#!/usr/bin/env sh

# Exit if any command fails
set -e

get_container_id() {
  local compose_file=$1
  local service=$2
  if [ -z "${compose_file}" ] || [ -z "${service}" ]; then
    echo "usage: get_container_id <compose_file> <service>"
    exit 1
  fi

 # first line of jq normalizes for docker compose breaking change, see docker/compose#10958
  docker compose --file $compose_file ps --format json --status running \
    | jq -sc '.[] | if type=="array" then .[] else . end' | jq -s \
    | jq -r '.[]? | select(.Service == "'${service}'") | .ID'
}

# Exports all environment variables
export_env() {
  export_pg_env
  export_redis_env
}

# Exports postgres environment variables
export_pg_env() {
  # Based on creds in compose.yaml
  export PGPORT=5433
  export PGHOST=localhost
  export PGUSER=pg
  export PGPASSWORD=password
  export PGDATABASE=postgres
  export DB_POSTGRES_URL="postgresql://pg:password@127.0.0.1:5433/postgres"
}

# Exports redis environment variables
export_redis_env() {
  export REDIS_HOST="127.0.0.1:6380"
}

pg_clear() {
  local pg_uri=$1

  for schema_name in `psql "${pg_uri}" -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg_%' AND schema_name NOT LIKE 'information_schema';" -t`; do
    psql "${pg_uri}" -c "DROP SCHEMA \"${schema_name}\" CASCADE;"
  done
}

pg_init() {
  local pg_uri=$1

  psql "${pg_uri}" -c "CREATE SCHEMA IF NOT EXISTS \"public\";"
}

redis_clear() {
  local redis_uri=$1
  redis-cli -u "${redis_uri}" flushall
}

main_native() {
  local services=${SERVICES}
  case "$services" in
    *db_test*) postgres_url_env_var=DB_TEST_POSTGRES_URL; postgres_url=${DB_TEST_POSTGRES_URL:-} ;;
    *) postgres_url_env_var=DB_POSTGRES_URL; postgres_url=${DB_POSTGRES_URL:-} ;;
  esac
  case "$services" in
    *redis_test*) redis_host_env_var=REDIS_TEST_HOST; redis_host=${REDIS_TEST_HOST:-} ;;
    *) redis_host_env_var=REDIS_HOST; redis_host=${REDIS_HOST:-} ;;
  esac

  if [ -n "${postgres_url}" ]; then
    echo "Using ${postgres_url_env_var} (${postgres_url}) to connect to postgres."
    pg_init "${postgres_url}"
  else
    echo "Postgres connection string missing did you set ${postgres_url_env_var}?"
    exit 1
  fi

  if [ -n "${redis_host}" ]; then
    echo "Using ${redis_host_env_var} (${redis_host}) to connect to Redis."
  else
    echo "Redis connection string missing did you set ${redis_host_env_var}?"
    echo "Continuing without Redis..."
  fi

  cleanup() {
    local services=$@

    case "$services" in
      *redis_test*) [ -z "${redis_host}" ] || redis_clear "redis://${redis_host}" > /dev/null 2>&1 ;;
    esac
    case "$services" in
      *db_test*) [ -z "${postgres_url}" ] || pg_clear "${postgres_url}" > /dev/null 2>&1 ;;
    esac
  }

  # trap SIGINT and performs cleanup
  trap "on_sigint ${services}" INT
  on_sigint() {
    cleanup $@
    exit $?
  }

  # Run the arguments as a command
  code=0
  DB_POSTGRES_URL="${postgres_url}" \
  REDIS_HOST="${redis_host}" \
  "$@" || code=$?

  cleanup ${services}

  exit ${code}
}

main_docker() {
  # Expect a SERVICES env var to be set with the docker service names
  local services=${SERVICES}

  dir=$(dirname $0)
  compose_file="${dir}/docker-compose.yaml"

  # whether this particular script started the container(s)
  started_container=false

  # performs cleanup as necessary, i.e. taking down containers
  # if this script started them
  cleanup() {
    local services=$@
    echo # newline
    if $started_container; then
      docker compose --file $compose_file rm --force --stop --volumes ${services}
    fi
  }

  # trap SIGINT and performs cleanup
  trap "on_sigint ${services}" INT
  on_sigint() {
    cleanup $@
    exit $?
  }

  # check if all services are running already
  not_running=false
  for service in $services; do
    container_id=$(get_container_id $compose_file $service)
    if [ -z $container_id ]; then
      not_running=true
      break
    fi
  done

  # if any are missing, recreate all services
  if $not_running; then
    started_container=true
    docker compose --file $compose_file up --wait --force-recreate ${services}
  else
    echo "all services ${services} are already running"
  fi

  # do not exit when following commands fail, so we can intercept exit code & tear down docker
  set +e

  # setup environment variables and run args
  export_env
  "$@"
  # save return code for later
  code=$?

  # performs cleanup as necessary
  cleanup ${services}
  exit ${code}
}

# Main entry point
main() {
  if [ "${ATPROTO_TEST_NATIVE:-0}" = 1 ] || ! docker ps >/dev/null 2>&1; then
    echo "Using externally provisioned test services."
    main_native "$@"
  else
    main_docker "$@"
  fi
}
