# DNS Resolver Checker

A lightweight shell script to test plain DNS, DNS over HTTPS (DoH) and DNS over TLS (DoT) resolvers.

## Usage
## Quick run:
```bash
wget -qO- https://raw.githubusercontent.com/clarkxkent/checkdns/refs/heads/main/checkdns.sh | sh
```

### Test custom domain:
```bash
wget -qO- https://raw.githubusercontent.com/clarkxkent/checkdns/refs/heads/main/checkdns.sh | sh -s example.com
```

### Download and run locally:
```bash
wget https://raw.githubusercontent.com/clarkxkent/checkdns/refs/heads/main/checkdns.sh
chmod +x checkdns.sh
./checkdns.sh
```

## Features

- Tests popular DNS resolvers (Cloudflare, Google, Quad9, AdGuard, NextDNS)
- Supports plain DNS, DoH and DoT protocols
- Clean output with status indicators (✅/❌)
- POSIX-compliant (works with sh, bash, ash)
- Custom domain testing support

## Requirements

- `dig` utility (version 9.18+)

### Installation commands for dig:
- **Debian/Ubuntu**: `sudo apt install dnsutils`
- **OpenWrt**: `opkg install bind-dig`
- **MacOS**: `brew install bind`
- **Termux**" `apt upgrade dnsutils`

## Output Example

```
🔓 Plain DNS (UDP)
  ✅ Cloudflare (1.1.1.1) (8 ms)
  ✅ Cloudflare (1.0.0.1) (2 ms)
  ✅ Google (8.8.8.8) (1 ms)
  ✅ Google (8.8.4.4) (1 ms)
  ✅ Quad9 (9.9.9.9) (1 ms)
  ✅ Quad9 (149.112.112.112) (2 ms)
  ✅ AdGuardDNS (94.140.14.14) (2 ms)
  ✅ AdGuardDNS (94.140.15.15) (2 ms)
  ✅ NextDNS (45.90.28.65) (59 ms)
  ✅ NextDNS (45.90.30.65) (57 ms)

🔒 DNS over HTTPS (DoH)
  ✅ Cloudflare (1.1.1.1) (4 ms)
  ✅ Cloudflare (1.0.0.1) (4 ms)
  ✅ Google (8.8.8.8) (2 ms)
  ✅ Google (8.8.4.4) (4 ms)
  ✅ Quad9 (9.9.9.9) (2 ms)
  ✅ Quad9 (149.112.112.112) (2 ms)
  ✅ AdGuardDNS (dns.adguard-dns.com) (2 ms)
  ✅ NextDNS (dns.nextdns.io) (44 ms)

🔒 DNS over TLS (DoT)
  ✅ Cloudflare (1.1.1.1) (45 ms)
  ✅ Cloudflare (1.0.0.1) (45 ms)
  ✅ Google (8.8.8.8) (7 ms)
  ✅ Google (8.8.4.4) (11 ms)
  ✅ Quad9 (9.9.9.9) (2 ms)
  ✅ Quad9 (149.112.112.112) (3 ms)
  ✅ AdGuardDNS (dns.adguard-dns.com) (45 ms)
  ✅ NextDNS (dns.nextdns.io) (114 ms)
```
