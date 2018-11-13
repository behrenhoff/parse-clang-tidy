#!/usr/bin/perl

use DBI;
use File::Slurp;
use List::Util;
use Mojolicious::Lite;
use Mojo::JSON qw(from_json);
# use Mojo::SQLite;
use Text::Wrap qw(wrap); $Text::Wrap::columns = 120;

my $includeLookup = from_json(read_file("include_to_src.json"));

# helper sqlite => sub { state $sql = Mojo::SQLite->new('sqlite:result.sqlite') };
helper sqlite => sub {
    my $dbh = DBI->connect("dbi:SQLite:dbname=result.sqlite","","", {});
    return $dbh;
};
 
get '/' => sub {
    my $c  = shift;
    my $db = $c->sqlite; # no Mojo::SQLite
    # my $db = $c->sqlite->db;
    my $ary_ref  = $db->selectall_arrayref("select topdir, checker, count(*) from result group by topdir, checker;");
    my %nEntriesPerDirChecker;
    my %checkerGroups;
    my %topdirs;
    for my $row (@$ary_ref) {
        my ($topdir, $checker, $count) = @$row;
        my $chGroup = ($checker =~ /^(\w+)-/)[0];

        $nEntriesPerDirChecker{$topdir}{$checker} = $count;
        $nEntriesPerDirChecker{$topdir}{$chGroup} += $count;

        $topdirs{$topdir} = 1;
        push @{$checkerGroups{$chGroup}}, $checker
            unless grep { $checker eq $_ } @{$checkerGroups{$chGroup}};
    }

    $c->render(template => 'overview',
               nEntries => \%nEntriesPerDirChecker,
               checkers => [map [$_, $checkerGroups{$_}], sort keys %checkerGroups],
               topdirs => [sort keys %topdirs]);
};


get '/detail' => sub {
    my $c  = shift;
    my $db = $c->sqlite; # no Mojo::SQLite
    # my $db = $c->sqlite->db;

    my $checker = $c->param('c');
    my $topdir = $c->param('topdir');

    #CREATE TABLE result (file TEXT, topdir TEXT, checker TEXT, line INTEGER, col INTEGER, code TEXT);
    my $problems;
    my $query = "select file, checker, line, col, code from result ";
    my $orderby = "order by checker, file, line";
    if ($checker && $topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ? and checker LIKE ? $orderby;",
            {Slice=>{}}, $topdir, "$checker\%");
    } elsif ($checker) {
        $problems = $db->selectall_arrayref(
            "$query where checker LIKE ? $orderby;",
            {Slice=>{}}, "$checker\%");
    } elsif ($topdir) {
        $problems = $db->selectall_arrayref(
            "$query where topdir = ? $orderby;",
            {Slice=>{}}, $topdir);
    } else {
        $c->redirect_to('/');
    }
    for my $p (@$problems) {
        if ($p->{file} =~ s!^include/!!) {
            # we are dealing with include files...
            my $fn = $p->{file};
            $fn =~ s/^include\///;
            my $lookup = $includeLookup->{$fn};
            # die "Error $p->{file}" if !$lookup;
            if (!defined $lookup || @$lookup == 0) {
                $p->{file} .= "\n<br>Could not find file in source tree.";
            } elsif (@$lookup == 1) {
                $p->{url} = $lookup->[0];
            } else {
                $p->{file} = "Unclear file origin. Candidates:<br>\n" . join(" or<br>\n", @$lookup);
            }
        } elsif ($p->{file} !~ m!^/!) {
            $p->{url} = $p->{file};
        }
        $p->{code} = wrap('', '', $p->{code});
    }

    $c->render(template => 'detail',
               problems => $problems,
               srcprefix => 'https://github.com/root-project/root/blob/c716de08e98d51a2b17bd2aa29e19d3402ec81e8/'
               );
};

app->start;


__DATA__

@@ overview.html.ep
% title 'clang-tidy - ROOT - quick overview';
% layout 'defaultLayout';

