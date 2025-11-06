#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Mosquitto MQTT broker on Debian-based systems
# - Installs mosquitto and mosquitto-clients
# - Enables and starts the service
# - Optionally configures local auth

info() { echo "[bootstrap-mqtt] $*"; }

ensure_packages() {
  info "Installing mosquitto and mosquitto-clients..."
  sudo apt update
  sudo apt install -y mosquitto mosquitto-clients
}

enable_service() {
  info "Enabling and starting mosquitto.service..."
  sudo systemctl enable --now mosquitto
}

configure_auth() {
  local user="$1"; shift || true
  local pass="$1"; shift || true

  if [[ -z "${user}" || -z "${pass}" ]]; then
    info "Skipping auth configuration (no user/pass provided)."
    return 0
  fi

  info "Configuring mosquitto user '${user}'..."
  sudo mosquitto_passwd -b /etc/mosquitto/passwd "${user}" "${pass}" || true

  local conf="/etc/mosquitto/conf.d/10-auth.conf"
  sudo tee "${conf}" >/dev/null <<EOF
allow_anonymous false
password_file /etc/mosquitto/passwd
listener 1883 0.0.0.0
EOF

  info "Restarting mosquitto to apply auth settings..."
  sudo systemctl restart mosquitto
}

main() {
  local user="${1:-}"
  local pass="${2:-}"

  ensure_packages
  enable_service
  configure_auth "${user}" "${pass}"

  info "MQTT broker status:"
  systemctl --no-pager -l status mosquitto | sed -n '1,12p' || true
  ss -tlnp | grep 1883 || true
}

main "$@"


