package Tapir::Server::Transport::HTTP;

use Moose;
extends 'Tapir::Server::Transport';
use Tapir::MethodCall;

use Carp;
use POE qw(Component::Server::HTTP);
use HTTP::Status qw(:constants);
use JSON::XS;
use Data::UUID;
use Try::Tiny;

use Data::Dumper;

my $data_uuid = Data::UUID->new();
my $json_xs = JSON::XS->new->utf8->allow_nonref;

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

    $self->logger->info("Setup called!");
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

    my $call = Tapir::MethodCall->new(
        server => $self->server,
        transport => {
            request  => $request,
            response => $response,
        },
    );

    $call->add_action($_) foreach (
        \&decode_json_payload,
    );

    $call->add_error_callback(\&return_error);
    $call->add_callback(\&return_success);

    $call->run();

    $response->streaming(1);
    return RC_WAIT;
}

sub decode_json_payload {
    my $call = shift;
    _record_timing($call, 'decode_json_payload');

    my $request = $call->transport->{request};

    ## Parse the request path

    my ($service, $method) = $request->uri->path =~ m{^/([^/]+)/([^/]+)$};
    if (! $service) {
        croak "Invalid request.  Only understand '/<service>/<method>'";
    }

    $call->{service} = $call->server->idl->service_named($service);
    if (! $call->{service}) {
        croak "Invalid service '$service'";
    }

    $call->{method} = $call->service->method_named($method);
    if (! $call->{method}) {
        croak "Invalid method '$service.$method'";
    }

    $call->heap_set(
        ip => $request->header('X-Forwarded-For') || $request->{connection}{remote_ip},
        id => $data_uuid->create_str,
    );

    $call->logger->info(sprintf "Request for %s '%s' from %s", uc($request->method), $request->uri->path, $call->heap_index('ip'));

    ## Decode the content

    if (! $request->header('Content-Type') || $request->header('Content-Type') !~ m{^application/json\b}) {
        croak "Invalid 'Content-Type' header; must be 'application/json'";
    }

    my $data = eval { $json_xs->decode($request->content) };
    if ($@) {
        croak "Failed to decode JSON data in request payload: $@";
    }

    $call->heap_set(data => $data);
}

sub return_error {
    my ($call, $error, $status_code) = @_;
    _record_timing($call, 'return_error');

    _conclude_http_request($call,
        data => {
            success => JSON::XS::false,
            result  => $error,
        },
        status => $status_code || HTTP_BAD_REQUEST,
    );
}

sub return_success {
    my ($call, $status_code) = @_;
    _record_timing($call, 'return_success');

    _conclude_http_request($call,
        data => {
            success => JSON::XS::true,
            result  => $call->heap_index('result'),
        },
        status => $status_code || HTTP_OK,
    );
}

sub _conclude_http_request {
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

sub _record_timing {
    my ($call, $key) = @_;
    $call->{timing}{$key} = Time::HiRes::time;
}

1;
