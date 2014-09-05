# E-resource access checker

A simple Ruby library and command line script to check for full-text access to
e-resource titles. Plain old URL/link checking won't alert you if one of your
ebook links points to a valid HTML page reading "NO ACCESS." This script will.

The script can currently check for access problems for the following
platforms/vendors (so far): 

- Alexander Street Press 
- Apabi
- Duke University Press ebooks (on HighWire platform)
- Ebrary
- EBSCOhost eBook Collection
- FMG Films on Demand
- ScienceDirect ebooks (Elsevier)
- SAGE Knowledge
- SAGE Research Methods Online 
- SerialsSolutions
- SpringerLink 
- University Press (inc. Oxford) Scholarship Online
- Wiley Online Library

The script can check for some other special issues on certain platforms:

- Nineteenth Century Collections Online - check for presence of "Related Volumes" section on an ebook landing page
- Endeca - check whether a record has been deleted or not

# Requirements
- You must have Ruby installed. This script has been tested on Ruby 1.9.3 and
  2.1.2
- You must currently also have [PhantomJS](http://phantomjs.org) installed.
  There are binary installations [available](http://phantomjs.org/download.html)
  for all major operating systems.

# Installation

When/if this is released as a gem it should be as simple as:

    gem install access_checker

For now:

    gem install bundle
    bundle install
    gem build
    gem install pkg/access_checker-0.0.1.gem

# How to use


## Prepare your input file

The script expects a .csv file containing URLs for which to check access. The
column containing the URL should normally be the last/right-most column. You may
include any number of columns (RecordID#, Title, Publication Date, etc.) to the
left of the URL column. Make sure there is only **one** URL per row.

(If your CSV has a header row, the columns may be in any order as you can
specify which column contains the URL:s.)

All URLs/titles in one input file must be in/on the same package/platform. 

If your URLs are prefixed with proxy strings, and you are running the script
from a location where proxying isn't needed for access, deleting the proxy
strings from the URLs first will speed up the script. Use Excel Replace All to
do this. 

Put the input file in any directory. Example location:

    C:\Users\you\data_dir\inputfile.csv

## Run the script

* Open your command line shell (this will be Windows PowerShell for most Windows
  users)
* In shell, move to the rubyscripts directory. Given the example locations
  listed above, you will type the following and then hit Enter: 

      cd C:\Users\you\data_dir

In your command line shell, type

    access_checker -l

Note the key for the provider of your e-resources and then type (substitute in
the key for your provider, the name of your actual input file and the desired
name for your actual output file): 

    access_checker -p key inputfile.csv -o outputfile.csv

Or, using shell input and output redirection:

    access_checker -p key < inputfile.csv > outputfile.csv

## Command line options

To see more command line options, type:

    access_checker --help

## Output

Script will output a .csv file containing all data from the input file, with
the two columns 'result' and 'message' appended.

## If the script chokes/dies (or you need to otherwise stop it) while running...

You don't have to start over from the beginning. Remove all rows already checked
(i.e. included in the output file) from the input file and restart the script,
using a different output file location, or use shell redirection to append to
the existing output file: 

    access_checker -p key < inputfile.csv >> outputfile.csv

The header row will be inserted into the output file again, so watch for that in
the final results. 

# How it works

First, this script does not access, download, or touch *ANY* actual full-text
content hosted by our providers. 

It simply visits the landing/description/info page for each ostensibly full-text
resource---the page a user clicking the link in a catalog record would be
brought to, at the same URL that our ILS link checker would ping. 

Depending on the platform/package, it checks for text indicating full or
restricted access a) displayed on that page; OR b) buried in the page source
code.
