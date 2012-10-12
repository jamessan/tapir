use Module::Build;

my $build = Module::Build->new(
    module_name => 'Tapir',
    license     => 'perl',
    sign        => 1,
    create_readme => 1,
    configure_requires => {
        'Module::Build' => 0.4,
    },
    build_requires             => {
        'Test::More'           => 0,
        'Test::Deep'           => 0,
        'Test::File::Contents' => 0,
    },
    requires                       => {
        'perl'                     => 5.008,
        'Thrift::Parser'           => '0.06',
        'POE::Component::Sequence' => '0.02',
        'Moose'                    => 0,
        'Devel::Declare'           => 0,
        'File::Spec'               => 0,
        'Try::Tiny'                => 0,
        'Params::Validate'         => 0,
        'Class::Accessor::Grouped' => 0,
        'Log::Log4perl'            => 0,
    },
    create_makefile_pl => 'small',
    meta_merge => {
        resources => {
            repository => "http://github.com/ewaters/tapir",
            bugtracker => "http://github.com/ewaters/tapir/issues?labels=bug",
        },
    },
);

$build->create_build_script;

