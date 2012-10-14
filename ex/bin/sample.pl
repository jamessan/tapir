#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tapir::Server;

my $server = Tapir::Server->new(
	thrift_file => $FindBin::Bin . '/../../t/thrift/example.thrift',
);

$server->add_handler(
	class => 'MyAPI::Accounts',
);

$server->add_transport(
	class   => 'Tapir::Server::Transport::HTTP',
	options => {
		port => 8080,
	},
);

=cut
$server->add_transport(
	class   => 'Tapir::Server::Transport::AMQP',
	options => {
		username => 'guest',
		password => 'guest',
		hostname => 'localhost',
		port     => 5672,
		ssl      => 0,
		queue_name => '%s', # service name
	},
);
=cut

$server->run();
