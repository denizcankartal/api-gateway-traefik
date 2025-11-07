FROM traefik:v3.1

# Install envsubst for environment variable substitution
RUN apk add --no-cache gettext

# Copy static Traefik configuration
COPY traefik.yml /etc/traefik/traefik.yml

# Copy default middlewares
COPY defaults.yml /etc/traefik/defaults.yml

# Copy entrypoint script that processes gateway-config.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories for configuration and certificates
RUN mkdir -p /etc/traefik/dynamic /etc/traefik/acme

# Expose ports
EXPOSE 80 443 8080

# Health check
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD traefik healthcheck --ping || exit 1

# Use custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
