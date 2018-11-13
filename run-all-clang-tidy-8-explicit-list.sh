#!/bin/bash

set -e


#rct=run-clang-tidy-7.py
#ctPath=-clang-tidy-binary

rct=/home/behrenhoff/src/llvm/tools/clang/tools/extra/clang-tidy/tool/run-clang-tidy.py
ctPath=/home/behrenhoff/src/llvm-build/bin/clang-tidy
logDir=clang-tidy_head


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

mkdir -p "$logDir"

# -export-fixes="$logDir/$category.fix.yaml" \
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
        if [[ "$topdir" == "interpreter" ]] ; then # && [[ "$category" == "bugprone-exception-escape" ]]; then
            # Exclude large LLVM directory for bugprone-exception-escape
            # since it runs forever
            continue
        fi

        echo "Checking category $category in $topdir"
        mkdir -p "$logDir/$topdir"
        "$rct" -clang-tidy-binary "$ctPath" -quiet -header-filter=.\* -checks="-*,$checkers" -j1 \
            "$srcdir" \
            2> /dev/null \
            | grep -v -- "-checks=-\*,$checkers" \
            > "$logDir/$topdir/$category.log" &
        maxbg $N_CPUS_AVAILABLE 1

    done

done < <( \
perl -E'print q(
    boost-use-to-string
    bugprone-argument-comment
    bugprone-assert-side-effect
    bugprone-bool-pointer-implicit-conversion
    bugprone-copy-constructor-init
    bugprone-dangling-handle
    bugprone-exception-escape
    bugprone-fold-init-type
    bugprone-forward-declaration-namespace
    bugprone-forwarding-reference-overload
    bugprone-inaccurate-erase
    bugprone-incorrect-roundings
    bugprone-integer-division
    bugprone-lambda-function-name
    bugprone-macro-repeated-side-effects
    bugprone-misplaced-operator-in-strlen-in-alloc
    bugprone-misplaced-widening-cast
    bugprone-move-forwarding-reference
    bugprone-multiple-statement-macro
    bugprone-narrowing-conversions
    bugprone-parent-virtual-call
    bugprone-sizeof-container
    bugprone-sizeof-expression
    bugprone-string-constructor
    bugprone-string-integer-assignment
    bugprone-string-literal-with-embedded-nul
    bugprone-suspicious-enum-usage
    bugprone-suspicious-memset-usage
    bugprone-suspicious-missing-comma
    bugprone-suspicious-semicolon
    bugprone-suspicious-string-compare
    bugprone-swapped-arguments
    bugprone-terminating-continue
    bugprone-throw-keyword-missing
    bugprone-undefined-memory-manipulation
    bugprone-undelegated-constructor
    bugprone-unused-raii
    bugprone-unused-return-value
    bugprone-use-after-move
    bugprone-virtual-near-miss
    cert-dcl03-c
    cert-dcl16-c
    cert-dcl21-cpp
    cert-dcl50-cpp
    cert-dcl54-cpp
    cert-dcl58-cpp
    cert-dcl59-cpp
    cert-env33-c
    cert-err09-cpp
    cert-err34-c
    cert-err52-cpp
    cert-err58-cpp
    cert-err60-cpp
    cert-err61-cpp
    cert-fio38-c
    cert-flp30-c
    cert-msc30-c
    cert-msc32-c
    cert-msc50-cpp
    cert-msc51-cpp
    cert-oop11-cpp
    clang-analyzer-apiModeling.StdCLibraryFunctions
    clang-analyzer-apiModeling.TrustNonnull
    clang-analyzer-apiModeling.google.GTest
    clang-analyzer-core.CallAndMessage
    clang-analyzer-core.DivideZero
    clang-analyzer-core.DynamicTypePropagation
    clang-analyzer-core.NonNullParamChecker
    clang-analyzer-core.NonnilStringConstants
    clang-analyzer-core.NullDereference
    clang-analyzer-core.StackAddressEscape
    clang-analyzer-core.UndefinedBinaryOperatorResult
    clang-analyzer-core.VLASize
    clang-analyzer-core.builtin.BuiltinFunctions
    clang-analyzer-core.builtin.NoReturnFunctions
    clang-analyzer-core.uninitialized.ArraySubscript
    clang-analyzer-core.uninitialized.Assign
    clang-analyzer-core.uninitialized.Branch
    clang-analyzer-core.uninitialized.CapturedBlockVariable
    clang-analyzer-core.uninitialized.UndefReturn
    clang-analyzer-cplusplus.InnerPointer
    clang-analyzer-cplusplus.NewDelete
    clang-analyzer-cplusplus.NewDeleteLeaks
    clang-analyzer-cplusplus.SelfAssignment
    clang-analyzer-deadcode.DeadStores
    clang-analyzer-nullability.NullPassedToNonnull
    clang-analyzer-nullability.NullReturnedFromNonnull
    clang-analyzer-nullability.NullableDereferenced
    clang-analyzer-nullability.NullablePassedToNonnull
    clang-analyzer-nullability.NullableReturnedFromNonnull
    clang-analyzer-optin.cplusplus.VirtualCall
    clang-analyzer-optin.mpi.MPI-Checker
    clang-analyzer-optin.osx.cocoa.localizability.EmptyLocalizationContextChecker
    clang-analyzer-optin.osx.cocoa.localizability.NonLocalizedStringChecker
    clang-analyzer-optin.performance.GCDAntipattern
    clang-analyzer-optin.performance.Padding
    clang-analyzer-optin.portability.UnixAPI
    clang-analyzer-osx.API
    clang-analyzer-osx.NumberObjectConversion
    clang-analyzer-osx.ObjCProperty
    clang-analyzer-osx.SecKeychainAPI
    clang-analyzer-osx.cocoa.AtSync
    clang-analyzer-osx.cocoa.AutoreleaseWrite
    clang-analyzer-osx.cocoa.ClassRelease
    clang-analyzer-osx.cocoa.Dealloc
    clang-analyzer-osx.cocoa.IncompatibleMethodTypes
    clang-analyzer-osx.cocoa.Loops
    clang-analyzer-osx.cocoa.MissingSuperCall
    clang-analyzer-osx.cocoa.NSAutoreleasePool
    clang-analyzer-osx.cocoa.NSError
    clang-analyzer-osx.cocoa.NilArg
    clang-analyzer-osx.cocoa.NonNilReturnValue
    clang-analyzer-osx.cocoa.ObjCGenerics
    clang-analyzer-osx.cocoa.RetainCount
    clang-analyzer-osx.cocoa.RunLoopAutoreleaseLeak
    clang-analyzer-osx.cocoa.SelfInit
    clang-analyzer-osx.cocoa.SuperDealloc
    clang-analyzer-osx.cocoa.UnusedIvars
    clang-analyzer-osx.cocoa.VariadicMethodTypes
    clang-analyzer-osx.coreFoundation.CFError
    clang-analyzer-osx.coreFoundation.CFNumber
    clang-analyzer-osx.coreFoundation.CFRetainRelease
    clang-analyzer-osx.coreFoundation.containers.OutOfBounds
    clang-analyzer-osx.coreFoundation.containers.PointerSizedValues
    clang-analyzer-security.FloatLoopCounter
    clang-analyzer-security.insecureAPI.UncheckedReturn
    clang-analyzer-security.insecureAPI.bcmp
    clang-analyzer-security.insecureAPI.bcopy
    clang-analyzer-security.insecureAPI.bzero
    clang-analyzer-security.insecureAPI.getpw
    clang-analyzer-security.insecureAPI.gets
    clang-analyzer-security.insecureAPI.mkstemp
    clang-analyzer-security.insecureAPI.mktemp
    clang-analyzer-security.insecureAPI.rand
    clang-analyzer-security.insecureAPI.strcpy
    clang-analyzer-security.insecureAPI.vfork
    clang-analyzer-unix.API
    clang-analyzer-unix.Malloc
    clang-analyzer-unix.MallocSizeof
    clang-analyzer-unix.MismatchedDeallocator
    clang-analyzer-unix.Vfork
    clang-analyzer-unix.cstring.BadSizeArg
    clang-analyzer-unix.cstring.NullArg
    clang-analyzer-valist.CopyToSelf
    clang-analyzer-valist.Uninitialized
    clang-analyzer-valist.Unterminated
    cppcoreguidelines-avoid-goto
    cppcoreguidelines-no-malloc
    cppcoreguidelines-slicing
    cppcoreguidelines-special-member-functions
    google-build-explicit-make-pair
    google-runtime-int
    google-runtime-operator
    hicpp-deprecated-headers
    hicpp-exception-baseclass
    hicpp-explicit-conversions
    hicpp-function-size
    hicpp-invalid-access-moved
    hicpp-member-init
    hicpp-move-const-arg
    hicpp-multiway-paths-covered
    hicpp-named-parameter
    hicpp-new-delete-operators
    hicpp-no-assembler
    hicpp-noexcept-move
    hicpp-static-assert
    hicpp-undelegated-constructor
    hicpp-uppercase-literal-suffix
    hicpp-vararg
    misc-definitions-in-headers
    misc-misplaced-const
    misc-new-delete-overloads
    misc-non-copyable-objects
    misc-non-private-member-variables-in-classes
    misc-redundant-expression
    misc-static-assert
    misc-throw-by-value-catch-by-reference
    misc-unconventional-assign-operator
    misc-uniqueptr-reset-release
    misc-unused-alias-decls
    misc-unused-parameters
    misc-unused-using-decls
    mpi-buffer-deref
    mpi-type-mismatch
    objc-avoid-nserror-init
    objc-avoid-spinlock
    objc-forbidden-subclassing
    objc-property-declaration
    performance-faster-string-find
    performance-for-range-copy
    performance-implicit-conversion-in-loop
    performance-inefficient-algorithm
    performance-inefficient-string-concatenation
    performance-inefficient-vector-operation
    performance-move-const-arg
    performance-move-constructor-init
    performance-noexcept-move-constructor
    performance-type-promotion-in-math-fn
    performance-unnecessary-copy-initialization
    performance-unnecessary-value-param
    portability-simd-intrinsics
    readability-const-return-type
    readability-container-size-empty
    readability-delete-null-pointer
    readability-deleted-default
    readability-else-after-return
    readability-function-size
    readability-identifier-naming
    readability-implicit-bool-conversion
    readability-inconsistent-declaration-parameter-name
    readability-misleading-indentation
    readability-misplaced-array-index
    readability-named-parameter
    readability-non-const-parameter
    readability-redundant-control-flow
    readability-redundant-declaration
    readability-redundant-function-ptr-dereference
    readability-redundant-member-init
    readability-redundant-smartptr-get
    readability-redundant-string-cstr
    readability-redundant-string-init
    readability-simplify-boolean-expr
    readability-simplify-subscript-expr
    readability-static-accessed-through-instance
    readability-static-definition-in-anonymous-namespace
    readability-string-compare
    readability-uniqueptr-delete-release
    readability-uppercase-literal-suffix
    zircon-temporary-objects
)' \
| perl -nE 'chomp;
            s/ //g;
            next unless $_;
            if ($_ eq "bugprone-macro-parentheses") { # produces a LOT of output
                push @{$all{$_}}, $_;
            } elsif (/modernize-use-(emplace|equals-default|equals-delete|override)/) {
                push @{$all{"modernize-use"}}, $_;
            } elsif (/^(?:zircon|portability|mpi|objc|boost|google)-/) {
                ($cat, $c) = split/-/, $_, 2;
                push @{$all{"misc"}}, $_;
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


#
#     clang-tidy-7 -list-checks -checks=\* \
# | grep -v Enabled                                                \
# | grep -v braces-around-statements                               \
# | grep -v cppcoreguidelines-owning-memory                        \
# | grep -v cppcoreguidelines-pro-bounds-array-to-pointer-decay    \
# | grep -v cppcoreguidelines-pro-bounds-constant-array-index      \
# | grep -v cppcoreguidelines-pro-bounds-pointer-arithmetic        \
# | grep -v cppcoreguidelines-pro-type-member-init                 \
# | grep -v cppcoreguidelines-pro-type-vararg                      \
# | grep -v cppcoreguidelines-special-member-functions             \
# | grep -v fuchsia-default-arguments                              \
# | grep -v fuchsia-overloaded-operator                            \
# | grep -v google-build-using-namespace                           \
# | grep -v google-default-arguments                               \
# | grep -v google-readability-braces-around-statements            \
# | grep -v google-readability-namespace-comments                  \
# | grep -v google-runtime-references                              \
# | grep -v hicpp-braces-around-statements                         \
# | grep -v hicpp-no-array-decay                                   \
# | grep -v hicpp-use-auto                                         \
# | grep -v hicpp-use-equals-default                               \
# | grep -v hicpp-use-equals-delete                                \
# | grep -v hicpp-use-override                                     \
# | grep -v hicpp-vararg                                           \
# | grep -v llvm-header-guard                                      \
# | grep -v llvm-include-order                                     \
# | grep -v llvm-namespace-comment                                 \
# | grep -v modernize-pass-by-value                                \
# | grep -v readability-braces-around-statements                   \
# | grep -v readability-implicit-bool-cast                         \
# | grep -v readability-implicit-bool-conversion                   \
# | perl -nE 'chomp;
#             s/ //g;
#             next unless $_;
#             if ($_ eq "bugprone-macro-parentheses") { # produces a LOT of output
#                 push @{$all{$_}}, $_;
#             } elsif (/modernize-use-(emplace|equals-default|equals-delete|override)/) {
#                 push @{$all{"modernize-use"}}, $_;
#             } else {
#                 ($cat, $c) = split/-/, $_, 2;
#                 push @{$all{$cat}}, $_;
#             }
#             END {
#                 while (($k, $v) = each %all) {
#                     print "$k ";
#                     say join ",", @$v;
#                 }
#             }' \
# | sort
# )

wait
