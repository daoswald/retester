use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
	'Mojolicious' => '3.0',
        'Safe'	      => '0',
        'Carp'        => '0',
        'Moo'         => '0',
        'Plack'       => '0',
},
  test      => {TESTS => 't/*.t'}
);
