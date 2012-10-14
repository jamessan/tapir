package Tapir::Server;

=head1 NAME

Tapir::Server - An API server

=head1 DESCRIPTION

Mainly subclassed, this offers a base class for any implementation of the API.

=cut

use Moose;
use Params::Validate;
use Carp;
use Try::Tiny;
use Thrift::IDL;
use Thrift::Parser;

use Tapir::Logger;
use Tapir::Validator;


sub is_valid_request {
    my ($self, %opt) = @_;

    return { };
}

# User specified arguments
has 'thrift_file' => (is => 'ro', required => 1);

has 'handlers'   => (is => 'ro', default => sub { [] });
has 'transports' => (is => 'ro', default => sub { [] });
has 'logger'     => (is => 'ro', lazy_build => 1);

has 'idl'        => (is => 'ro', lazy_build => 1);
has 'validator'  => (is => 'ro', default => sub { Tapir::Validator->new( audit_types => 1 ) } );

sub BUILD {
    my $self = shift;

    # Conduct an audit of the thrift document
    if (my @errors = $self->validator->audit_idl_document($self->idl)) {
        croak "Invalid thrift_idl file '" . $self->thrift_file . "'; the following errors were found:\n"
            . join("\n", map { " - $_" } @errors);
    }
}

sub add_handler {
    my $self = shift;
    my %opt = validate(@_, {
        class => 1,
    });

    eval "require $opt{class}";
    if ($@) {
        croak "Failed to load class $opt{class}: $@";
    }

    if (! $opt{class}->isa('Tapir::Server::Handler')) {
        croak "$opt{class} must be a subclass of Tapir::Server::Handler";
    }

    my $service = $opt{class}->service;
    if (! $service) {
        croak "Class $opt{class} doesn't define a service";
    }

    my $idl_service = $self->idl->service_named($service);
    if (! $idl_service) {
        croak "No such service '$service' defined in the IDL";
    }

    my %methods = %{ $opt{class}->service_methods };
    if (! %methods) {
        croak "Class $opt{class} doesn't define any methods";
    }

    my %idl_methods = map { $_->name => $_ } @{ $idl_service->methods };
    foreach my $method (keys %methods) {
        if (! $idl_methods{$method}) {
            croak "No such method '$service.$method' defined in the IDL";
        }
    }

    push @{ $self->handlers }, {
        class   => $opt{class},
        service => $service,
        methods => \%methods,
        idl_service => $idl_service,
        parser  => Thrift::Parser->new(idl => $self->idl, service => $service),
    };
}

sub add_transport {
    my $self = shift;
    my %opt = validate(@_, {
        class   => 1,
        options => { default => {} },
    });

    eval "require $opt{class}";
    if ($@) {
        croak "Failed to load class $opt{class}: $@";
    }

    my $transport;
    try {
        $transport = $opt{class}->new(
            server => $self,
            logger => $self->logger,
            %{ $opt{options} }
        );
        $transport->setup();
    } catch {
        croak "Failed to load class $opt{class}: $_";
    };

    push @{ $self->transports }, $transport;
}

sub add_call_actions {
    my ($self, $call) = @_;

    my $service_name = $call->service->name;
    my $method_name  = $call->method->name;

    my $handlers_found = 0;
    foreach my $handler (@{ $self->handlers }) {
        next unless $handler->{service} eq $service_name;
        next unless $handler->{methods}{$method_name};
        $handlers_found++;
        $handler->{class}->add_call_actions($call);
    }

    if (! $handlers_found) {
        croak "No handlers found for service call '$service_name.$method_name'";
    }
}

sub run {
    my $self = shift;

    if (! int @{ $self->transports }) {
        croak "Can't run() without any transports defined";
    }

    $_->run() foreach @{ $self->transports };
}

sub _build_logger {
    my $self = shift;
    return Tapir::Logger->new(screen => 1);
}

sub _build_idl {
    my $self = shift;
    return Thrift::IDL->parse_thrift_file($self->thrift_file);
}

1;
