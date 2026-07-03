#!/bin/sh
#set -x

DOMAIN="${1:-itdog.info}"

if ! command -v dig >/dev/null 2>&1; then
    echo "dig is not installed. Commands to install:"
    echo "Debian/Ubuntu: sudo apt install dnsutils"
    echo "OpenWrt: opkg install bind-dig"
    echo "MacOS: brew install bind"
    echo "Termux: apt upgrade dnsutils"
    exit 1
fi

dns_query() {
    protocol="$1"
    resolver_name="$2"
    resolver_hosts="$3"  # Список хостов через пробел
    
    # Перебираем абсолютно все хосты для этого резолвера
    for resolver_host in $resolver_hosts; do
        result=$(dig +${protocol} +tries=1 +time=3 @"$resolver_host" "$DOMAIN" A 2>&1)
        
        # Проверяем на сетевые ошибки подключения
        if echo "$result" | grep -q "failed:\|timed out\|no servers could be reached\|connection refused\|host unreachable"; then
            echo "  ❌ $resolver_name ($resolver_host)"
            echo "$result" | grep -E "(failed:|timed out|no servers|connection|unreachable)" | sed 's/^/    /'
            continue
        fi
        
        query_time=$(echo "$result" | grep "Query time:" | sed 's/.*Query time: \([0-9]*\) msec.*/\1/')
        ip_lines=$(echo "$result" | grep -A 10 "ANSWER SECTION:" | grep -E "IN[[:space:]]+A[[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3}")
        
        if [ -n "$ip_lines" ]; then
            if [ -n "$query_time" ]; then
                echo "  ✅ $resolver_name ($resolver_host) ($query_time ms)"
            else
                echo "  ✅ $resolver_name ($resolver_host)"
            fi
        else
            if [ -n "$query_time" ]; then
                echo "  ❌ $resolver_name ($resolver_host) ($query_time ms)"
            else
                echo "  ❌ $resolver_name ($resolver_host)"
            fi
            echo "$result" | grep -v '^$' | grep -v '^;' | sed 's/^/    /'
        fi
    done
}

# Списки серверов (основные и резервные через пробел)
RESOLVERS_UDP="
Cloudflare:1.1.1.1 1.0.0.1
Google:8.8.8.8 8.8.4.4
Quad9:9.9.9.9 149.112.112.112
AdGuardDNS:94.140.14.14 94.140.15.15
NextDNS:45.90.28.65 45.90.30.65"

RESOLVERS_DOH="
Cloudflare:1.1.1.1 1.0.0.1
Google:8.8.8.8 8.8.4.4
Quad9:9.9.9.9 149.112.112.112
AdGuardDNS:://adguard-dns.com
NextDNS:dns.nextdns.io"

RESOLVERS_DOT="
Cloudflare:1.1.1.1 1.0.0.1
Google:8.8.8.8 8.8.4.4
Quad9:9.9.9.9 149.112.112.112
AdGuardDNS:://adguard-dns.com
NextDNS:dns.nextdns.io"

OLD_IFS="$IFS"

echo "🔓 Plain DNS (UDP)"
IFS="
"
for resolver in $RESOLVERS_UDP; do
    [ -z "$resolver" ] && continue
    IFS="$OLD_IFS"
    name=${resolver%%:*}
    hosts=${resolver#*:}
    dns_query "notcp" "$name" "$hosts"
done

echo ""
echo "🔒 DNS over HTTPS (DoH)"
IFS="
"
for resolver in $RESOLVERS_DOH; do
    [ -z "$resolver" ] && continue
    IFS="$OLD_IFS"
    name=${resolver%%:*}
    hosts=${resolver#*:}
    dns_query "https" "$name" "$hosts"
done

echo ""
echo "🔒 DNS over TLS (DoT)"
IFS="
"
for resolver in $RESOLVERS_DOT; do
    [ -z "$resolver" ] && continue
    IFS="$OLD_IFS"
    name=${resolver%%:*}
    hosts=${resolver#*:}
    dns_query "tls" "$name" "$hosts"
done

IFS="$OLD_IFS"