<table class=overview>
    <tr>
    <th style="text-align:center">
        <a href="#" onclick="show_all(); return false;">[Expand all]</a> |
        <a href="#" onclick="hide_all(); return false;">[Hide details]</a>
    </th>
    <% for my $topdir (@$topdirs) { %>
        <th style="text-align:center"><a href="detail?topdir=<%= $topdir %>"><%= $topdir %></a></th>
    <% } %>
    </tr>

    <% for my $cgroupRef (@$checkers) {
            my ($cgroup, $clist) = @$cgroupRef; %>
            <tr class="group <%= $cgroup %>">
            <th><a href="detail?c=<%= $cgroup %>"><%= $cgroup %></a>
                <span class="show <%= $cgroup %>"><a href="#" onclick="show_group('<%= $cgroup %>'); return false;">[Expand]</a></span>
                <span class="hide <%= $cgroup %>"><a href="#" onclick="hide_group('<%= $cgroup %>'); return false;">[Collapse]</a></span>
            </th>
            <% for my $topdir (@$topdirs) { %>
                <td><a href="detail?c=<%= $cgroup %>&amp;topdir=<%= $topdir %>"><%= $nEntries->{$topdir}{$cgroup} %></a></td>
            <% } %>
            </tr>

            <% for my $c (@$clist) { %>
                <tr class="checker <%= $cgroup %>">
                <th><a href="detail?c=<%= $c %>"><%= $c %></a></th>
                <% for my $topdir (@$topdirs) { %>
                    <td><a href="detail?c=<%= $c %>&amp;topdir=<%= $topdir %>"><%= $nEntries->{$topdir}{$c} %></a></td>
                <% } %>
                </tr>
            <% } %>

    <% } %>
</table>

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
        <% if (exists $p->{url}) { %>
            <td><a href="<%= $srcprefix %><%= $p->{url} %>#L<%= $p->{line} %>"><%= $p->{file} %>:<%= $p->{line} %></a></td>
        <% } else { %>
            <td><%= $p->{file} %>:<%= $p->{line} %></td>
        <% } %>
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
    border: 1px solid #aaaaaa;
    padding: 3px 5px 3px 5px;
}

table.overview td {
    text-align: center;
    background-color: #f0f0f0;
}
table.overview th {
    text-align: left;
    background-color: lightgrey;
}

table.overview tr.group th,
table.overview tr.group td {
    /* background-color: #ceff5b; */
    background-color: #ffffff;
    height: 1.5em;
    font-weight: bold;
    font-size: 13px;
}
table.overview tr.checker th {
    padding-left: 1em;
}

table.overview span.show { display: none; }

a {
     text-decoration: none;
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

        function show_all() {
            $("tr.checker").show();
            $("span.hide").show();
            $("span.show").hide();
        }

        function hide_all() {
            $("tr.checker").hide();
            $("span.hide").hide();
            $("span.show").show();
        }

        function show_group(g) {
            $("tr.checker." + g).show();
            $("span.hide." + g).show();
            $("span.show." + g).hide();
        }

        function hide_group(g) {
            $("tr.checker." + g).hide();
            $("span.hide." + g).hide();
            $("span.show." + g).show();
        }
    </script>
  </head>
  <body>
  <h2>clang-tidy-8 (head version) results from 2018-11-12, ROOT master (C++14, Python3), ROOT commit c716de08e98d51a2b17bd2aa29e19d3402ec81e8</h2>
  <div class=bugs>Known problems: everything is a bit slow, please be patient!</div>
  <%= content %>
  <div style="margin-top: 2em; margin-bottom:2em">Server hardware: Rapberry Pi Zero W!</div>
  <div style="font-size: x-small;color:grey">Impressum: Website betrieben von: Wolf Behrenhoff; Lobuschstr. 33; 22765 Hamburg; Germany<br>
Datenschutz: Der Webserver loggt die IP-Adressen und Uhrzeiten beim Abrufen dieser Webseite. Dieser Log dient der Fehlersuche bei Problemen und wird ansonsten nicht ausgewertet. Es gibt es hier keine Benutzerkonten und keine Cookies. Diese Website bindet Scripte von https://code.jquery.com und https://cdn.datatables.net ein, wo ihre IP-Adresse und ggf. weitere Daten erfasst werden können. Abgesehen davon werden keine Daten erhoben, gespeichert oder ausgewertet.
  </div>
  </body>
</html>
