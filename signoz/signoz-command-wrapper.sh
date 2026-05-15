#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  echo "Starting SigNoz through binary wrapper: /root/signoz-bin server" >&2
  exec /root/signoz-bin server
fi

case "$1" in
  generate|help|metastore|server|-h|--help|-v|--version)
    exec /root/signoz-bin "$@"
    ;;
  *)
    echo "Starting SigNoz through binary wrapper: /root/signoz-bin server $*" >&2
    exec /root/signoz-bin server "$@"
    ;;
esac
