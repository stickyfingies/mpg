#!/bin/bash

# This script generates self-signed HTTPS certificates for use on localhost.

# Exit on any error
set -eou pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure SSL certificates directory exists
echo "🔒 Checking SSL certificates..."
if [ ! -d "$ROOT_DIR/certificates" ]; then
  echo "📝 Creating SSL certificates directory..."
  mkdir -p "$ROOT_DIR/certificates"
fi

# Create self-signed certificates if they don't exist
if [ ! -f "$ROOT_DIR/certificates/cert.pem" ] || [ ! -f "$ROOT_DIR/certificates/key.pem" ]; then
  echo "🔑 Generating self-signed SSL certificates..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$ROOT_DIR/certificates/key.pem" \
    -out "$ROOT_DIR/certificates/cert.pem" \
    -subj "/CN=localhost" -keyout "$ROOT_DIR/certificates/key.pem"
fi

echo "✨ SSL certificates are ready to roll!"