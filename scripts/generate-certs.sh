#!/usr/bin/env bash
# shellcheck shell=bash
set -euf -o pipefail

PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd | xargs dirname)"
readonly PROGDIR

# For some commands we must invoke a Windows executable if in the context of
# WSL.
IS_WSL=$(grep -q WSL /proc/version 2>/dev/null && echo "true" || echo "false")
readonly IS_WSL
if [[ "${IS_WSL}" == "true" ]]; then
  MKCERT=mkcert.exe
else
  MKCERT=mkcert
fi
readonly MKCERT

if [[ "${IS_WSL}" == "true" ]]; then
  CAROOT=$("${MKCERT}" -CAROOT | xargs -0 wslpath -u)
else
  CAROOT=$("${MKCERT}" -CAROOT)
fi
readonly CAROOT

"${MKCERT}" -install || true # Ignore errors, as java key stores are sometimes not owned by the user in Windows.

if [ ! -f "${PROGDIR}/certs/rootCA-key.pem" ]; then
  cp "${CAROOT}/rootCA-key.pem" "${PROGDIR}/certs/rootCA-key.pem"
fi

if [ ! -f "${PROGDIR}/certs/rootCA.pem" ]; then
  cp "${CAROOT}/rootCA.pem" "${PROGDIR}/certs/rootCA.pem"
fi

"${MKCERT}" -cert-file certs/cert.pem -key-file certs/privkey.pem \
  "*.islandora.dev" \
  "islandora.dev" \
  "*.islandora.io" \
  "islandora.io" \
  "*.islandora.info" \
  "islandora.info" \
  "localhost" \
  "127.0.0.1" \
  "::1"
