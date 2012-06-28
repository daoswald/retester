#!/usr/bin/env perl
use Mojolicious::Lite;

use lib 'lib';

use SafeMatchStats;

any '/' => sub {
    my $self = shift;
    $self->stash(
        match_success => undef,     captures => undef,
        explanation   => undef,     graphviz => undef
    );
    if( $self->param('regexp') ) {
        my $re = SafeMatchStats->new( {
            regexp_str => $self->param('regexp'),
            regexp_mods => $self->param('modifiers')
        } );
        my $success = $re->match( $self->param('target') );
        $self->stash( match_success => $success         );
        $self->stash( captures      => $re->captures    );
        $self->stash( explanation   => $re->explanation );
        $self->stash( graphviz      => $re->graphviz    );
    }
    $self->render('index');
};


app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Perl Regexp Tester';
<h1>Perl Regexp Tester</h1>
<p>
Test Perl regular expressions against target strings.
</p>
<p>
The regexp engine used is compatible with Perl <%= " $^V" =%>.
</p>
%= form_for '/' => ( method => 'post' ) => begin
  <p>
    Target string:
    <br />
    %= text_area 'target', cols => 80, placeholder => 'Target string', maxlength => 2048
  </p>
  <p>
    Regular Expression:
    <br />
    %= text_area 'regexp', cols => 80, placeholder => 'Regular Expression', maxlength => 2048
    <br />
    <small>Example: To test "<code>m/pattern/</code>", enter "<code>pattern</code>" 
    (without quotes).</small>
  </p>
  <p>
    Flags:
    <br />
    <%= text_field 'flags', cols        => '30', 
                            placeholder => 'Valid Modifiers: [msixadlu]',
                            maxlength   => '8'
    %>
  </p>
    %= submit_button
%end

%== '<h2>Match!</h2>' if $match_success
%== '<h2>No match!</h2>' if ! $match_success && defined $match_success
%== '<h2>Invalid regular expression!</h2>' if ! defined $match_success
% if( ref( $captures ) eq 'HASH' ) { local $" = ',';
<h3>Capture variables:</h3>
<pre>
    <%= defined $captures->{'${^PREMATCH}'}  && "\${^PREMATCH}   => $captures->{'${^PREMATCH}'}\n"  =%>
    <%= defined $captures->{'${^MATCH}'}     && "\${^MATCH}      => $captures->{'${^MATCH}'}\n"     =%>
    <%= defined $captures->{'${^POSTMATCH}'} && "\${^POSTMATCH}  => $captures->{'${^POSTMATCH}'}\n" =%>
    <%= defined $captures->{'$^N'}           && "\$^N            => $captures->{'$^N'}\n"           =%>
    <% foreach my $digit ( 1 .. $#{$captures->{'$<digits>'}} ) { =%>
        <%= "\$$digit: $captures->{'$<digits>'}[$digit]\n"  =%>
    <% } =%>
    <% foreach my $name ( keys %{$captures->{'$+{name}'}} ) { =%>
        <%= "\$+{$name} => $captures->{'$+{name}'}{$name}\n"  =%>
    <% } =%>
    <% foreach my $name ( keys %{$captures->{'$-{name}'}} ) { =%>
        <%= "\$-{$name} => (@{$captures->{'$-{name}'}{$name}})\n" =%>
    <% } =%>
    <%= scalar @{$captures->{'@-'}} && "\@- => (@{$captures->{'@-'}})\n" =%>
    <%= scalar @{$captures->{'@+'}} && "\@+ => (@{$captures->{'@+'}})\n" =%>
</pre>
% }
<p>
<h3>Regex Explanation:</h3>
<p>
Note: This section doesn't properly comprehend regexp constructs unique to
Perl v5.10 or later.
</p>
<p>
    %== length $explanation &&  "<pre>$explanation</pre>"
</p>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
