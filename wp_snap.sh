#!/bin/bash

# This script aims to adhere to the Google Bash Style Guide:
# https://google.github.io/styleguide/shell.xml

# Full system path to the directory containing this file, with trailing slash.
# This line determines the location of the script even when called from a bash
# prompt in another directory (in which case `pwd` will point to that directory
# instead of the one containing this script).  See http://stackoverflow.com/a/246128
mydir="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )/"

# Include functions script.
if [[ -e ${mydir}/functions.sh ]]; then
  source ${mydir}/functions.sh
else 
  echo "Could not find required functions file at ${mydir}/functions.sh. Exiting."
  exit 1
fi

source_config;
make_target_dir;
file_snap;
db_snap;

echo "Done. Target dir: $DIRNAME";
