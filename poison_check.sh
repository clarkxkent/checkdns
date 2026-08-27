#!/bin/sh

# Проверка ответов публичных DNS-серверов относительно нескольких DoH-резолверов.
# Совместимо с /bin/sh (ash/BusyBox).
#
# Важно: различие IP у CDN само по себе НЕ доказывает DNS-подмену.
# Поэтому несовпадающие корректные ответы отмечаются как «ОТЛИЧАЕТСЯ»,
# а не как безусловная «ПОДМЕНА».

DNS_SERVERS="
Google-DNS:Pri:8.8.8.8
Google-DNS:Sec:8.8.4.4
Cloudflare:Pri:1.1.1.1
Cloudflare:Sec:1.0.0.1
Quad9-Secure:Pri:9.9.9.9
Quad9-Secure:Sec:149.112.112.112
AdGuard-Default:Pri:94.140.14.14
AdGuard-Default:Sec:94.140.15.15
NextDNS:Pri:45.90.28.80
NextDNS:Sec:45.90.30.80
ControlD:Pri:76.76.2.0
ControlD:Sec:76.76.10.0
AliDNS:Pri:223.5.5.5
AliDNS:Sec:223.6.6.6
Yandex-Basic:Pri:77.88.8.8
Yandex-Basic:Sec:77.88.8.1
Yandex-Safe:Pri:77.88.8.88
Yandex-Safe:Sec:77.88.8.2
Yandex-Family:Pri:77.88.8.7
Yandex-Family:Sec:77.88.8.3
"

DOMAINS="vkvideo.ru youtube.com discord.com rutracker.org pornhub.com instagram.com whatsapp.com telegram.org"

# Несколько независимых DoH-резолверов. Их ответы объединяются в эталонный набор,
# чтобы уменьшить ложные срабатывания на CDN/geolocation.
REFERENCE_DOH_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9"

if ! command -v dig >/dev/null 2>&1; then
 echo "Ошибка: команда 'dig' не найдена. Нужен пакет с dig (обычно bind-dig)." >&2
 exit 1
fi

# Проверяем поддержку +https самой утилитой dig.
DOH_SUPPORTED=0
if dig -h 2>&1 | grep -qi 'https'; then
 DOH_SUPPORTED=1
fi

TMP_DIR="${TMPDIR:-/tmp}/dns-check.$$"
if ! mkdir -p "$TMP_DIR"; then
 echo "Ошибка: не удалось создать временный каталог $TMP_DIR" >&2
 exit 1
fi
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

get_status() {
 # Извлекает DNS RCODE из строки HEADER, например NOERROR/NXDOMAIN/SERVFAIL.
 printf '%s\n' "$1" | awk '
 /status:/ {
 for (i = 1; i <= NF; i++) {
 if ($i == "status:") {
 s = $(i + 1)
 gsub(/,/, "", s)
 print s
 exit
 }
 }
 }
 '
}

get_a_records() {
 # dig +answer: owner TTL class type rdata
 printf '%s\n' "$1" | awk '$4 == "A" && $5 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $5}' | sort -u
}

first_ip() {
 printf '%s\n' "$1" | awk 'NF {print; exit}'
}

count_lines() {
 printf '%s\n' "$1" | awk 'NF {n++} END {print n+0}'
}

format_ip_set() {
 SET="$1"
 FIRST=$(first_ip "$SET")
 [ -z "$FIRST" ] && return

 COUNT=$(count_lines "$SET")
 if [ "$COUNT" -gt 1 ]; then
 printf '%s(+%s)' "$FIRST" "$((COUNT - 1))"
 else
 printf '%s' "$FIRST"
 fi
}

sets_intersect() {
 # Возвращает 0, если два многострочных набора имеют хотя бы один общий IP.
 SET_A="$1"
 SET_B="$2"

 for A in $SET_A; do
 for B in $SET_B; do
 [ "$A" = "$B" ] && return 0
 done
 done
 return 1
}

is_yandex_filtered() {
 case "$1" in
 Yandex-Safe|Yandex-Family) return 0;;
 *) return 1;;
 esac
}

build_reference_cache() {
 DOMAIN="$1"
 STATUS_FILE="$TMP_DIR/$DOMAIN.status"
 IPS_FILE="$TMP_DIR/$DOMAIN.ips"

: > "$IPS_FILE"

 if [ "$DOH_SUPPORTED" -ne 1 ]; then
 echo "UNAVAILABLE" > "$STATUS_FILE"
 return
 fi

 ANY_RESPONSE=0
 SEEN_NOERROR=0
 SEEN_NXDOMAIN=0
 FIRST_STATUS=""

 for REF_SERVER in $REFERENCE_DOH_SERVERS; do
 OUT=$(dig @"$REF_SERVER" "$DOMAIN" A +https +time=2 +tries=1 +noall +comments +answer 2>/dev/null)
 ST=$(get_status "$OUT")

 [ -z "$ST" ] && continue

 ANY_RESPONSE=1
 [ -z "$FIRST_STATUS" ] && FIRST_STATUS="$ST"

 case "$ST" in
 NOERROR)
 SEEN_NOERROR=1
 get_a_records "$OUT" >> "$IPS_FILE"
;;
 NXDOMAIN)
 SEEN_NXDOMAIN=1
