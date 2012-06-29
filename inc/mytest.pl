#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny qw(capture);

my $target = "This that and the other.";
my $regex = q/(that)\s(and)/;


foreach my $cr ( \&just_do_it ) {
    my( $stdout, $stderr, $result ) = try_capture( $cr, $target, $regex );
    print "\$stdout contained:\n<<<$stdout>>>\n";
    print "\$stderr contained:\n<<<$stderr>>>\n";
    print "\$result contained:\n<<<$result>>>\n";
    print "\$@      contained:\n<<<$@>>>\n";
}


sub try_capture {
    my ( $code, $target, $re_obj ) = @_;
    print "Binding $target, $re_obj\n";
    return capture { $code->($target,$re_obj) };
}



sub just_do_it {
    my( $target, $re_obj ) = @_;
    use re q/debug/;
    return $target =~ m/$re_obj/;
}
