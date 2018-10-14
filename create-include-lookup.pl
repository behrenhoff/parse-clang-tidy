#!/usr/bin/perl

use 5.18.0;
use warnings;
use File::Find;
use Mojo::JSON qw(to_json);

my ($rootsrcdir, $builddir) = @ARGV;
if (! defined $builddir || ! -d $rootsrcdir || ! -d $builddir) {
    die "Usage: $0 /path/to/roots/sourcedir /path/to/builddir";
}

my @headers;
my %fastfind; # lookup table for single filename without path
sub wantedRootSource {
    return if -d || /\.(?:cpp|cxx|txt|html|ttf|otf|md|yml)$/i;
    my $filename = substr($_, length($rootsrcdir) + 1);
    push @headers, $filename;
    $filename =~ m#(?:.*/|^)(.*)#;
    push @{$fastfind{$1}}, $filename;
}

my %incToSrc;
sub wantedBuilddir {
    return if -d;
    return if /(?:modulemap|html)$/;
    my $relFile = substr($_, length($builddir) + length("include") + 2);
    my $fastResult = $fastfind{$relFile};
    if (defined $fastResult && @$fastResult == 1) {
        $incToSrc{$relFile} = [$fastResult->[0]];
    } else {
        $incToSrc{$relFile} = [grep /\Q$relFile\E$/, @headers];
    }
}

find({wanted => \&wantedRootSource, no_chdir => 1}, $rootsrcdir);
find({wanted => \&wantedBuilddir, no_chdir => 1}, "$builddir/include");
open my $out, ">", "include_to_src.json" or die $!;
print $out to_json(\%incToSrc);
