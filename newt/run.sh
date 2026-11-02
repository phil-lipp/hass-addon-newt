#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -e

bashio::log.info "Starting Newt..."

# Persist Newt config / provisioning credentials across restarts.
export HOME="/data"
export XDG_CONFIG_HOME="/data/.config"
mkdir -p "${XDG_CONFIG_HOME}"

HEALTH_FILE="${HEALTH_FILE:-/tmp/healthy}"
export HEALTH_FILE
rm -f "${HEALTH_FILE}"

# Build command arguments
ARGS=(
    "--endpoint" "$(bashio::config 'endpoint')"
    "--log-level" "$(bashio::config 'log_level')"
    "--health-file" "${HEALTH_FILE}"
)

if bashio::config.has_value 'id' && [ -n "$(bashio::config 'id')" ]; then
    ARGS+=("--id" "$(bashio::config 'id')")
fi

if bashio::config.has_value 'secret' && [ -n "$(bashio::config 'secret')" ]; then
    ARGS+=("--secret" "$(bashio::config 'secret')")
fi

# Add DNS if configured
if bashio::config.has_value 'dns' && [ -n "$(bashio::config 'dns')" ]; then
    ARGS+=("--dns" "$(bashio::config 'dns')")
fi

if bashio::config.has_value 'provisioning_key' && [ -n "$(bashio::config 'provisioning_key')" ]; then
    ARGS+=("--provisioning-key" "$(bashio::config 'provisioning_key')")
fi

if ! bashio::config.has_value 'id' && ! bashio::config.has_value 'provisioning_key'; then
    bashio::log.fatal "Configure either id+secret or provisioning_key"
    exit 1
fi

# PEM mTLS (preferred)
if bashio::config.has_value 'tls_client_cert_file' && [ -n "$(bashio::config 'tls_client_cert_file')" ]; then
    ARGS+=("--tls-client-cert-file" "$(bashio::config 'tls_client_cert_file')")
fi

if bashio::config.has_value 'tls_client_key' && [ -n "$(bashio::config 'tls_client_key')" ]; then
    ARGS+=("--tls-client-key" "$(bashio::config 'tls_client_key')")
fi

if bashio::config.has_value 'tls_client_ca' && [ -n "$(bashio::config 'tls_client_ca')" ]; then
    ARGS+=("--tls-client-ca" "$(bashio::config 'tls_client_ca')")
fi

# Deprecated PKCS12 mTLS path
if bashio::config.has_value 'tls_client_cert' && [ -n "$(bashio::config 'tls_client_cert')" ]; then
    ARGS+=("--tls-client-cert" "$(bashio::config 'tls_client_cert')")
fi

if bashio::config.has_value 'docker' && [ "$(bashio::config 'docker')" = "true" ]; then
    ARGS+=("--docker-socket" "/var/run/docker.sock")
fi

# Optional escape hatch for any Newt env var (MTU, BLUEPRINT_FILE, etc.).
if bashio::config.exists 'custom_env_vars'; then
    length="$(bashio::config 'custom_env_vars|length')"
    if [[ "${length}" =~ ^[0-9]+$ ]]; then
        for ((i = 0; i < length; i++)); do
            entry="$(bashio::config "custom_env_vars[${i}]")"
            if [[ -z "${entry}" || "${entry}" == "null" ]]; then
                continue
            fi
            if [[ ! "${entry}" =~ ^[A-Z_][A-Z0-9_]*=.+$ ]] || [[ "${entry}" == *$'\n'* ]] || [[ "${entry}" == *$'\r'* ]]; then
                bashio::log.warning "Skipping invalid custom env var format"
                continue
            fi
            var_name="${entry%%=*}"
            case "${var_name}" in
                PATH|HOME|LD_*|HEALTH_FILE|XDG_CONFIG_HOME|PANGOLIN_ENDPOINT|NEWT_ID|NEWT_SECRET|SITE_ID|SITE_SECRET)
                    bashio::log.warning "Skipping protected variable: ${var_name}"
                    continue
                    ;;
            esac
            bashio::log.info "Custom env: ${var_name}=[REDACTED]"
            # shellcheck disable=SC2163
            export "${entry}"
        done
    fi
fi

exec /newt "${ARGS[@]}"
