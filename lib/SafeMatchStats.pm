package SafeMatchStats;

use Moo;
use Sub::Quote;

use v5.14;
use utf8;
use feature qw( unicode_strings );

use Try::Tiny;
use Safe;
use Carp;

our $VERSION = 0.01;

has regexp_obj  => ( is => 'ro' );
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
    my $regexp_obj =
      $class->_safe_qr( $args_hash->{regexp_str}, $args_hash->{regexp_mods} );
    croak "Couldn't generate a valid regexp object."
      if !ref $regexp_obj eq 'Regexp';
    return {
        regexp_obj => $regexp_obj,
        matched    => 0,
    };
}

sub do_match {
    my ( $self, $target ) = @_;
    return scalar $self->_safe_match_gather( $target, $self->regexp_obj );
}

sub _safe_qr {
    my ( $self, $regexp, $modifiers ) = @_;
    my $compartment = Safe->new;
    ${ $compartment->varglob('regexp') } = $self->_sanitize_re_string($regexp);
    ${ $compartment->varglob('modifiers') } =
      $self->_sanitize_re_modifiers($modifiers);
    my $re_obj =
      $compartment->reval('my $safe_reg = qr/(?$modifiers:$regexp)/;');
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
    try { $self->matched( scalar $target =~ m/$re_obj/ ); }
    catch {
        $self->matched(undef);
        warn "Problem in matching: $_";
    };
    my $matched;
    $matched = $self->matched(1) if $target =~ m/$re_obj/;
    $self->digits(
        [ map { substr $target, $-[$_], $+[$_] - $-[$_] } 0 .. $#- ] );
    $self->hash_plus( $matched   ? {%+}          : undef );
    $self->hash_minus( $matched  ? {%-}          : undef );
    $self->prematch( $matched    ? ${^PREMATCH}  : undef );
    $self->match( $matched       ? ${^MATCH}     : undef );
    $self->postmatch( $matched   ? ${^POSTMATCH} : undef );
    $self->carat_n( $matched     ? $^N           : undef );
    $self->array_minus( $matched ? [@-]          : undef );
    $self->array_plus( $matched  ? [@+]          : undef );

    return $self->matched;
}

1;
