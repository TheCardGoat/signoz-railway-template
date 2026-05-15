#!/bin/sh
set -eu

default_command="/signoz-otel-collector migrate sync check && exec /signoz-otel-collector --config=/etc/otel-collector-config.yaml --manager-config=/etc/manager-config.yaml --copy-path=/var/tmp/collector-config.yaml"

if [ "$#" -eq 0 ]; then
  command="$default_command"
elif [ "$#" -eq 1 ]; then
  case "$1" in
    -*|migrate|migrate\ *)
      command="/signoz-otel-collector $1"
      ;;
    *)
      command="$1"
      ;;
  esac
elif { [ "$1" = "/bin/sh" ] || [ "$1" = "sh" ]; } && [ "${2:-}" = "-c" ]; then
  shift 2
  command="$*"
else
  case "$1" in
    -*|migrate)
      command="/signoz-otel-collector $*"
      ;;
    *)
      command="$*"
      ;;
  esac
fi

sanitized_command="$(printf '%s' "$command" | sed \
  -e 's/[[:space:]]*--feature-gates=-pkg[.]translator[.]prometheus[.]NormalizeName//g' \
  -e "s/[[:space:]]*--feature-gates='-pkg[.]translator[.]prometheus[.]NormalizeName'//g" \
  -e 's/[[:space:]]*--feature-gates="-pkg[.]translator[.]prometheus[.]NormalizeName"//g' \
  -e 's/[[:space:]]*--feature-gates -pkg[.]translator[.]prometheus[.]NormalizeName//g')"

if [ "$sanitized_command" != "$command" ]; then
  echo "Removed unsupported OpenTelemetry feature gate disable from collector start command."
fi

exec /bin/sh -c "$sanitized_command"
