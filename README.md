API Gateway Docker image providing a single HTTPS entry point for all backend services.

## Features

- **Automatic TLS** - Let's Encrypt certificates with auto-renewal (production)
- **Local Development** - HTTP-only mode when `DOMAIN=localhost` (no TLS)
- **HTTP → HTTPS** - Automatic redirect to secure endpoints 
- **Rate Limiting** - Default 100 req/s per IP, configurable per-route 
- **Circuit Breaking** - Protect backends from cascading failures 
- **Security Headers** - HSTS, XSS protection, CSP enabled 
- **Path-based Routing** - Single domain, multiple services 
- **Cloudflare IP Whitelisting** - Blocks direct server access 
- **Health Checks** - Automatic backend monitoring 
- **Response Compression** - Automatic gzip/brotli compression

## Quick Start

### Local Development (No DNS Required)

```bash
# Start the gateway
docker compose -f docker-compose.local.yml up -d

# Test the gateway
curl http://localhost/           # Frontend
curl http://localhost/api/status/200  # API

# View dashboard
open http://localhost:8080/dashboard/
```

### Production Deployment

```bash
# 1. Create .env file
cp .env.example .env
nano .env  # Set DOMAIN and LETSENCRYPT_EMAIL

# 2. Point DNS to your server
# Create A record: example.com -> YOUR_SERVER_IP

# 3. Configure firewall
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# 4. Deploy
docker compose -f docker-compose.production.yml up -d

# 5. Verify HTTPS (wait 30-60s for certificate)
curl https://example.com
docker compose -f docker-compose.production.yml logs -f api-gateway | grep acme
```

## Configuration

### Adding Your Services

**1. Add service to docker-compose:**

Edit both `docker-compose.local.yml` and `docker-compose.production.yml`:

```yaml
services:
  my-api:
    build: ./my-api
    networks:
      - gateway
```

**2. Add routes to both route files:**

Edit [traefik/dynamic/routes.local.yml](traefik/dynamic/routes.local.yml):

```yaml
http:
  routers:
    my-api-router:
      rule: "Host(`localhost`) && PathPrefix(`/myapi`)"
      service: my-api-service
      entryPoints:
        - web
      middlewares:
        - default-compression@file

  services:
    my-api-service:
      loadBalancer:
        servers:
          - url: "http://my-api:8000"
```

Edit [traefik/dynamic/routes.production.yml](traefik/dynamic/routes.production.yml):

```yaml
http:
  routers:
    my-api-router:
      rule: "Host(`${DOMAIN}`) && PathPrefix(`/myapi`)"
      service: my-api-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      middlewares:
        - default-security-headers@file
        - default-compression@file
        - default-ratelimit@file

  services:
    my-api-service:
      loadBalancer:
        servers:
          - url: "http://my-api:8000"
```

**3. Restart gateway:**

```bash
# Local
docker compose -f docker-compose.local.yml restart api-gateway

# Production
docker compose -f docker-compose.production.yml restart api-gateway
```

### Available Default Middlewares

Defined in [traefik/dynamic/middlewares.yml](traefik/dynamic/middlewares.yml):

- `default-security-headers@file` - HSTS, XSS, CSP
- `default-compression@file` - gzip/brotli
- `default-ratelimit@file` - 100 req/s per IP
- `default-circuit-breaker@file` - 30% error threshold
- `internal-only@file` - Docker network only
- `cloudflare-only@file` - Cloudflare IPs only (optional)

### Custom Middlewares

Add to [traefik/dynamic/middlewares.yml](traefik/dynamic/middlewares.yml):

```yaml
http:
  middlewares:
    # Stricter rate limiting for API
    api-ratelimit:
      rateLimit:
        average: 50
        burst: 100
        period: 1s
```

```yaml
routers:
  my-api-router:
    middlewares:
      - api-ratelimit@file
      - default-security-headers@file
```

## Security

### Cloudflare IP Whitelisting (Optional)

If using Cloudflare proxy, add the middleware to block direct IP access in [traefik/dynamic/routes.production.yml](traefik/dynamic/routes.production.yml):

```yaml
routers:
  api-router:
    middlewares:
      - cloudflare-only@file
```

**Setup:**
1. Enable Cloudflare proxy (orange cloud)
2. Set SSL/TLS mode to **Full (Strict)**
3. Add middleware to routes

**Warning:** Don't use without Cloudflare or Let's Encrypt will fail.

### Dashboard Access

Dashboard is bound to localhost in production. To access remotely:

```bash
# SSH tunnel
ssh -L 8080:localhost:8080 user@server

# Then open: http://localhost:8080/dashboard/
```

## Monitoring

### View Logs

```bash
# Local
docker compose -f docker-compose.local.yml logs -f api-gateway

# Production
docker compose -f docker-compose.production.yml logs -f api-gateway

# Certificate issues
docker compose logs api-gateway | grep acme

# Rate limiting
docker compose logs api-gateway | grep -i "rate limit"
```

### Health Check

```bash
# Gateway health
curl http://localhost/ping

# Check certificate (production)
curl -vI https://example.com 2>&1 | grep "SSL certificate"
```

## Troubleshooting

### Let's Encrypt Certificate Not Issued

```bash
# Check logs
docker compose -f docker-compose.production.yml logs api-gateway | grep acme
```

**Common issues:**

1. **Port 80 blocked**
   ```bash
   ufw status
   ```

2. **DNS not pointing to server**
   ```bash
   dig +short example.com
   ```

3. **Incorrect environment variables**
   ```bash
   cat .env
   ```

4. **Cloudflare middleware blocking**
   - Remove `cloudflare-only@file` temporarily from [traefik/dynamic/routes.production.yml](traefik/dynamic/routes.production.yml)

5. **Rate limited by Let's Encrypt**
   - Wait 1 hour and try again

### Routes Not Working

```bash
# Check loaded config
docker compose exec api-gateway cat /etc/traefik/dynamic/routes.yml

# Check Traefik dashboard
open http://localhost:8080/dashboard/

# Restart gateway
docker compose -f docker-compose.local.yml restart api-gateway
```

### Configuration Changes Not Applying

Traefik watches the `dynamic/` folder and reloads automatically. If changes don't apply:

```bash
# Check if file provider is working
docker compose exec api-gateway cat /etc/traefik/traefik.yml | grep -A 3 providers

# Force restart
docker compose restart api-gateway
```

## Switching Environments

```bash
# Stop current environment
docker compose -f docker-compose.local.yml down

# Start production
docker compose -f docker-compose.production.yml up -d
```

## Production Checklist

### Before Deployment
- [ ] `.env` configured with domain and email
- [ ] Customize [traefik/dynamic/routes.yml](traefik/dynamic/routes.yml) for your services
- [ ] DNS A record pointing to server
- [ ] Firewall allows ports 80 and 443

### After Deployment
- [ ] Certificate issued successfully
- [ ] HTTPS works: `curl https://example.com`
- [ ] HTTP redirects to HTTPS
- [ ] Dashboard accessible via SSH tunnel

### Optional: Cloudflare
- [ ] DNS proxy enabled (orange cloud)
- [ ] SSL/TLS mode: "Full (Strict)"
- [ ] `cloudflare-only@file` middleware added
- [ ] Direct IP access returns 403

## Architecture

```
Local Development (HTTP):
Browser → Gateway :80 (web) → Backend Services

Production (HTTPS):
Browser → Gateway :443 (websecure) → Backend Services
          ↑ (Let's Encrypt TLS)
          │
HTTP :80 → Automatic redirect to HTTPS :443
```