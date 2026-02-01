# wp_snap.sh
Takes a full snapshot of WordPress/CiviCRM files and databases.

# wp_snap_db.sh
Takes a full snapshot of WordPress/CiviCRM databases only.

# wp_snap_files.sh
Takes a full snapshot of WordPress/CiviCRM files only.

============================
## INSTALLATION (default config):
1. Copy config.sh.dist to config.sh
2. Edit config.sh according to comments in that file.

============================
## OPTIONAL ADDITIONAL CONFIG:
1. Copy config.sh.dist to a file under config/.
2. Rename the file with a meaningful name, and edit it according to comments in
   that file.
3. You may repeat this for any number of named config files under config/, and
   use --config-file FILENAME to specify a named config file under config/.
4. Note that scripts will only use a single config file per invocation, i.e.,
   config files will not be combined.

============================
## USAGE:
Run any of the above scripts with --help to see usage.
