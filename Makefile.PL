use inc::Module::Install;

name     'Business-CompanyDesignator';
all_from 'lib/Business/CompanyDesignator.pm';
license  'perl';

build_requires 'Test::More';

requires 'File::ShareDir';
requires 'List::MoreUtils';
requires 'Mouse';
requires 'MouseX::NativeTraits';
requires 'namespace::autoclean';
requires 'Regexp::Assemble';
requires 'Unicode::Normalize';

test_requires 'Test::More' => 0.88;
test_requires 'Test::Exception';

auto_install;

install_share;

WriteAll;

