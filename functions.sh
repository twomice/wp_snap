# Print usage/help
usage() {
  local SCRIPT_NAME

  SCRIPT_NAME="$(basename "$0")"

  cat <<EOF

${SCRIPT_NAME}: ${SCRIPT_DESCRIPTION}

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  --config-file|-c FILE    Use config/FILE instead of the default config.sh
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
    source "${CONFIGFILE}"
  else
    echo "Could not read required config file at ${CONFIGFILE}. Exiting."
    exit 1
  fi
}

make_target_dir(){
  DIRNAME="${backup_dir}/backup_$(date +%m%d%Y_%H%M%S)";
  echo "Target dir: $DIRNAME";
  mkdir -p $DIRNAME;
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
  mysqldump -u $mysql_user --password="$mysql_password" --no-tablespaces --routines $MYSQL_OPTIONS $mysql_database_wordpress | gzip > $DIRNAME/cms.sql.gz

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
    mysqldump -u $mysql_user_civicrm --password="$mysql_password_civicrm" --no-tablespaces --routines $MYSQL_OPTIONS $mysql_database_civicrm | gzip > $DIRNAME/civicrm.sql.gz
  fi

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
  $sudocmd tar --exclude="${wp_root_basename}/wp-content/updraft" -czf $DIRNAME/files.tgz "$wp_root_basename";
}