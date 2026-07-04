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
  ✅ Cloudflare (1.1.1.1) (2 ms)
  ✅ Cloudflare (1.0.0.1) (2 ms)
  ✅ Google (8.8.8.8) (1 ms)
  ✅ Google (8.8.4.4) (1 ms)
  ✅ Quad9 (9.9.9.9) (1 ms)
  ✅ Quad9 (149.112.112.112) (1 ms)
  ✅ AliDNS (223.5.5.5) (111 ms)
  ✅ AliDNS (223.6.6.6) (41 ms)
  ✅ DNS.SB (185.222.222.222) (11 ms)
  ✅ Yandex (77.88.8.8) (40 ms)
  ✅ Yandex (77.88.8.1) (44 ms)
  ✅ AdGuardDNS (94.140.14.14) (6 ms)
  ✅ AdGuardDNS (94.140.15.15) (2 ms)
  ✅ COMSS (212.109.195.93) (43 ms)
  ✅ COMSS (83.220.169.155) (42 ms)
  ✅ OpenDNS (208.67.222.222) (1 ms)
  ✅ OpenDNS (208.67.220.220) (1 ms)
  ✅ NextDNS (45.90.28.65) (2 ms)
  ✅ NextDNS (45.90.30.65) (1 ms)
  ✅ MSK-IX (62.76.76.62) (79 ms)
  ✅ MSK-IX (62.76.62.76) (79 ms)
  ✅ ControlD (76.76.2.0) (9 ms)
  ✅ ControlD (76.76.10.0) (2 ms)

🔒 DNS over HTTPS (DoH)
  ✅ Cloudflare (1.1.1.1) (4 ms)
  ✅ Cloudflare (1.0.0.1) (3 ms)
  ✅ Google (8.8.8.8) (4 ms)
  ✅ Google (8.8.4.4) (5 ms)
  ✅ Quad9 (9.9.9.9) (2 ms)
  ✅ Quad9 (149.112.112.112) (1 ms)
  ✅ AliDNS (dns.alidns.com) (46 ms)
  ✅ DNS.SB (doh.dns.sb) (90 ms)
  ✅ Yandex (common.dot.dns.yandex.net) (41 ms)
  ✅ AdGuardDNS (dns.adguard-dns.com) (3 ms)
  ✅ COMSS (dns.comss.one) (43 ms)
  ❌ OpenDNS (doh.opendns.com)
  ✅ NextDNS (dns.nextdns.io) (44 ms)
  ✅ ControlD (freedns.controld.com) (4 ms)
  ✅ IIJ.jp (public.dns.iij.jp) (95 ms)
  ✅ Tencent (doh.pub) (265 ms)
  ✅ LibreDNS (doh.libredns.gr) (11 ms)
  ✅ Mullwad (dns.mullvad.net) (9 ms)
  ✅ Wikimedia (wikimedia-dns.org) (128 ms)

🔒 DNS over TLS (DoT)
  ✅ Cloudflare (1.1.1.1) (43 ms)
  ✅ Cloudflare (1.0.0.1) (44 ms)
  ✅ Google (8.8.8.8) (14 ms)
  ✅ Google (8.8.4.4) (8 ms)
  ✅ Quad9 (9.9.9.9) (1 ms)
  ✅ Quad9 (149.112.112.112) (2 ms)
  ✅ AliDNS (dns.alidns.com) (121 ms)
  ✅ DNS.SB (dot.sb) (15 ms)
  ✅ Yandex (common.dot.dns.yandex.net) (132 ms)
  ✅ AdGuardDNS (dns.adguard-dns.com) (48 ms)
  ✅ COMSS (dns.comss.one) (94 ms)
  ✅ OpenDNS (dns.opendns.com) (4 ms)
  ✅ NextDNS (dns.nextdns.io) (129 ms)
  ✅ ControlD (p0.freedns.controld.com) (4 ms)
  ✅ IIJ.jp (public.dns.iij.jp) (15 ms)
  ✅ Tencent (doh.pub) (140 ms)
  ✅ LibreDNS (doh.libredns.gr) (24 ms)
  ✅ Mullwad (dns.mullvad.net) (29 ms)
  ✅ Wikimedia (wikimedia-dns.org) (120 ms)
```
