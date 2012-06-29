#!/usr/bin/env perl
use Mojolicious::Lite;

use lib 'lib';

use SafeMatchStats;

app->secret('Some Session Secret');

app->defaults(
    {
        map { $_, undef }
          qw( match_success   prematch    match
              postmatch       carat_n     digits
              array_minus     array_plus  hash_minus
              hash_plus                               )
    }
);

plugin 'PoweredBy';
plugin 'PODRenderer';

any '/' => sub {
    my $self = shift;
    if ( $self->param('regexp') ) {
        my $re = SafeMatchStats->new(
            {
                regexp_str  => $self->param('regexp')    || '',
                regexp_mods => $self->param('modifiers') || ''
            }
        );
        $self->stash(
            match_success => $re->do_match( $self->param('target') ) );
        $self->stash(
            {
                prematch    => $re->prematch,
                match       => $re->match,
                postmatch   => $re->postmatch,
                carat_n     => $re->carat_n,
                digits      => $re->digits,
                array_minus => $re->array_minus,
                array_plus  => $re->array_plus,
                hash_minus  => $re->hash_minus,
                hash_plus   => $re->hash_plus,
            }
        );
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
    <%= text_area 'target', cols        => 80,
                            placeholder => 'Target string',
                            maxlength   => 2048
    =%>
  </p>
  <p>
    Regular Expression:
    <br />
    <%=
      text_area 'regexp', cols        => 80,
                          placeholder => 'Regular Expression',
                          maxlength   => 2048
    =%>
    <br />
      <small>
        Example: To test "<code>m/pattern/</code>", enter
        "<code>pattern</code>" (without quotes).
      </small>
  </p>
  <p>
    Modifiers:
    <br />
    <%= text_field 'modifiers', cols        => '30', 
                                placeholder => 'Valid Modifiers: [msixadlu]',
                                maxlength   => '10'
    %>
    %= submit_button
  </p>
%end

<article>
%== '<h2>Match!</h2>' if $match_success
%== '<h2>No match!</h2>' if defined $match_success && ! $match_success
%== '<h2>Invalid regular expression!</h2>' if param('regexp') && ! defined $match_success
</article>
<% if( $match_success ) {
    local $" = ',';
=%>
  <article>
    <h3>Capture variables:</h3>
      <ul>
        %  if( @{$digits} > 1 ) {
          <li>Digit Captures
            <ul>
            %  foreach my $digit ( 1 .. $#{$digits} ) {
              %== "<li><pre>\$$digit => $digits->[$digit]</pre></li>"
            % }
            </ul>
          </li>
        % }
        % if( keys %{$hash_plus} ) {
          <li>Named Captures
            <ul>
              % foreach my $name ( keys %{$hash_plus} ) {
                %== "<li><pre>\$+{$name} => $hash_plus->{$name}</pre></li>"
              % }
            </ul>
          </li>
        % }
        %== defined $prematch  && "<li><pre>\${^PREMATCH}  => $prematch</pre></li>"
        %== defined $match     && "<li><pre>\${^MATCH}     => $match</pre></li>"
        %== defined $postmatch && "<li><pre>\${^POSTMATCH} => $postmatch</pre></li>"
        %== defined $carat_n   && "<li><pre>\$^N           => $carat_n</pre></li>"
        % foreach my $name ( keys %{$hash_minus} ) {
          %== "<li><pre>\$-{$name} => (@{$hash_minus->{$name}})</pre></li>"
        % }
        %== @{$array_minus} && "<li><pre>\@- => (@{$array_minus})</pre></li>"
        %== @{$array_plus}  && "<li><pre>\@+ => (@{$array_plus})</pre></li>"
    </ul>
  </article>
% }




@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body>
    <article>
      <header>
        [
          <%= link_to '/' => begin %>The Perl Regex Tester<% end =%> |
          <a href='http://perldoc.perl.org/perlre.html'>perlre</a> |
          <a href='http://perldoc.perl.org/perlrequick.html'>perlrequick</a> |
          <a href='http://perldoc.perl.org/perlretut.html'>perlretut</a> |
          <a href='http://perldoc.perl.org/perlop.html'>perlop</a> |
          <a href='http://perldoc.perl.org/perlfaq6.html'>perlfaq6</a>
        ]
      </header>
    </article>
    <%= content %>
  </body>
</html>
