#!/bin/bash
# Run on Abhimaan's Mac (edge). Keys stay on this Mac (git-ignored). Only rootCA.pem is shared.
set -e
cd "$(dirname "$0")"
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
$OPENSSL version

# 1. Root CA (self-signed, CA:TRUE, Key Cert Sign)
$OPENSSL req -x509 -new -nodes -newkey rsa:2048 \
  -keyout rootCA.key -out rootCA.pem -days 825 \
  -config ca.cnf -extensions v3_ca

# 2. Server key + CSR for app.team07.test
$OPENSSL req -new -nodes -newkey rsa:2048 \
  -keyout server.key -out server.csr -config leaf.cnf

# 3. CA signs the server certificate (SAN: app + api)
$OPENSSL x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key \
  -CAcreateserial -out server.crt -days 397 -sha256 \
  -extfile leaf.cnf -extensions v3_leaf

# 4. Verify
$OPENSSL verify -CAfile rootCA.pem server.crt
$OPENSSL x509 -in server.crt -noout -ext subjectAltName

# 5. Install for nginx
DEST="$(brew --prefix)/etc/nginx/certs"
mkdir -p "$DEST"
cp server.crt server.key "$DEST/"
chmod 644 "$DEST/server.crt"; chmod 600 "$DEST/server.key"

echo "Next: AirDrop rootCA.pem (ONLY that file) to the client Macs, then on each client:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem"
