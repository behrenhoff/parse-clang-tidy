use Mojolicious::Lite;
# use Mojo::SQLite;
use DBI;

# helper sqlite => sub { state $sql = Mojo::SQLite->new('sqlite:result.sqlite') };
helper sqlite => sub {
    my $dbh = DBI->connect("dbi:SQLite:dbname=result.sqlite","","", {AutoCommit=>0});
    return $dbh;
};
 
get '/' => sub {
    my $c  = shift;
    my $db = $c->sqlite; #->db;
    #$c->render(json => $db->query('select datetime("now","localtime") as now')->hash);
    my $ary_ref  = $db->selectall_arrayref("select topdir, checker, count(*) from result group by topdir, checker;");
    my %nEntriesPerDirChecker;
    my @checkers;
    my @topdirs;
    for my $row (@$ary_ref) {
        $nEntriesPerDirChecker{$row->[0]}{$row->[1]} = $row->[2];
        push @topdirs, $row->[0] unless grep { $row->[0] eq $_ } @topdirs;
        push @checkers, $row->[1] unless grep { $row->[1] eq $_ } @checkers;
    }
    @checkers = sort @checkers;


    $c->render(template => 'overview',
               nEntries => \%nEntriesPerDirChecker,
               checkers => \@checkers,
               topdirs => \@topdirs);
};


get '/detail' => sub {
    my $c  = shift;
    my $db = $c->sqlite; #->db;

    my $checker = $c->param('c');
    my $topdir = $c->param('topdir');

    #CREATE TABLE result (file TEXT, topdir TEXT, checker TEXT, line INTEGER, col INTEGER, code TEXT);
    my $problems;
    my $query = "select file, checker, line, col, code from result ";
    if ($checker && $topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ? and checker = ?;",
            {Slice=>{}}, $topdir, $checker);
    } elsif ($checker) {
        $problems = $db->selectall_arrayref(
            "$query where checker = ?;",
            {Slice=>{}}, $checker);
    } elsif ($topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ?;",
            {Slice=>{}}, $topdir);
    } else {
        $c->redirect_to('/');
    }
    for my $p (@$problems) {
        $p->{file} =~ s!^src/!!;
    }

    $c->render(template => 'detail',
               problems => $problems,
               srcprefix => 'https://github.com/root-project/root/blob/73c39b2808/'
               );
};

app->start;


__DATA__

@@ overview.html.ep
% title 'clang-tidy - ROOT - quick overview';
% layout 'defaultLayout';

<table class=overview>
    <tr>
    <th></th>
    <% for my $topdir (@$topdirs) { %>
        <th><a href="detail?topdir=<%= $topdir %>"><%= $topdir %></a></th>
    <% } %>
    </tr>

    <% for my $c (@$checkers) { %>
        <tr>
        <th><a href="detail?c=<%= $c %>"><%= $c %></a></th>
        <% for my $topdir (@$topdirs) { %>
            <td><a href="detail?c=<%= $c %>&amp;topdir=<%= $topdir %>"><%= $nEntries->{$topdir}{$c} %></a></td>
        <% } %>
        </tr>
    <% } %>

@@ detail.html.ep
% title 'clang-tidy - ROOT - detailled report';
% layout 'defaultLayout';

<table>
<tr><th>Filename</th><th>Checker</th><th>Problem</th></tr>

<% for my $p (@$problems) { %>
    <tr>
        <td><a href="<%= $srcprefix %><%= $p->{file} %>#L<%= $p->{line} %>"><%= $p->{file} %>:<%= $p->{line} %></a></td>
        <td><%= $p->{checker} %></td>
        <td><pre><%= $p->{code} %></pre></td>
    </tr>
<% } %>


</table>


@@ layouts/defaultLayout.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
<style>

body {
    font-family: sans-serif;
    font-size: 12px;
}

table {
    border-collapse: collapse;
}

table, table th, table td {
    border: 1px solid black;
    padding: 3px 5px 3px 5px;
}

table.overview td { text-align: center; }
table.overview th {
    text-align: left;
    background-color: lightgrey;
}

</style>
  </head>
  <body>
  <h2>clang-tidy results from 2018-09-17, ROOT master (C++14, Python3), Git hash: 73c39b2808</h2>
  <%= content %>
  </body>
</html>
