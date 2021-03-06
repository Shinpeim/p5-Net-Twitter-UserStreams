use inc::Module::Install;
name 'Net-Twitter-UserStreams';
all_from 'lib/Net/Twitter/UserStreams.pm';
readme_from 'lib/Net/Twitter/UserStreams.pm';
readme_markdown_from 'lib/Net/Twitter/UserStreams.pm';
readme_pod_from 'lib/Net/Twitter/UserStreams.pm';
githubmeta;

test_requires 'Test::TCP';
test_requires 'Test::Requires';
test_requires 'YAML';
test_requires 'JSON';

requires 'AnyEvent::Twitter::Stream';
requires 'Smart::Args';
requires 'Net::OAuth';
requires 'Net::SSLeay';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
