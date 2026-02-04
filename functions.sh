# Print usage/help
usage() {
  local SCRIPT_NAME

  SCRIPT_NAME="$(basename "$0")"

  cat <<EOF

${SCRIPT_NAME}: ${SCRIPT_DESCRIPTION}

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  --config-file|-c FILE    Use config/FILE instead of the default config.sh
  --prune|-p               Prune old snaps, per max_snap_age_days config setting
  --help                   Show this help and exit

Notes:
  - If --config-file is not specified, ${SCRIPT_NAME} uses ./config.sh
  - Config files specified with --config-file must live in ./config/

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --config-file prod.sh
  ${SCRIPT_NAME} --config-file=staging.sh
EOF
}


# Parse command-line options.
parse_options() {
  CONFIG_FILE_OVERRIDE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config-file|-c)
        if [[ -z "$2" || "$2" == --* ]]; then
          echo "--config-file requires an argument"
          exit 1
        fi
        CONFIG_FILE_OVERRIDE="$2"
        shift 2
        ;;
      --config-file=*)
        CONFIG_FILE_OVERRIDE="${1#*=}"
        shift
        ;;
      --prune|-p)
        IS_PRUNE="1"
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
}

source_config() {
  local CONFIGFILE
  local CONFIG_BASENAME

  if [[ -n "${CONFIG_FILE_OVERRIDE}" ]]; then
    CONFIG_BASENAME="$(basename "${CONFIG_FILE_OVERRIDE}")"
    CONFIGFILE="${MYDIR}/config/${CONFIG_BASENAME}"
  else
    CONFIGFILE="${MYDIR}/config.sh"
  fi

  if [[ -e "${CONFIGFILE}" ]]; then
    echo "Using config file: ${CONFIGFILE}"
    source "${CONFIGFILE}"
  else
    echo "Could not read required config file at ${CONFIGFILE}. Exiting."
    exit 1
  fi
}

make_target_dir(){
  TARGET_DIR="${backup_dir}/backup_$(date +%m%d%Y_%H%M%S)";
  echo "Target dir: $TARGET_DIR";
  mkdir -p $TARGET_DIR;
}

timestamp_target_dir(){
  # Create a timestamp file for this backup.
  echo "This file's timestamp is the creation time of this backup." > $TARGET_DIR/BACKUP_TIMESTAMP
}

# Dump wp and civcirm databases
db_snap() {
  MYSQL_OPTIONS=""
  if [[ -n "$mysql_host" ]]; then
    MYSQL_OPTIONS=" --host=$mysql_host"
  fi
  if [[ -n "$mysql_port" ]]; then
    MYSQL_OPTIONS="$MYSQL_OPTIONS --port=$mysql_port"
  fi

  echo "Archiving databases ..."
  echo "  Wordpress ..."
  mysqldump -u $mysql_user --password="$mysql_password" --no-tablespaces --routines $MYSQL_OPTIONS $mysql_database_wordpress | gzip > $TARGET_DIR/cms.sql.gz

  if [[ -n $mysql_database_civicrm ]]; then
    if [[ -z "$mysql_user_civicrm" ]]; then
      mysql_user_civicrm="$mysql_user";
    fi
    if [[ -z "$mysql_password_civicrm" ]]; then
      mysql_password_civicrm="$mysql_password";
    fi
    if [[ -z "$mysql_host_civicrm" ]]; then
      mysql_host_civicrm="$mysql_host";
    fi
    if [[ -z "$mysql_port_civicrm" ]]; then
      mysql_port_civicrm="$mysql_port";
    fi
    MYSQL_OPTIONS=""
    if [[ -n "$mysql_host_civicrm" ]]; then
      MYSQL_OPTIONS=" --host=$mysql_host_civicrm"
    fi
    if [[ -n "$mysql_port_civicrm" ]]; then
      MYSQL_OPTIONS="$MYSQL_OPTIONS --port=$mysql_port_civicrm"
    fi
    echo "  CiviCRM..."
    mysqldump -u $mysql_user_civicrm --password="$mysql_password_civicrm" --no-tablespaces --routines $MYSQL_OPTIONS $mysql_database_civicrm | gzip > $TARGET_DIR/civicrm.sql.gz
  fi

  timestamp_target_dir;
}

# archive files
file_snap() {
  if [[ "$use_sudo" == "1" ]]; then
    sudocmd="sudo"
    echo "Acquiring sudo access ..."
    sudo echo "Thank you."
  fi

  echo "Archiving files ..."
  cd $wp_root_dir;
  cd ..
  wp_root_basename=$(basename $wp_root_dir);
  $sudocmd tar --exclude="${wp_root_basename}/wp-content/updraft" -czf $TARGET_DIR/files.tgz "$wp_root_basename";
  if [[ "$use_sudo" == "1" ]]; then
    # ensure files.tgz doesn't remain root:root, instead copy ownership from $TARGET_DIR
    sudo chown --reference=$TARGET_DIR $TARGET_DIR/files.tgz
  fi
  timestamp_target_dir;
}

# Ensure configurations are valid
validate_config_or_exit() {
  local has_bad_config=0
  # Test whether $max_snap_age_days is an integer > -1
  if [[ -n "${max_snap_age_days}" ]]; then
    if [[ ! $max_snap_age_days =~ ^[1-9][0-9]*$ ]]; then
      echo "CONFIGURATION INVALID: max_snap_age_days must be a positive integer: '${max_snap_age_days}' found"
      has_bad_config=1
    fi
  fi

  if [[ "$has_bad_config" != "0" ]]; then
    echo "CONFIGURATION INVALID. See notes above."
    exit 1;
  fi
}

# Prune old snaps if so configured and instructed.
prune_old_snaps() {
  # Note:
  #   $IS_PRUNE was set in parse_options().

  # Redundantly call validate_config_or_exit(). It was already called in the
  # main script body, but this is a destructive function, so we prefer the
  # redundant check.
  validate_config_or_exit;

  if [[ "$IS_PRUNE" != "1" || -z "$max_snap_age_days" ]]; then
    return;
  fi
  if [[ ! -d "$backup_dir" ]]; then
    return;
  fi
  find "$backup_dir" -mindepth 2 -maxdepth 2 -type f -name "BACKUP_TIMESTAMP" -mtime +"$max_snap_age_days" -printf '%h\0' | sort -zu |
  while IFS= read -r -d '' snapdir; do
    echo "Pruning old snap: $snapdir"
    rm -r --one-file-system -- "$snapdir";
  done
}