;;
 esac
 done

 if [ -s "$IPS_FILE" ]; then
 sort -u "$IPS_FILE" -o "$IPS_FILE"
 echo "NOERROR" > "$STATUS_FILE"
 elif [ "$SEEN_NOERROR" -eq 1 ]; then
 echo "NOERROR" > "$STATUS_FILE"
 elif [ "$SEEN_NXDOMAIN" -eq 1 ]; then
 echo "NXDOMAIN" > "$STATUS_FILE"
 elif [ "$ANY_RESPONSE" -eq 1 ]; then
 echo "${FIRST_STATUS:-UNKNOWN}" > "$STATUS_FILE"
 else
 echo "UNAVAILABLE" > "$STATUS_FILE"
 fi
}
# Эталонные DoH-ответы не зависят от проверяемого DNS, поэтому получаем их один раз
# на домен, а не повторяем для каждого DNS-сервера.
for DOMAIN in $DOMAINS; do
 build_reference_cache "$DOMAIN"
done

if [ "$DOH_SUPPORTED" -ne 1 ]; then
 echo "Предупреждение: установленный dig не поддерживает +https; DoH-эталон недоступен." >&2
fi

printf "%-16s | %-4s | %-16s | %-22s | %-22s | %s\n" \
 "DNS Сервер" "Тип" "Домен" "Ответ DNS" "Эталон (DoH)" "Статус"
echo "----------------------------------------------------------------------------------------------------------------"

for SERVER_INFO in $DNS_SERVERS; do
 SERVER_NAME=$(printf '%s\n' "$SERVER_INFO" | cut -d: -f1)
 SERVER_TYPE=$(printf '%s\n' "$SERVER_INFO" | cut -d: -f2)
 SERVER_IP=$(printf '%s\n' "$SERVER_INFO" | cut -d: -f3)

 [ -z "$SERVER_IP" ] && continue

 for DOMAIN in $DOMAINS; do
 DIG_OUTPUT=$(dig @"$SERVER_IP" "$DOMAIN" A +time=1 +tries=2 +noall +comments +answer 2>/dev/null)
 DNS_STATUS=$(get_status "$DIG_OUTPUT")
 ALL_PUBLIC=$(get_a_records "$DIG_OUTPUT")

 REF_STATUS=$(cat "$TMP_DIR/$DOMAIN.status" 2>/dev/null)
 ALL_TRUE=$(cat "$TMP_DIR/$DOMAIN.ips" 2>/dev/null)

 PUBLIC_DISPLAY=$(format_ip_set "$ALL_PUBLIC")
 TRUE_DISPLAY=$(format_ip_set "$ALL_TRUE")

 [ -z "$PUBLIC_DISPLAY" ] && PUBLIC_DISPLAY="-"
 [ -z "$TRUE_DISPLAY" ] && TRUE_DISPLAY="-"

 if [ -z "$DNS_STATUS" ]; then
 STATUS="⚠️ DNS не ответил"
 PUBLIC_DISPLAY="таймаут"

 elif [ "$REF_STATUS" = "UNAVAILABLE" ] || [ -z "$REF_STATUS" ]; then
 STATUS="⚠️ Эталон недоступен"

 else
 case "$DNS_STATUS" in
 NOERROR)
 if [ -z "$ALL_PUBLIC" ]; then
 if [ "$REF_STATUS" = "NXDOMAIN" ]; then
 STATUS="⚠️ Ответ отличается"
 elif [ -n "$ALL_TRUE" ]; then
 if is_yandex_filtered "$SERVER_NAME"; then
 STATUS="🛡️ Фильтрация Яндекса"
 else
 STATUS="⚠️ NOERROR без A"
 fi
 else
 STATUS="✅ ОК (без A)"
 fi
 elif [ "$REF_STATUS" = "NXDOMAIN" ]; then
 STATUS="⚠️ Ответ отличается"
 elif [ -z "$ALL_TRUE" ]; then
 STATUS="⚠️ Эталон без A"
 elif sets_intersect "$ALL_PUBLIC" "$ALL_TRUE"; then
 STATUS="✅ ОК"
 else
 if is_yandex_filtered "$SERVER_NAME"; then
 STATUS="🛡️ Фильтрация Яндекса"
 else
 # Для CDN разные IP у разных резолверов нормальны.
 # Без дополнительного доказательства это не называем подменой.
 STATUS="🚨 ОТЛИЧАЕТСЯ"
 fi
 fi
;;

 NXDOMAIN)
 PUBLIC_DISPLAY="NXDOMAIN"
 if [ "$REF_STATUS" = "NXDOMAIN" ]; then
 STATUS="? ОК (NXDOMAIN)"
 elif [ -n "$ALL_TRUE" ] || [ "$REF_STATUS" = "NOERROR" ]; then
 if is_yandex_filtered "$SERVER_NAME"; then
 STATUS="🛡️  Фильтрация Яндекса"
 else
 STATUS="⚠️ ВОЗМОЖНО ПОДМЕНА (NXDOMAIN)"
 fi
 else
 STATUS="🚨 ПОДМЕНА (NXDOMAIN)"
 fi
;;

 SERVFAIL)
 PUBLIC_DISPLAY="SERVFAIL"
 STATUS="❌ SERVFAIL"
;;

 REFUSED)
 PUBLIC_DISPLAY="REFUSED"
 STATUS="❌ REFUSED"
;;

 FORMERR)
 PUBLIC_DISPLAY="FORMERR"
 STATUS="❌ FORMERR"
;;

 NOTIMP)
 PUBLIC_DISPLAY="NOTIMP"
 STATUS="❌ NOTIMP"
;;

 *)
 [ -z "$PUBLIC_DISPLAY" ] && PUBLIC_DISPLAY="$DNS_STATUS"
 STATUS="?? DNS status: $DNS_STATUS"
;;
 esac
 fi

 printf "%-16s | %-4s | %-16s | %-22s | %-22s | %s\n" \
 "$SERVER_NAME" "$SERVER_TYPE" "$DOMAIN" "$PUBLIC_DISPLAY" "$TRUE_DISPLAY" "$STATUS"
 done

 echo "----------------------------------------------------------------------------------------------------------------"
done
