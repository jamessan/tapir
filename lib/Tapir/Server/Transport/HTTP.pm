package Tapir::Server::Transport::HTTP;

use Moose;
extends 'Tapir::Server::Transport';
use Tapir::MethodCall;
use Tapir::Exceptions;

use POE qw(Component::Server::HTTP);
use HTTP::Status qw(:constants);
use JSON::XS;
use Data::UUID;
use Try::Tiny;
use Data::Dumper;

my $data_uuid = Data::UUID->new();
my $json_xs = JSON::XS->new->utf8->allow_nonref->allow_blessed;

has 'alias' => (is => 'ro', default => 'tapir-http');
has 'port'  => (is => 'ro', default => 3000);
has 'ssl'   => (is => 'ro');

sub setup {
    my $self = shift;

    POE::Session->create(
        object_states => [ $self, [qw(
            _start
            http_handler
        )] ]
    );

    ## Find all the @rest methods

    foreach my $handler (@{ $self->server->handlers }) {
        my $idl_service = $handler->{idl_service};
        foreach my $method (keys %{ $handler->{methods} }) {
            my $idl_method = $idl_service->method_named($method);
            my $rest = $idl_method->{doc}{rest};
            next unless $rest;
            $self->logger->info(sprintf "Listening for %s %s", uc($rest->{method}), $rest->{route});
        }
    }
}

sub run {
    my $self = shift;

    POE::Kernel->run();
}

sub _start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set($self->alias);

    $self->{http_aliases} = POE::Component::Server::HTTP->new(
        Port => $self->port,
        ContentHandler => {
            '/' => sub {
                $kernel->call($self->alias, 'http_handler', @_);
            },
        },
        # FIXME: Replace with SSL-capable HTTP server
        ($self->ssl ? (
        SSL => {
            KeyFile  => $self->ssl->{key},
            CertFile => $self->ssl->{cert},
        },
        ) : ()),
    );

    $self->logger->info("Connect to the API proxy on HTTP port ".$self->port);
}

sub http_handler {
    my ($self, $kernel, $request, $response) = @_[OBJECT, KERNEL, ARG0, ARG1];

    my $call = Tapir::MethodCall
        ->new(
            server => $self->server,
            transport => {
                request  => $request,
                response => $response,
            },
        )
        ->add_action(\&setup_methodcall)
        ->add_error_callback(\&catch_exception)
        ->add_callback(\&handle_result)
        ->run();

    $response->streaming(1);
    return RC_WAIT;
}

sub setup_methodcall {
    my $call = shift;
    record_timing($call, 'decode_json_payload');

    my $request = $call->transport->{request};

    ## Parse the request path

    my ($service, $method) = $request->uri->path =~ m{^/([^/]+)/([^/]+)$};
    if (! $service) {
        Tapir::Exception->throw("Invalid request.  Only understand '/<service>/<method>'");
    }

    if (! $call->service( $call->server->idl->service_named($service) )) {
        Tapir::Exception->throw("Invalid service '$service'");
    }

    if (! $call->method( $call->service->method_named($method) )) {
        Tapir::Exception->throw("Invalid method '$service.$method'");
    }

    ## Decode the content

    if (! $request->header('Content-Type') || $request->header('Content-Type') !~ m{^application/json\b}) {
        Tapir::Exception->throw("Invalid 'Content-Type' header; must be 'application/json'");
    }

    my $data = eval { $json_xs->decode($request->content) };
    if (my $ex = $@) {
        $ex =~ s{at (.+?) line \d+\.\s*$}{};
        Tapir::Exception->throw("Failed to decode JSON data in request payload: $ex");
    }

    ## Compose the thrift message and validate it

    my $parser = $call->server->parser_for_call($call);
    my $method_message_class = $parser->{methods}{$method}{class};
    my $thrift_message;
    try {
        $thrift_message = $method_message_class->compose_message_call(%$data);
    }
    catch {
        my $ex = $_;
        if (ref $ex && blessed $ex && $ex->isa('Exception::Class::Base')) {
            if ($ex->isa('Thrift::Parser::InvalidArgument')) {
                $ex->rethrow();
            }
        }
        Tapir::Exception->throw("Error in composing $method_message_class message: $_");
    };

    $call->server->validator->validate_parser_message($thrift_message);

    $call->arguments($thrift_message->arguments);
    $call->message($thrift_message);
    $call->heap_set(
        ip => $request->header('X-Forwarded-For') || $request->{connection}{remote_ip},
        id => $data_uuid->create_str,
    );

    $call->logger->info(sprintf "Request for %s '%s' from %s", uc($request->method), $request->uri->path, $call->heap_index('ip'));

    ## Queue up the handler actions

    $call->server->add_call_actions($call);
}

sub catch_exception {
    my ($call, $exception) = @_;

    my $error = "$exception";

    return_error($call, $error);
}

sub handle_result {
    my $call = shift;
    record_timing($call, 'handle_result');

    if ($call->heap_isset('result')) {
        return_success($call);
    }
    else {
        return_error($call, "No result from method call found");
    }
}

sub return_error {
    my ($call, $error, $status_code) = @_;
    conclude_http_request($call,
        data => {
            success => JSON::XS::false,
            result  => $error,
        },
        status => $status_code || HTTP_BAD_REQUEST,
    );
}

sub return_success {
    my ($call, $status_code) = @_;
    conclude_http_request($call,
        data => {
            success => JSON::XS::true,
            result  => $call->heap_index('result'),
        },
        status => $status_code || HTTP_OK,
    );
}

sub conclude_http_request {
    my ($call, %args) = @_;
    my ($request, $response) = @{ $call->transport }{'request', 'response'};

    $response->code($args{status} || HTTP_OK);
    if ($args{data} && ref $args{data}) {
        $response->content_type('application/json; charset=utf8');
        $response->content($json_xs->encode($args{data}));

    }

    # Close the POE::Component::Client::HTTP::Request and HTTP::Response objects
    # This will trigger the socket to be written to and closed.
    if ($response->streaming) {
        $response->send($response);
        $response->close();
        $request->header(Connection => 'close');
    }
}

sub record_timing {
    my ($call, $key) = @_;
    $call->{timing}{$key} = Time::HiRes::time;
}

1;
