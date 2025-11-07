#!/bin/sh
set -e

echo "========================================="
echo "API Gateway Starting"
echo "========================================="

# Check if gateway-config.yml exists
if [ ! -f "/etc/gateway/config.yml" ]; then
    echo "ERROR: /etc/gateway/config.yml not found!"
    echo "Please mount your gateway-config.yml to /etc/gateway/config.yml"
    exit 1
fi

echo "✓ Found gateway configuration at /etc/gateway/config.yml"

# Substitute environment variables in gateway-config.yml
echo "✓ Processing environment variables in configuration..."
envsubst < /etc/gateway/config.yml > /tmp/config-processed.yml

# Convert gateway-config.yml to Traefik dynamic.yml
# For now, we'll use a simple approach: the gateway-config.yml IS the dynamic.yml
# This means users write in Traefik's format but with env var support
cp /tmp/config-processed.yml /etc/traefik/dynamic/dynamic.yml

echo "✓ Generated Traefik dynamic configuration"

# Validate required environment variables
if [ -z "$DOMAIN" ]; then
    echo "WARNING: DOMAIN not set. Routing may not work correctly."
fi

if [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo "WARNING: LETSENCRYPT_EMAIL not set. TLS certificates may not be issued."
fi

# Ensure acme.json has correct permissions
touch /etc/traefik/acme/acme.json
chmod 600 /etc/traefik/acme/acme.json

echo "✓ ACME storage initialized"

# Display configuration summary
echo ""
echo "Configuration Summary:"
echo "----------------------"
echo "Domain: ${DOMAIN:-NOT SET}"
echo "Let's Encrypt Email: ${LETSENCRYPT_EMAIL:-NOT SET}"
echo "Dynamic Config: /etc/traefik/dynamic/dynamic.yml"
echo "ACME Storage: /etc/traefik/acme/acme.json"
echo ""
echo "========================================="
echo "Starting Traefik..."
echo "========================================="

# Start Traefik
exec traefik
