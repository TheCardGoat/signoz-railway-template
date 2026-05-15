#!/bin/sh
set -eu

signoz_port=8080
railway_port="${PORT:-$signoz_port}"
proxy_pid=""

if [ -z "${SIGNOZ_TOKENIZER_JWT_SECRET:-}" ]; then
  SIGNOZ_TOKENIZER_JWT_SECRET="$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  export SIGNOZ_TOKENIZER_JWT_SECRET
  echo "Generated ephemeral SIGNOZ_TOKENIZER_JWT_SECRET; set a persistent Railway variable for stable sessions." >&2
fi

if [ "$railway_port" != "$signoz_port" ]; then
  echo "Forwarding Railway PORT ${railway_port} to SigNoz port ${signoz_port}" >&2
  socat "TCP-LISTEN:${railway_port},fork,reuseaddr" "TCP:127.0.0.1:${signoz_port}" &
  proxy_pid="$!"
fi

if [ "$#" -eq 0 ]; then
  echo "Starting SigNoz with default server subcommand" >&2
  ./signoz server &
elif [ "$1" = "server" ]; then
  echo "Starting SigNoz: ./signoz $*" >&2
  ./signoz "$@" &
elif [ "$1" = "./signoz" ] || [ "$1" = "/root/signoz" ]; then
  shift
  if [ "$#" -eq 0 ]; then
    echo "Starting SigNoz: ./signoz server" >&2
    ./signoz server &
  elif [ "$1" = "server" ]; then
    echo "Starting SigNoz: ./signoz $*" >&2
    ./signoz "$@" &
  else
    echo "Starting SigNoz: ./signoz server $*" >&2
    ./signoz server "$@" &
  fi
elif { [ "$1" = "/bin/sh" ] || [ "$1" = "sh" ]; } && [ "${2:-}" = "-c" ]; then
  shift 2
  command="$*"
  case "$command" in
    "./signoz"|"/root/signoz")
      echo "Starting SigNoz: ./signoz server" >&2
      ./signoz server &
      ;;
    "./signoz server"*|"/root/signoz server"*)
      echo "Starting SigNoz shell command: $command" >&2
      /bin/sh -c "$command" &
      ;;
    "./signoz "*)
      command="./signoz server ${command#./signoz }"
      echo "Starting SigNoz shell command: $command" >&2
      /bin/sh -c "$command" &
      ;;
    "/root/signoz "*)
      command="/root/signoz server ${command#/root/signoz }"
      echo "Starting SigNoz shell command: $command" >&2
      /bin/sh -c "$command" &
      ;;
    *)
      echo "Starting shell command: $command" >&2
      /bin/sh -c "$command" &
      ;;
  esac
else
  echo "Starting SigNoz: ./signoz server $*" >&2
  ./signoz server "$@" &
fi

signoz_pid="$!"

terminate() {
  kill -TERM "$signoz_pid" 2>/dev/null || true
  if [ -n "$proxy_pid" ]; then
    kill -TERM "$proxy_pid" 2>/dev/null || true
  fi
  wait "$signoz_pid" 2>/dev/null || true
}

trap 'terminate; exit 143' INT TERM

set +e
wait "$signoz_pid"
status="$?"
set -e

if [ -n "$proxy_pid" ]; then
  kill -TERM "$proxy_pid" 2>/dev/null || true
fi

exit "$status"
