#!/bin/sh
set -eu

real_binary="${SIGNOZ_OTEL_REAL_BINARY:-/usr/local/bin/signoz-otel-collector.real}"
removed_gate=0
pending_feature_gates=0
initialized_output_args=0

sanitize_feature_gates() {
  printf '%s' "$1" | sed \
    -e 's/^-pkg[.]translator[.]prometheus[.]NormalizeName$//' \
    -e 's/^-pkg[.]translator[.]prometheus[.]NormalizeName,//' \
    -e 's/,-pkg[.]translator[.]prometheus[.]NormalizeName$//' \
    -e 's/,-pkg[.]translator[.]prometheus[.]NormalizeName,/,/g'
}

for arg in "$@"; do
  if [ "$initialized_output_args" = 0 ]; then
    set --
    initialized_output_args=1
  fi

  if [ "$pending_feature_gates" = 1 ]; then
    sanitized_value="$(sanitize_feature_gates "$arg")"
    if [ "$sanitized_value" != "$arg" ]; then
      removed_gate=1
    fi
    if [ -n "$sanitized_value" ]; then
      set -- "$@" "--feature-gates" "$sanitized_value"
    fi
    pending_feature_gates=0
    continue
  fi

  case "$arg" in
    --feature-gates)
      pending_feature_gates=1
      ;;
    --feature-gates=*)
      feature_gates="${arg#--feature-gates=}"
      sanitized_value="$(sanitize_feature_gates "$feature_gates")"
      if [ "$sanitized_value" != "$feature_gates" ]; then
        removed_gate=1
      fi
      if [ -n "$sanitized_value" ]; then
        set -- "$@" "--feature-gates=$sanitized_value"
      fi
      ;;
    *)
      set -- "$@" "$arg"
      ;;
  esac
done

if [ "$initialized_output_args" = 0 ]; then
  set --
fi

if [ "$removed_gate" = 1 ]; then
  echo "Removed unsupported OpenTelemetry feature gate disable from collector arguments."
fi

exec "$real_binary" "$@"
