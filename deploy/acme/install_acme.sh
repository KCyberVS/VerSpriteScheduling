#!/usr/bin/env bash
# install_acme.sh
# Usage: run on the host (not inside devcontainer). This script installs acme.sh (if needed),
# issues Let's Encrypt certificates using webroot, installs them under /etc/letsencrypt/live/verspritescheduling.io,
# and sets a reload command so nginx is reloaded after renewals.

set -euo pipefail
DOMAIN="verspritescheduling.io"
WWW_DOMAIN="www.verspritescheduling.io"
WEBROOT="/workspaces/landingschedule/docs"
INSTALL_DIR="/etc/letsencrypt/live/${DOMAIN}"

echo "Ensure webroot exists: ${WEBROOT}"
if [ ! -d "${WEBROOT}" ]; then
  echo "ERROR: webroot directory does not exist: ${WEBROOT}" >&2
  exit 1
fi

# Install acme.sh if not present
if [ ! -x "$HOME/.acme.sh/acme.sh" ]; then
  echo "Installing acme.sh into $HOME/.acme.sh"
  curl -sSf https://get.acme.sh | sh
fi

# Ensure acme.sh is on PATH for this session
export PATH="$HOME/.acme.sh:$PATH"

echo "Issuing certificate for ${DOMAIN} and ${WWW_DOMAIN} using webroot ${WEBROOT}"
~/.acme.sh/acme.sh --issue --webroot "${WEBROOT}" -d "${DOMAIN}" -d "${WWW_DOMAIN}" --server letsencrypt || {
  echo "acme.sh issue failed" >&2
  exit 2
}

echo "Installing certificates to ${INSTALL_DIR} (requires sudo)"
sudo mkdir -p "${INSTALL_DIR}"
~/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" \
  --cert-file "${INSTALL_DIR}/fullchain.pem" \
  --key-file  "${INSTALL_DIR}/privkey.pem" \
  --reloadcmd "sudo systemctl reload nginx" || {
    echo "acme.sh install-cert failed" >&2
    exit 3
}

echo "Certificate installed. Files:
  ${INSTALL_DIR}/fullchain.pem
  ${INSTALL_DIR}/privkey.pem"

echo "Next steps (if not already done):
 - Copy the provided nginx site file into /etc/nginx/sites-available/verspritescheduling
 - sudo ln -s /etc/nginx/sites-available/verspritescheduling /etc/nginx/sites-enabled/verspritescheduling
 - sudo nginx -t && sudo systemctl reload nginx

After that, the installed certificates are referenced at /etc/letsencrypt/live/${DOMAIN} and nginx reloads on renewals."

exit 0
