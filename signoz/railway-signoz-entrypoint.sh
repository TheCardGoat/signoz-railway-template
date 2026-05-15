#!/bin/sh
set -eu

signoz_port=8080
railway_port="${PORT:-$signoz_port}"
proxy_pid=""

if [ "$railway_port" != "$signoz_port" ]; then
  echo "Forwarding Railway PORT ${railway_port} to SigNoz port ${signoz_port}" >&2
  socat "TCP-LISTEN:${railway_port},fork,reuseaddr" "TCP:127.0.0.1:${signoz_port}" &
  proxy_pid="$!"
fi

if [ "$#" -eq 0 ]; then
  ./signoz server &
elif [ "$1" = "./signoz" ] || [ "$1" = "/root/signoz" ]; then
  "$@" &
elif [ "$1" = "server" ]; then
  ./signoz "$@" &
elif { [ "$1" = "/bin/sh" ] || [ "$1" = "sh" ]; } && [ "${2:-}" = "-c" ]; then
  shift 2
  /bin/sh -c "$*" &
else
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
