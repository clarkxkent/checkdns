#!/bin/sh

# Список проверяемых публичных DNS серверов
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9 45.90.28.80 76.76.2.0 223.5.5.5 77.88.8.8 77.88.8.88 77.88.8.7 208.67.222.222 94.140.14.14"

get_server_name() {
    case "$1" in
        8.8.8.8) echo "Google-DNS" ;;
        1.1.1.1) echo "Cloudflare" ;;
        45.90.28.80) echo "NextDNS" ;;
        76.76.2.0) echo "ControlD" ;;
        223.5.5.5) echo "AliDNS" ;;
        77.88.8.8) echo "Yandex-Basic" ;;
        77.88.8.88) echo "Yandex-Safe" ;;
        77.88.8.7) echo "Yandex-Family" ;;
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
        # 1. Получаем ВСЕ IP от проверяемого DNS (выбираем первый для вывода в таблицу)
        ALL_PUBLIC=$(dig +short @"$SERVER_IP" "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$')
        IP_PUBLIC=$(echo "$ALL_PUBLIC" | head -n1)

        # 2. Получаем ВСЕ эталонные IP (выбираем первый для вывода в таблицу)
        ALL_TRUE=$(dig +short @45.90.28.92 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$')
        
        # Резервный DoH через Яндекс
        if [ -z "$ALL_TRUE" ]; then
            ALL_TRUE=$(dig +short @77.88.8.8 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$')
        fi
        IP_TRUE=$(echo "$ALL_TRUE" | head -n1)

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
        else
            # Логика умного сравнения подсетей (проверяем по первым 2 октетам, например 142.250.)
            SUBNET_PUBLIC=$(echo "$IP_PUBLIC" | cut -d. -f1-2)
            SUBNET_TRUE=$(echo "$IP_TRUE" | cut -d. -f1-2)
            
            # Проверяем точное совпадение, пересечение списков IP или совпадение подсети класса B
            MATCH_FOUND=0
            if [ "$IP_PUBLIC" = "$IP_TRUE" ]; then
                MATCH_FOUND=1
            elif [ "$SUBNET_PUBLIC" = "$SUBNET_TRUE" ]; then
                MATCH_FOUND=1
            else
                # Проверяем, есть ли публичный IP в полном списке эталонных IP
                for ip in $ALL_TRUE; do
                    if [ "$IP_PUBLIC" = "$ip" ]; then
                        MATCH_FOUND=1
                        break
                    fi
                done
            fi

            if [ "$MATCH_FOUND" -eq 1 ]; then
                STATUS="✅ ОК"
            else
                # Исключение для фильтрации Яндекса, если решите вернуть Safe/Family IP в список
                if [ "$SERVER_NAME" = "Yandex-Safe" ] || [ "$SERVER_NAME" = "Yandex-Family" ]; then
                    STATUS="🛡️  Фильтрация Яндекса"
                else
                    STATUS="🚨 ПОДМЕНА!"
                fi
            fi
        fi

        printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "$SERVER_NAME" "$DOMAIN" "$IP_PUBLIC" "$IP_TRUE" "$STATUS"
    done
    echo "-----------------------------------------------------------------------------------------------"
done
