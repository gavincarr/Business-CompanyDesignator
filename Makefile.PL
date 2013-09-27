use inc::Module::Install;

name     'Business-CompanyDesignator';
all_from 'lib/Business/CompanyDesignator.pm';
author   q{Gavin Carr <gavin@openfusion.com.au>};
license  'perl';

build_requires 'Test::More';

requires 'Mouse';
requires 'File::ShareDir';
requires 'List::MoreUtils';
requires 'Regexp::Assemble';

auto_install;

install_share;

WriteAll;

