use strict;
use warnings;
use FindBin;
use Test::More;
use Test::File::Contents;
use Tapir::Documentation::NaturalDocs;
use File::Temp qw();

my $temp_dir = File::Temp->newdir();

Tapir::Documentation::NaturalDocs->build(
	input_fn     => $FindBin::Bin . '/thrift/example.thrift',
	temp_dir     => $temp_dir . '/process',
	output_dir   => $temp_dir . '/output',
	prepare_only => 1,
);

ok ! -d $temp_dir . '/process', "Temporary directory was removed";
ok -d $temp_dir . '/output', "Output directory was created";

done_testing;
