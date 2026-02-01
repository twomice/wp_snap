#!/bin/bash

# This script aims to adhere to the Google Bash Style Guide:
# https://google.github.io/styleguide/shell.xml

# Full system path to the directory containing this file, with trailing slash.
# This line determines the location of the script even when called from a bash
# prompt in another directory (in which case `pwd` will point to that directory
# instead of the one containing this script).  See http://stackoverflow.com/a/246128
MYDIR="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )/"

SCRIPT_DESCRIPTION="Take a snapshot of a given site's WordPress and CiviCRM database tables."

# Include functions script.
if [[ -e ${MYDIR}/functions.sh ]]; then
  source ${MYDIR}/functions.sh
else 
  echo "Could not find required functions file at ${MYDIR}/functions.sh. Exiting."
  exit 1
fi

parse_options "$@"
source_config;
make_target_dir;
db_snap;

echo "Done. Target dir: $DIRNAME";
