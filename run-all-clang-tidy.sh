#!/bin/bash

set -e

N_CPUS_AVAILABLE=$(grep processor /proc/cpuinfo | wc -l)

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

    echo "Checking category $category"
    run-clang-tidy-7.py -quiet -header-filter=.\* -checks="-*,$checkers" -j1 \
        ../src \
        2> /dev/null \
        | grep -v -- "-checks=-\*,$checkers" \
        > "clang-tidy/$category.log" &
    maxbg 8 1

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
| grep -v modernize-use-emplace                                  \
| grep -v modernize-use-equals-default                           \
| grep -v modernize-use-equals-delete                            \
| grep -v modernize-use-override                                 \
| grep -v readability-braces-around-statements                   \
| grep -v readability-implicit-bool-cast                         \
| grep -v readability-implicit-bool-conversion                   \
    | perl -nE 'chomp;s/ //g;next unless $_;($cat,$c) = split/-/,$_,2;push @{$all{$cat}},$_;END{while(($k,$v)=each%all){print"$k ";say join ",", @$v}}' \
    |sort
)

wait

