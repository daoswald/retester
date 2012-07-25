use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    VERSION   => '0.01',
    PREREQ_PM => {
        'Mojolicious'     => '3.0',
        'Try::Tiny'       => '0',
        'Capture::Tiny'   => '0',
        'Time::HiRes'     => '0',
        'Sys::SigAction'  => '0',
        'Safe'            => '0',
        'Carp'            => '0',
        'Moo'             => '0',
        'Plack'           => '0',
        'Test::More'      => '0',
        'Test::Exception' => '0',
        'List::MoreUtils' => '0',
    },
    test => { TESTS => 't/*.t' }
);
