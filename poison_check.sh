#!/bin/sh

# Список проверяемых публичных DNS серверов
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9 45.90.28.80 76.76.2.0 223.5.5.5 77.88.8.8 208.67.222.222 94.140.14.14"

get_server_name() {
    case "$1" in
        8.8.8.8) echo "Google-DNS" ;;
        1.1.1.1) echo "Cloudflare" ;;
        45.90.28.80) echo "NextDNS" ;;
        76.76.2.0) echo "ControlD" ;;
        223.5.5.5) echo "AliDNS" ;;
        77.88.8.8) echo "Yandex-Basic" ;;
        9.9.9.9) echo "Quad9-Secure" ;;
        208.67.222.222) echo "Cisco-OpenDNS" ;;
        94.140.14.14) echo "AdGuard-Default" ;;
        *) echo "Unknown" ;;
    esac
}

# Список доменов для проверки
DOMAINS="vk.com youtube.com wikipedia.org yandex.ru google.com instagram.com intel.com whatsapp.com rutracker.org telegram.org"

printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Домен" "Ответ DNS" "Эталон (Порт)" "Статус"
echo "-----------------------------------------------------------------------------------------------"

for SERVER_IP in $DNS_SERVERS; do
    SERVER_NAME=$(get_server_name "$SERVER_IP")

    for DOMAIN in $DOMAINS; do
        # 1. Запрос к проверяемому DNS серверу на стандартный порт 53
        IP_PUBLIC=$(dig +short @"$SERVER_IP" "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)

        # 2. Получение ЧИСТОГО эталона в РФ через альтернативные порты, где нет перехвата ТСПУ
        # Попытка 1: NextDNS
        IP_TRUE=$(dig +short @45.90.28.92 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)

        # Попытка 2: Яндекс.Базовый (как резерв для незаблокированных в РФ сайтов)
        if [ -z "$IP_TRUE" ]; then
            IP_TRUE=$(dig +short @77.88.8.8 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)
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
            STATUS="⚠️  Эталон недоступен"
            IP_TRUE="ошибка"
        elif [ "$IP_PUBLIC" = "$IP_TRUE" ]; then
            STATUS="✅ ОК"
        else
            # Если это фильтрующий сервер Яндекса, то подмена — это его штатная работа
            if [ "$SERVER_NAME" = "Yandex-Safe" ] || [ "$SERVER_NAME" = "Yandex-Family" ]; then
                STATUS="🛡️  Фильтрация Яндекса"
            else
                STATUS="🚨 ПОДМЕНА!"
            fi
        fi

        printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "$SERVER_NAME" "$DOMAIN" "$IP_PUBLIC" "$IP_TRUE" "$STATUS"
    done
    echo "-----------------------------------------------------------------------------------------------"
done
