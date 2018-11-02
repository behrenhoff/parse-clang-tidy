#!/bin/bash

set -e

# For running multi-core
N_CPUS_AVAILABLE=$(grep processor /proc/cpuinfo | wc -l)
if [[ "$1" == "-j" ]] && (( $2 > 0 )) && (( $2 < 2*$N_CPUS_AVAILABLE)) ; then
    N_CPUS_AVAILABLE=$2
    echo "Using $2 processes in parallel"
fi

maxbg() {
    local sleeptime=1
    local maxjobs=1
    if [[ "$1" != "" ]] ; then maxjobs="$1"; else maxjobs=$((($N_CPUS_AVAILABLE+1)/2)); fi
    if [[ "$2" != "" ]] ; then sleeptime="$2"; fi
    while [[ $(jobs | wc -l) -ge "$maxjobs" ]] ; do sleep "$sleeptime"; done
}

mkdir -p clang-tidy

# -export-fixes="clang-tidy/$category.fix.yaml" \
#        2> "clang-tidy/$category.errlog" \
#        | tail -n +5 \
#        | head -n -1 \

while read category checkers; do

    for srcdir in ../src/*; do
        # Only select source directories
        if ! [[ -d "$srcdir" ]] || ! [[ -e "$srcdir/CMakeLists.txt" ]]; then
            continue
        fi

        topdir=$(basename "$srcdir")
        if ! [[ "$topdir" == "interpreter" ]] && [[ "$category" == "bugprone-exception-escape" ]]; then
            # Exclude large LLVM directory for bugprone-exception-escape
            # since it runs forever
            continue
        fi

        echo "Checking category $category in $topdir"
        mkdir -p "clang-tidy/$topdir"
        run-clang-tidy-7.py -quiet -header-filter=.\* -checks="-*,$checkers" -j1 \
            "$srcdir" \
            2> /dev/null \
            | grep -v -- "-checks=-\*,$checkers" \
            > "clang-tidy/$topdir/$category.log" &
        maxbg $N_CPUS_AVAILABLE 1

    done

done < <( \
    clang-tidy-7 -list-checks -checks=\* \
| grep -v Enabled                                                \
| grep -v braces-around-statements                               \
| grep -v cppcoreguidelines-owning-memory                        \
| grep -v cppcoreguidelines-pro-bounds-array-to-pointer-decay    \
| grep -v cppcoreguidelines-pro-bounds-constant-array-index      \
| grep -v cppcoreguidelines-pro-bounds-pointer-arithmetic        \
| grep -v cppcoreguidelines-pro-type-member-init                 \
| grep -v cppcoreguidelines-pro-type-vararg                      \
| grep -v cppcoreguidelines-special-member-functions             \
| grep -v fuchsia-default-arguments                              \
| grep -v fuchsia-overloaded-operator                            \
| grep -v google-build-using-namespace                           \
| grep -v google-default-arguments                               \
| grep -v google-readability-braces-around-statements            \
| grep -v google-readability-namespace-comments                  \
| grep -v google-runtime-references                              \
| grep -v hicpp-braces-around-statements                         \
| grep -v hicpp-no-array-decay                                   \
| grep -v hicpp-use-auto                                         \
| grep -v hicpp-use-equals-default                               \
| grep -v hicpp-use-equals-delete                                \
| grep -v hicpp-use-override                                     \
| grep -v hicpp-vararg                                           \
| grep -v llvm-header-guard                                      \
| grep -v llvm-include-order                                     \
| grep -v llvm-namespace-comment                                 \
| grep -v modernize-pass-by-value                                \
| grep -v readability-braces-around-statements                   \
| grep -v readability-implicit-bool-cast                         \
| grep -v readability-implicit-bool-conversion                   \
| perl -nE 'chomp;
            s/ //g;
            next unless $_;
            if ($_ eq "bugprone-macro-parentheses") { # produces a LOT of output
                push @{$all{$_}}, $_;
            } elsif (/modernize-use-(emplace|equals-default|equals-delete|override)/) {
                push @{$all{"modernize-use"}}, $_;
            } else {
                ($cat, $c) = split/-/, $_, 2;
                push @{$all{$cat}}, $_;
            }
            END {
                while (($k, $v) = each %all) {
                    print "$k ";
                    say join ",", @$v;
                }
            }' \
| sort
)

wait
