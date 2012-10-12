package Tapir::Documentation::JSONSpec;

use strict;
use warnings;
use JSON::XS;

my $json_xs = JSON::XS->new->ascii->pretty(1)->allow_nonref;

sub get_spec {
	my ($class, %args) = @_;

	my $document  = $args{document};
	my $namespace = $args{namespace};
	my %types     = %{ $args{types} };

	my (@services, %methods);

	foreach my $service (@{ $document->services }) {
		push @services, $service;
		foreach my $method (@{ $service->methods }) {
			push @{ $methods{ $service->name } }, $method;
		}
	}

	my %spec = (
        namespace => $namespace,
    );

	{
		# Custom types
		my @type_custom_declare = ([qw(name type validateSpec)]);
		$spec{typedefs} = \@type_custom_declare;

		foreach my $type (
			sort { $a->name cmp $b->name }
			grep { $_->isa('Thrift::IDL::TypeDef') }
			values %types
		) {
			my %details = (
				name => $type->name,
				type => describe_type($type->type, $namespace, 1),
			);

			my $spec = describe_validateSpec($type);
			if (@$spec) {
				$details{validateSpec} = $spec;
			}
			else {
				$details{validateSpec} = [];
			}

			push @type_custom_declare, [ map { $details{$_} } @{ $type_custom_declare[0] } ];
		}
	}

	foreach my $type (
		sort { $a->name cmp $b->name }
		grep { $_->isa('Thrift::IDL::Enum') }
		values %types
	) {
		push @{ $spec{enums} }, {
			name   => $type->name,
			values => { map { $$_[0] => $$_[1] } @{ $type->numbered_values } },
		}
	}

	foreach my $type (
		sort { $a->name cmp $b->name }
		grep { $_->isa('Thrift::IDL::Struct') }
		values %types
	) {
		push @{ $spec{structs} }, {
			name => $type->name,
			baseClass => 'Tapir.Type.' . ($type->isa('Thrift::IDL::Exception') ? 'Exception' : 'Struct'),
			fieldSpec => describe_fields($type->fields, $namespace),
		};
	}


    my @method_declare = ([qw(name serviceName fieldSpec spec)]);
    $spec{methods} = \@method_declare;
	foreach my $service (@services) {
		push @{ $spec{services} }, {
			name      => $service->name,
			baseName => $namespace . '.' . $service->name,
			methods   => [ map { $_->name } @{ $methods{ $service->name } } ],
		};

		foreach my $method (@{ $methods{ $service->name } }) {
			push @method_declare, [
				$method->name,
				$service->name,
				describe_fields($method->arguments, $namespace, 1, 1),
				{
					exceptions => describe_fields($method->throws, $namespace, 1, 1),
					returns    => describe_type($method->returns, $namespace, 1)
				}
			];
		}
	}

	return $json_xs->encode(\%spec);
}

sub describe_type {
    my ($type, $namespace) = @_;

    my $namespaced_type = $type->isa('Thrift::IDL::Type::Custom') ? join '.', $namespace, $type->name : $type->name;

    if ($type->can('val_type')) {
        my %details = (
            type => $namespaced_type,
            valType => describe_type($type->val_type, $namespace, 1),
        );
        if ($type->can('key_type')) {
            $details{keyType} = describe_type($type->key_type, $namespace, 1);
        }

        return \%details;
    }

    return $namespaced_type;
}

sub describe_fields {
    my ($fields, $namespace, $want_perl, $no_header) = @_;

    my @output = (
        ($no_header ? () : (
        [qw(index name optional type validateSpec)],
        ))
    );
    foreach my $field (@$fields) {
        my $optional = $field->optional ? 1 : 0;
        if (! $optional && $field->{doc} && $field->{doc}{optional}) {
            $optional = 1;
        }
        push @output, [
            $field->id,
            $field->name,
            ($optional ? JSON::XS::true : JSON::XS::false),
            describe_type($field->type, $namespace, 1),
            describe_validateSpec($field)
        ];
    }

    return \@output;
}

sub describe_validateSpec {
    my $type = shift;
    return [] unless $type->{doc};

    my @spec;

    if ($type->{doc}{validators}) {
        foreach my $validator (@{ $type->{doc}{validators} }) {
            my ($type) = ref($validator) =~ m{::([^:]+)$};
            my %spec_details = (
                type => lc($type)
            );
            push @spec, \%spec_details;

            if ($type eq 'Range' || $type eq 'Length') {
                $spec_details{low}  = $validator->{min};
                $spec_details{high} = $validator->{max};
            }
            elsif ($type eq 'Regex') {
                # Javascript doesn't support POSIX named character classes
                my $pattern = $validator->{body};
                $pattern =~ s{\[:alnum:\]}{A-Za-z0-9}g;
                if ($pattern =~ /\[:([a-z]+):\]/) {
                    print STDERR "Failed to convert POSIX named character class '$1'\n";
                }
                $spec_details{pattern} = $pattern;
            }
            else {
                print STDERR "Unrecognized \@validate spec '$type'\n";
            }
        }
    }

    if ($type->{doc}{utf8}) {
        push @spec, { type => 'utf8' };
    }

    return \@spec;
}

1;
