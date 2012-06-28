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
% title 'Perl Regex Tester';
<h1><%= title =%></h1>
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
        <%=
            text_area 'target', cols => 80, placeholder => 'Target string',
            maxlength => 2048
        =%>
    </p>
    <p>
        Regular Expression:
        <br />
        <%=
            text_area 'regexp', cols => 80, placeholder => 'Regular Expression',
            maxlength => 2048
        =%>
        <br />
        <small>Example: To test "<code>m/pattern/</code>", enter
        "<code>pattern</code>" (without quotes).</small>
    </p>
    <p>
        Modifiers:
        <br />
        <%= text_field 'flags', cols        => '30', 
            placeholder => 'Valid Modifiers: [msixadlu]',
            maxlength   => '8'
        %>
        %= submit_button
    </p>
%end
<article>
%== '<h2>Match!</h2>' if $match_success
%== '<h2>No match!</h2>' if ! $match_success && defined $match_success
%== '<h2>Invalid regular expression!</h2>' if param('regexp') && ! defined $match_success
</article>
<% if( ref( $captures ) eq 'HASH' ) {
    local $" = ',';
=%>
    <article>
        <h3>Capture variables:</h3>
        <pre>
            <%= "\${^PREMATCH}   => $captures->{'${^PREMATCH}'}\n"  =%>
            <%= "\${^MATCH}      => $captures->{'${^MATCH}'}\n"     =%>
            <%= "\${^POSTMATCH}  => $captures->{'${^POSTMATCH}'}\n" =%>
            <%= "\$^N            => $captures->{'$^N'}\n"           =%>
            <% foreach my $digit ( 1 .. $#{$captures->{'$<digits>'}} ) { =%>
                <%= "\$$digit: $captures->{'$<digits>'}[$digit]\n"  =%>
            <% } =%>
            <% foreach my $name ( keys %{$captures->{'$+{name}'}} ) { =%>
                <%= "\$+{$name} => $captures->{'$+{name}'}{$name}\n"  =%>
            <% } =%>
            <% foreach my $name ( keys %{$captures->{'$-{name}'}} ) { =%>
                <%= "\$-{$name} => (@{$captures->{'$-{name}'}{$name}})\n" =%>
            <% } =%>
            <%= @{$captures->{'@-'}} && "\@- => (@{$captures->{'@-'}})\n" =%>
            <%= @{$captures->{'@+'}} && "\@+ => (@{$captures->{'@+'}})\n" =%>
        </pre>
    </article>
% }
% if( param('regexp') ) {
    <article>
        <p>
            <h3>Regex Explanation:</h3>
            <p>
                %== length $explanation &&  "<pre>$explanation</pre>"
            </p>
            <p>
                <small>Note: The <em>Regex Explanation</em> section doesn't
                properly comprehend regexp constructs unique to Perl v5.10 or
                later.</small>
            </p>
        </p>
    </article>
% }
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head><title><%= title %></title></head>
    <body><%= content %></body>
</html>
