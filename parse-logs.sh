#!/bin/bash

logdir="$1"
if ! [[ -d "$logdir" ]] ; then
	echo 'Please pass the logfile directory as argument'
	exit 1
fi


# Search for all *.log files and keep unique filenames
# Then process all files by a specific checker at the same time to avoid
# duplicate entries in the database.

for i in $(find "$logdir" -name \*.log -exec basename {} \; | sort -u); do 
	./parse-clang-tidy-log.pl "$logdir"/*/$i
done

