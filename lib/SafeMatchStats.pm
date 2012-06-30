package SafeMatchStats;

use Moo;
use Sub::Quote;

use v5.12;
use utf8;
use feature qw( unicode_strings );

use Try::Tiny;
use Capture::Tiny qw( capture );
use Safe;
use Carp;

our $VERSION = 0.01;

has regexp_obj  => ( is => 'ro' );
has regexp_str  => ( is => 'ro' );
has prematch    => ( is => 'rw' );
has match       => ( is => 'rw' );
has matched     => ( is => 'rw' );
has postmatch   => ( is => 'rw' );
has carat_n     => ( is => 'rw' );
has digits      => ( is => 'rw' );
has array_minus => ( is => 'rw' );
has array_plus  => ( is => 'rw' );
has hash_minus  => ( is => 'rw' );
has hash_plus   => ( is => 'rw' );
has target      => ( is => 'rw' );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args_hash = $args[0];
    croak "Must pass a hashref to $class\->new()."
      if ref $args_hash ne 'HASH';
    croak "Usage: $class\->new( { regexp_str => 'PATTERN' "
      . "[, regexp_mods => '[msixadlu^-]+' } )"
      if !exists $args_hash->{regexp_str};
    my $full_regex_str = $class->_gen_re_string(
        $args_hash->{regexp_str}, $args_hash->{regexp_mods}
    );
    my $regexp_obj =
      $class->_safe_qr( $full_regex_str );
    croak "Couldn't generate a valid regexp object."
      if !ref $regexp_obj eq 'Regexp';
    return {
        regexp_obj => $regexp_obj,
        regexp_str => $full_regex_str,
        matched    => 0,
    };
}


sub do_match {
    my ( $self, $target ) = @_;
    return scalar $self->_safe_match_gather( $target, $self->regexp_obj );
}

sub _gen_re_string {
    my( $self, $raw_re_str, $raw_mods ) = @_;
    my $re_str = $self->_sanitize_re_string( $raw_re_str );
    my $mod_str = $self->_sanitize_re_modifiers( $raw_mods );
    return "(?$mod_str:$re_str)";
}

sub _safe_qr {
    my ( $self, $re_str ) = @_;
    my $compartment = Safe->new;
    ${ $compartment->varglob('regexp') } = $re_str;
    my $re_obj =
      $compartment->reval('my $safe_reg = qr/$regexp/;');
    return if $@;    # Return "undef" if 'reval' caught an exception.
    return $re_obj;  # Otherwise return a regexp object.
}

sub _sanitize_re_modifiers {
    my ( $self, $modifiers ) = @_;
    return '' if !defined $modifiers;
    $modifiers =~ tr/msixadlu^-//cd;
    my @modifiers = split //, $modifiers;
    my %seen;
    return join '', grep { !$seen{$_}++ } @modifiers;
}

sub _sanitize_re_string {
    my ( $self, $re_string ) = @_;
    no warnings 'qw';
    my @bad_varnames = qw%       \$\^\w          \@ENV              \$ENV
      \$[0()<>#!+-]   \$\{[\w()<>+-]}    \@\{\w+}      %;
    $re_string =~ s/(?<!\\)($_)/\\$1/g foreach @bad_varnames;
    return $re_string;
}

sub _safe_match_gather {
    my ( $self, $target ) = @_;
    $self->target($target);
    my $re_obj = $self->regexp_obj;
    $self->matched(0);
    try {
        $self->matched(1) if $target =~ m/$re_obj/;
        my $matched = $self->matched;
        $self->digits(
            [ map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- ] );
        $self->hash_plus(   $matched ? {%+}          : undef );
        $self->hash_minus(  $matched ? {%-}          : undef );
        $self->prematch(    $matched ? ${^PREMATCH}  : undef );
        $self->match(       $matched ? ${^MATCH}     : undef );
        $self->postmatch(   $matched ? ${^POSTMATCH} : undef );
        $self->carat_n(     $matched ? $^N           : undef );
        $self->array_minus( $matched ? [@-]          : undef );
        $self->array_plus(  $matched ? [@+]          : undef );
    }
    catch {
        $self->matched(undef);
        warn "Problem in matching: $_";
    };

    return $self->matched;
}

sub debug_info {
    my ( $self, $target ) = @_;
    my $re_string = $self->regexp_str;
    my( undef, $stderr, undef )
        = capture { $self->_do_re_debug( $target, $re_string ) };
    return $stderr;
}

sub _do_re_debug {
    my( $self, $target, $regex ) = @_;
    my $rv;
    try {
        use re q/debug/;
        $rv = $target =~ m/$regex/;
    }
    catch {
        s/\sat\s[\w.]+\sline\s\d+\.$/./;
        print STDERR "$_\n";
    };
    return $rv;
}
    

1;
