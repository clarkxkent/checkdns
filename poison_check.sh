#!/bin/sh

# Список проверяемых публичных DNS серверов (в формате строки для POSIX sh)
DNS_SERVERS="8.8.8.8 1.1.1.1 77.88.8.8 9.9.9.9 208.67.222.222 94.140.14.14"

# Имена серверов для красивого вывода
get_server_name() {
    case "$1" in
        8.8.8.8) echo "Google" ;;
        1.1.1.1) echo "Cloudflare" ;;
        77.88.8.8) echo "Yandex" ;;
        9.9.9.9) echo "Quad9" ;;
        208.67.222.222) echo "OpenDNS" ;;
        94.140.14.14) echo "AdGuard" ;;
        *) echo "Unknown" ;;
    esac
}

# Список популярных доменов
DOMAINS="vk.com youtube.com wikipedia.org yandex.ru google.com instagram.com intel.com whatsapp.com rutracker.org telegram.org"

# Отрисовка шапки таблицы (используем стандартный printf)
printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Домен" "Ответ DNS" "Эталон (DoH)" "Статус"
echo "-----------------------------------------------------------------------------------------------"

for SERVER_IP in $DNS_SERVERS; do
    SERVER_NAME=$(get_server_name "$SERVER_IP")

    for DOMAIN in $DOMAINS; do
        # 1. Запрос к проверяемому DNS серверу через nslookup (стандарт для OpenWrt)
        IP_PUBLIC=$(nslookup "$DOMAIN" "$SERVER_IP" 2>/dev/null | awk '/^Address [0-9]+:/ { S=1; next } S && /^[0-9.]+$/ { print $1; exit }')
        
        # Если nslookup выдал пустую строку, пробуем альтернативный парсинг (зависит от версии BusyBox)
        if [ -z "$IP_PUBLIC" ]; then
            IP_PUBLIC=$(nslookup "$DOMAIN" "$SERVER_IP" 2>/dev/null | awk '/^Address: / { print $2; exit }')
        fi

        # 2. Получение эталона через DoH (используем API Google по IP для обхода блокировок SNI)
        # Отправляем текстовый запрос через curl
        JSON_RESP=$(curl -s --connect-timeout 2 -H "Accept: application/json" "https://8.8.8{DOMAIN}&type=A" 2>/dev/null)
        
        # Парсим IP без jq с помощью sed/awk (вытаскиваем значение из поля "data")
        IP_TRUE=$(echo "$JSON_RESP" | awk -F'"data":"' '{print $2}' | awk -F'"' '{print $1}' | grep -E '^[0-9.]+$' | head -n1)

        # Резервный DoH через Cloudflare по IP, если Google заблокирован
        if [ -z "$IP_TRUE" ]; then
            JSON_RESP=$(curl -s --connect-timeout 2 -H "Accept: application/dns-json" "https://1.1.1{DOMAIN}&type=A" 2>/dev/null)
            IP_TRUE=$(echo "$JSON_RESP" | awk -F'"data":"' '{print $2}' | awk -F'"' '{print $1}' | grep -E '^[0-9.]+$' | head -n1)
        fi

        # 3. Аналитика результатов
        if [ -z "$IP_PUBLIC" ] && [ -z "$IP_TRUE" ]; then
            STATUS="⚠️  Ошибка сети"
            IP_PUBLIC="нет ответа"
            IP_TRUE="нет ответа"
        elif [ -z "$IP_PUBLIC" ]; then
            STATUS="❌ DNS не ответил"
            IP_PUBLIC="ошибка"
        elif [ -z "$IP_TRUE" ]; then
            STATUS="⚠️  DoH недоступен"
            IP_TRUE="ошибка"
        elif [ "$IP_PUBLIC" = "$IP_TRUE" ]; then
            STATUS="✅ ОК"
        else
            STATUS="🚨 ПОДМЕНА!"
        fi

        printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "$SERVER_NAME" "$DOMAIN" "$IP_PUBLIC" "$IP_TRUE" "$STATUS"
    done
    echo "-----------------------------------------------------------------------------------------------"
done
