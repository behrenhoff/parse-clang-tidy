#!/usr/bin/perl

use 5.18.0;
use warnings;
use Data::Dumper;

my $fileremove = '/home/behrenhoff/root-head/';
my $disabledCheckersRE = 'cppcoreguidelines-owning-memory|modernize|hicpp-use-auto|hicpp-no-array-decay|hicpp-vararg|readability-non-const-parameter|google-readability-namespace-comments|hicpp-use-nullptr|google-readability-casting|cppcoreguidelines-pro-type-cstyle-cast|hicpp-signed-bitwise';


# my @dirs = qw(core doc documentation geom graf2d graf3d gui hist interpreter io macros main man math misc montecarlo net proof roofit rootx sql test tmva tree tutorials);

# my $filelimit = shift @ARGV;

sub useFile {
    my $fn = shift;
    #/home/behrenhoff/root-head/src/
        return 1;
    #return $fn =~ m!/tmva/tmva/!;
#     return $fn =~ m!$filelimit!;
}

sub checkerIsDiabled {
   return shift =~ /$disabledCheckersRE/;
}

sub parseInput {
    my %files;
    my %checkerCount;

    for my $filename (@ARGV) {
        say STDERR "Lesen von $filename ...";
        my $verbose = '';
        my ($file, $position, $message, $checker);
        open my $FH, '<', $filename or die $!;
        while (my $line = <$FH>) {
           if ($line =~ m#(/home\S+):(\d+:\d+): (.+)\[(.+?)(?:,-warnings-as-errors)\]$#) {
                 if ($file) {
                    if (useFile($file) && !checkerIsDiabled($checker)) {
                       ++$checkerCount{$checker} unless exists $files{$file}{$position}{$checker};
                       $files{$file}{$position}{$checker} = "$message\n$verbose"
                    }
                    $verbose = '';
                 }
                 ($file, $position, $message, $checker) = ($1, $2, $3, $4);
                 $file =~ s/\Q$fileremove//;
           } else {
                 if ($line !~ m# -quiet /home#) {
                    $line =~ s/\Q$fileremove//;
                    $verbose .= $line if $file;
                 }
            }
        }
    }
    return (\%files, \%checkerCount);
}

my ($files, $checkerCount) = parseInput();

say STDERR "Sorting...";
my @sortedCheckers = sort {$checkerCount->{$a} <=> $checkerCount->{$b}} keys %$checkerCount;
for my $checker (@sortedCheckers) {
    say "$checker: $checkerCount->{$checker}";
}

# for my $showChecker (@sortedCheckers) {
#     for my $filename (sort keys %$files) {
#         my $positionHref = $files->{$filename};
#         for my $position (map $_->[0], sort {$a->[1] <=> $b->[1]} map {[$_, (split/:/)[0]]} keys %$positionHref) {
#             my $checkerHref = $positionHref->{$position};
#             for my $checker (sort keys %$checkerHref) {
#                 next if $checker ne $showChecker;
#                 print "$filename:$position $checker\n", $checkerHref->{$checker};
#                 say "\n####################\n";
#             }
#         }
#     }
# }

use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=result.sqlite","","", {AutoCommit=>0});
$dbh->do("CREATE TABLE IF NOT EXISTS result (file TEXT, topdir TEXT, checker TEXT)");
my $dbInsert = $dbh->prepare("INSERT INTO result VALUES (?,?,?)");


open my $testjs, '>', "test.js" or die $!;
say $testjs "var dataSet = [";
my $count = 0;
RESULT: for my $showChecker (@sortedCheckers) {
    for my $filename (sort keys %$files) {
        my $positionHref = $files->{$filename};
        for my $position (map $_->[0], sort {$a->[1] <=> $b->[1]} map {[$_, (split/:/)[0]]} keys %$positionHref) {
            my $checkerHref = $positionHref->{$position};
            for my $checker (sort keys %$checkerHref) {
                next if $checker ne $showChecker;
                if ($filename =~ m#^src/(\w+)/.*\.cxx$#) {
                    $dbInsert->execute($filename, $1, $checker);
                }
                print $testjs "[";
                print $testjs join ", ", 
                              map qq("$_"), 
                                (map { quotejs($_) } $filename, $position, $checker), 
                                "<pre><code>" . quotejs($checkerHref->{$checker}) . "</code></pre>";
                say $testjs "],";
                last RESULT if ++$count == 2000;
            }
        }
    }
}
$dbh->commit();
$dbh->disconnect();
say $testjs "];";
my $jsRest = <<'ENDJS';
$(document).ready(function() {
    $('#ctdt').DataTable( {
        data: dataSet,
        columns: [
            { title: "File" },
            { title: "Position" },
            { title: "Checker" },
            { title: "Content" }
        ]
    } );
} );
ENDJS
say $testjs $jsRest;

sub quotejs {
    my ($result) = @_;
    $result =~ s/\\/\\\\/g;
    $result =~ s/\n/\\n/g;
    $result =~ s/"/\\"/g;
    $result =~ s/&/&amp;/g;
    $result =~ s/</&lt;/g;
    $result =~ s/>/&gt;/g;
    return $result;
}
