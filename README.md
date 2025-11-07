API Gateway Docker image providing a single HTTPS entry point for all backend services.

## Features

- **Automatic TLS** - Let's Encrypt certificates with auto-renewal 

- **HTTP → HTTPS** - Automatic redirect to secure endpoints 
- **Rate Limiting** - Default 100 req/s per IP, configurable per-route 
- **Circuit Breaking** - Protect backends from cascading failures 
- **Security Headers** - HSTS, XSS protection, CSP enabled 
- **Path-based Routing** - Single domain, multiple services 
- **Cloudflare IP Whitelisting** - Blocks direct server access 
- **Health Checks** - Automatic backend monitoring 
- **Response Compression** - Automatic gzip/brotli compression

## Quick Start

### 1. Setup Environment

``` bash
cp .env.example .env
nano .env  # Set DOMAIN and LETSENCRYPT_EMAIL
```

### 2. Configure Cloudflare

- DDoS protection
- Hidden origin IP (attackers can't target the server directly)

  ```
  Internet -> Cloudflare (Proxy + DDoS) -> API Gateway (TLS + Rate Limit) -> Backends
  ```

**Cloudflare DNS:**
  - Create `A` record: `example.com -> SERVER_IP`
  - Enable proxy (orange cloud icon)

  ```
  Type: A
  Name: @ (or subdomain)
  Content: SERVER_IP
  Proxy status: Proxied (orange cloud)
  ```

**Cloudflare SSL/TLS:**
   - Set encryption mode: **Full (Strict)** 

   - This validates the Let's Encrypt cert

### 3. Deploy

  ```bash
  # Server Firewall
  ufw allow 80/tcp   # Let's Encrypt HTTP-01
  ufw allow 443/tcp  # HTTPS
  ufw enable

  # Optional: Restrict SSH to the office IP
  ufw allow from OFFICE_IP to any port 22
  
  docker compose up -d
  ```

### 4. Verify

```bash
# Check logs
docker compose logs -f api-gateway

# Test HTTPS (should work through Cloudflare)
curl https://example.com

# Test direct IP access (should be blocked with 403)
curl http://SERVER_IP
```

## Configuration

### Adding Services

Add to [gateway-config.production.yml](gateway-config.production.yml):

```yaml
routers:
  admin-router:
    rule: "Host(`${DOMAIN}`) && PathPrefix(`/admin`)"
    service: app-service
    priority: 30
    middlewares:
      - internal-only@file  # Only Docker networks (no public access)
```

### Custom Middlewares

Add to [gateway-config.production.yml](gateway-config.production.yml):

```yaml
middlewares:
  api-strict-ratelimit:
    rateLimit:
      average: 50   # 50 requests/second
      burst: 100
      period: 1s

routers:
  api-router:
    middlewares:
      - cloudflare-only@file
      - api-strict-ratelimit
```

## Security

### Critical: Cloudflare IP Whitelisting

The `cloudflare-only@file` middleware blocks direct server access, forcing all traffic through Cloudflare:

```yaml
middlewares:
  - cloudflare-only@file  # Required for production
```

**Why this matters:**
- ❌ Without it: Attackers can bypass Cloudflare by accessing `http://SERVER_IP`
- ✅ With it: Only Cloudflare IPs can reach the server

### Updating Cloudflare IPs

Cloudflare occasionally updates their IP ranges. To update:

```bash
# Get latest IPs
curl https://www.cloudflare.com/ips-v4
curl https://www.cloudflare.com/ips-v6

# Update defaults.yml and rebuild
docker compose build
docker compose up -d
```

### Dashboard Security

The dashboard is bound to `127.0.0.1:8080` (localhost only). Access remotely via SSH tunnel:

```bash
ssh -L 8080:localhost:8080 user@server
# Then open: http://localhost:8080/dashboard/
```

## Monitoring

### View Logs

```bash
# All logs
docker compose logs -f api-gateway

# Certificate issues
docker compose logs -f api-gateway | grep acme

# Rate limiting events
docker compose logs api-gateway | grep -i "rate limit"

# Blocked requests
docker compose logs api-gateway | grep -i "403"
```

### Health Check

```bash
# Gateway health
curl http://localhost/ping

# HTTPS redirect test
curl -I http://example.com
# Should return: 301/308 → https://

# Verify Cloudflare protection
curl http://example.com
# Should return: 403 Forbidden
```

## Troubleshooting Let's Encrypt Certificate Not Issued

```bash
docker compose logs api-gateway | grep acme
```

**Common issues:**
1. Port 80 blocked - Let's Encrypt needs HTTP-01 challenge
2. DNS not pointing to server - Test: `dig example.com`
3. Cloudflare SSL mode wrong - Must be "Full (Strict)"
4. Rate limited by Let's Encrypt - Wait 1 hour

## Production Checklist

### Before Deployment
- [ ] Domain registered and DNS configured
- [ ] Server firewall configured (`ufw`)
- [ ] Environment variables set (`.env` file)

### Cloudflare Setup
- [ ] DNS A record pointing to server
- [ ] Proxy enabled (orange cloud)
- [ ] SSL/TLS mode: "Full (Strict)"

### Deployment
- [ ] Gateway config customized for the services
- [ ] `docker compose up -d` successful
- [ ] TLS certificate issued (check logs)
- [ ] HTTPS redirect working
- [ ] Direct IP access blocked (403)
