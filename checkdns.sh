#!/bin/sh
#set -x

DOMAIN="${1:-nvidia.com}"

if ! command -v dig >/dev/null 2>&1; then
    echo "dig is not installed. Commands to install:"
    echo "Debian/Ubuntu: sudo apt install dnsutils"
    echo "OpenWrt: opkg install bind-dig or apk add bind-dig"
    echo "MacOS: brew install bind"
    echo "Termux: apt upgrade dnsutils"
    exit 1
fi

dns_query() {
    protocol="$1"
    resolver_name="$2"
    resolver_hosts="$3"
    
    # Цикл корректно обойдет все IP, разделенные пробелами
    for resolver_host in $resolver_hosts; do
        # Пропускаем пустые итерации, если они возникнут
        [ -z "$resolver_host" ] && continue
        
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

# Список резолверов (разделитель внутри строки — точка с запятой)
RESOLVERS_UDP="Cloudflare:1.1.1.1 1.0.0.1;Google:8.8.8.8 8.8.4.4;Quad9:9.9.9.9 149.112.112.112;AliDNS:223.5.5.5 223.6.6.6;DNS.SB:185.222.222.222;Yandex:77.88.8.8 77.88.8.1;AdGuardDNS:94.140.14.14 94.140.15.15;COMSS:212.109.195.93 83.220.169.155;OpenDNS:208.67.222.222 208.67.220.220;NextDNS:45.90.28.65 45.90.30.65;MSK-IX:62.76.76.62 62.76.62.76;ControlD:76.76.2.0 76.76.10.0"
RESOLVERS_DOH="Cloudflare:1.1.1.1 1.0.0.1;Google:8.8.8.8 8.8.4.4;Quad9:9.9.9.9 149.112.112.112;AliDNS:dns.alidns.com;DNS.SB:doh.dns.sb;Yandex:common.dot.dns.yandex.net;AdGuardDNS:dns.adguard-dns.com;COMSS:dns.comss.one;OpenDNS:doh.opendns.com/dns-query;NextDNS:dns.nextdns.io;ControlD:freedns.controld.com;IIJ.jp:public.dns.iij.jp;Tencent:doh.pub;LibreDNS:doh.libredns.gr;Mullwad:dns.mullvad.net;Wikimedia:wikimedia-dns.org"
RESOLVERS_DOT="Cloudflare:1.1.1.1 1.0.0.1;Google:8.8.8.8 8.8.4.4;Quad9:9.9.9.9 149.112.112.112;AliDNS:dns.alidns.com;DNS.SB:dot.sb;Yandex:common.dot.dns.yandex.net;AdGuardDNS:dns.adguard-dns.com;COMSS:dns.comss.one;OpenDNS:dns.opendns.com;NextDNS:dns.nextdns.io;ControlD:p0.freedns.controld.com;IIJ.jp:public.dns.iij.jp;Tencent:doh.pub;LibreDNS:doh.libredns.gr;Mullwad:dns.mullvad.net;Wikimedia:wikimedia-dns.org"

run_checks() {
    title="$1"
    proto="$2"
    list="$3"
    
    echo "$title"
    
    # Используем безопасный разбор строки через IFS для ';'
    OLD_IFS="$IFS"
    IFS=";"
    for item in $list; do
        IFS="$OLD_IFS"
        [ -z "$item" ] && continue
        
        name="${item%%:*}"
        hosts="${item#*:}"
        
        dns_query "$proto" "$name" "$hosts"
    done
    IFS="$OLD_IFS"
    echo ""
}

run_checks "🔓 Plain DNS (UDP)" "notcp" "$RESOLVERS_UDP"
run_checks "🔒 DNS over HTTPS (DoH)" "https" "$RESOLVERS_DOH"
run_checks "🔒 DNS over TLS (DoT)" "tls" "$RESOLVERS_DOT"
