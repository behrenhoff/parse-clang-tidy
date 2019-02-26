# parse-clang-tidy

Using the scripts in this repository, you can

* parse the output of clang-tidy
* store the result in a sqlite3 database
* create a single-page website for fulltext search (for small projects only)
* create a webapp (using a local webserver) for overview in large projects

## Before you begin

### Dependencies
* Perl >= 5.18
* Mojolicious (if you want to run the gui)
* SQLite3 and corresponding Perl DBD driver
* and of course: clang-tidy!

On Ubuntu, run:

```
sudo apt-get install perl libmojolicious-perl libdbi-perl libdbd-sqlite3-perl libfile-slurp-perl libtext-wrapi18n-perl
```

Of course, clang-tidy need to be installed as well. Either build from source or download binaries. For Ubuntu, go to `https://apt.llvm.org/` and follow the instructions (run `sudo apt-get install clang-tidy-7` after adding the corresponding package) In case you install the Ubuntu packages, the files will contain the version number, i.e. instead of `run-clang-tidy.py`, your file will be named `run-clang-tidy-7.py` or similar.

### Patching clang-tidy

Clang-tidy doesn't flush properly, therefore the result can get messy. Simpy replace "sys.stdout.write" with "print" to fix the problem, as can be seen in the following patch for run-clang-tidy.py:

```
+++ b/clang-tidy/tool/run-clang-tidy.py
@@ -167,7 +167,7 @@ def run_tidy(args, tmpdir, build_path, queue, lock, failed_files):
     if proc.returncode != 0:
       failed_files.append(name)
     with lock:
-      sys.stdout.write(' '.join(invocation) + '\n' + output.decode('utf-8') + '\n')
+      print(' '.join(invocation) + '\n' + output.decode('utf-8') + '\n')
       if len(err) > 0:
         sys.stderr.write(err.decode('utf-8') + '\n')
     queue.task_done()
```

### Quick start

Run cmake:

`cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 /path/to/source`

A file `compile_commands.json` will be created.

Run: `run-clang-tidy -checks=\* | tee output.log`

Now open the file `parse-clang-tidy-log.pl` and change the variables `$srcpath` and `$buildpath` (within the top few lines of the file) so they point to your source and build directory (TODO: determine automatically from CMakeCache.txt).

Then run: `/path/to/parse-clang-tidy-log.pl output.log`

Two files will be created: `result.sqlite` (WARNING: results will be APPENDED to the database. So delete the file first if you want to rerun!) and `test.js`.
Finally copy the file `test.html` from the this repository to the current directory. Then open `test.html` in a browser.
Alternatively, run `sqlite3 result.sql` to view the database.


### Running the GUI

Create a mapping for include files. Unless you use this project for ROOT, just run:

`echo '{}' > include_to_src.json`

Then start the GUI (in the directory of the results.sqlite DB):

`morbo /path/to/gui.pl`

Then open a browser and navigate to: `http://127.0.0.1:3000`

## Advanced stuff

Running on large projects can cause problems if your log file is several 10 or 100 gigabytes large. So you cannot keep everything in RAM. To solve the problem, run clang-tidy multiple times for different checks. For example, run one clang-tidy instance for checks=bugprone*, one instance for modernize checks, ... (don't forget to disable all other checks!). Store the results in different log files. Then parse one log file at a time. Since `parse-clang-tidy-log.pl` appends to the database, your DB will contain the full result at the end. On the other hand, please do not split on subdirectories for memory reasons during parsing. Problem is, if you do, you still need to parse all log file outputs of the same checker at the same time to avoid duplicates from header files. You CAN however do this split for performance reasons. Have a look at the .sh files in this project. They split by subdirectory and by checker.

## Final word of warning

This program was written with [ROOT](https://root.cern.ch) in mind and several ROOT specialties might still be hardcoded, e.g. the git commit hash when I ran this...
