use Mojolicious::Lite;
# use Mojo::SQLite;
use DBI;
use Text::Wrap qw(wrap); $Text::Wrap::columns = 120;

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
    my $orderby = "order by checker, file, line";
    if ($checker && $topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ? and checker = ? $orderby;",
            {Slice=>{}}, $topdir, $checker);
    } elsif ($checker) {
        $problems = $db->selectall_arrayref(
            "$query where checker = ? $orderby;",
            {Slice=>{}}, $checker);
    } elsif ($topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ? $orderby;",
            {Slice=>{}}, $topdir);
    } else {
        $c->redirect_to('/');
    }
    for my $p (@$problems) {
        $p->{file} =~ s!^src/!!;
        $p->{code} = wrap('', '', $p->{code});
    }

    $c->render(template => 'detail',
               problems => $problems,
               srcprefix => 'https://github.com/root-project/root/blob/4831835e28fe3f182409bea54dc61b148e1461a0/'
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

<table id="resultlist">
<thead>
<tr><th>Filename</th><th>Checker</th><th>Problem</th></tr>
</thead>
<tbody>
<% for my $p (@$problems) { %>
    <tr>
        <td><a href="<%= $srcprefix %><%= $p->{file} %>#L<%= $p->{line} %>"><%= $p->{file} %>:<%= $p->{line} %></a></td>
        <td><%= $p->{checker} %></td>
        <td><pre><%= $p->{code} %></pre></td>
    </tr>
<% } %>

</tbody>
</table>


@@ layouts/defaultLayout.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <link rel="stylesheet" href="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js">
<style>

body {
    font-family: sans-serif;
    font-size: 12px;
}

div.bugs {
    color: red;
    margin-bottom: 1em;
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

.dataTables_filter {
    font-size: 16px;
    margin: 10px 0px 10px 0px;
}

.dataTables_filter input {
    width: 400px;
    margin-left: 10px;
    background-color: ghostwhite;
}

</style>
    <script type="text/javascript" language="javascript" src="https://code.jquery.com/jquery-3.3.1.min.js"></script>
    <script type="text/javascript" language="javascript" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"></script>
    <script type="text/javascript" language="javascript">
        $(document).ready( function () {
            $('#resultlist').DataTable({paging: false, ordering: false});
        } );
    </script>
  </head>
  <body>
  <h2>clang-tidy results from 2018-09-28, ROOT master (C++14, Python3), ROOT commit 4831835e28fe3f182409bea54dc61b148e1461a0</h2>
  <div class=bugs>Known problems: Github link to include files and roottest is broken; system include files from /include wrongly listed under include; bugprone* checks for the interpreter directory incomplete</div>
  <%= content %>
  </body>
</html>
