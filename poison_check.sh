#!/bin/sh

# Список проверяемых публичных DNS серверов
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9 45.90.28.80 76.76.2.0 223.5.5.5 94.140.14.14 77.88.8.8 77.88.8.88 77.88.8.7"

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
        94.140.14.14) echo "AdGuard-Default" ;;
        *) echo "Unknown" ;;
    esac
}

# Список доменов для проверки
DOMAINS="vkvideo.ru youtube.com discord.com rutracker.org instagram.com whatsapp.com telegram.org"

printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Домен" "Ответ DNS" "Эталон (DoH)" "Статус"
echo "-----------------------------------------------------------------------------------------------"

for SERVER_IP in $DNS_SERVERS; do
    SERVER_NAME=$(get_server_name "$SERVER_IP")

    for DOMAIN in $DOMAINS; do
        # 1. Запрашиваем ПОЛНЫЙ ответ от проверяемого DNS (без +short)
        DIG_OUTPUT=$(dig @$SERVER_IP $DOMAIN A +time=1 +tries=2 2>/dev/null)
        
        # Вытаскиваем статус ответа (NXDOMAIN, NOERROR и т.д.)
        DNS_STATUS=$(echo "$DIG_OUTPUT" | grep -o 'status: [A-Z]*' | awk '{print $2}')
        
        # Вытаскиваем все IP-адреса из секции ANSWER
        ALL_PUBLIC=$(echo "$DIG_OUTPUT" | awk '/;; ANSWER SECTION:/ {flag=1; next} /;;/ {flag=0} flag' | grep -E 'IN[[:space:]]+A' | awk '{print $NF}')
        IP_PUBLIC=$(echo "$ALL_PUBLIC" | head -n1)

        # 2. Получаем эталонные IP через защищенный DoH (используем IP-адреса для надежности)
        ALL_TRUE=$(dig +short @8.8.8.8 +https "$DOMAIN" A +time=1 +tries=2 2>/dev/null | grep -E '^[0-9.]+$')
        
        # Резервный DoH через Яндекс (по IP)
        if [ -z "$ALL_TRUE" ]; then
            ALL_TRUE=$(dig +short @77.88.8.8 +https "$DOMAIN" A +time=1 +tries=2 2>/dev/null | grep -E '^[0-9.]+$')
        fi
        IP_TRUE=$(echo "$ALL_TRUE" | head -n1)

        # 3. Аналитика результатов
        if [ -z "$DNS_STATUS" ] && [ -z "$IP_TRUE" ]; then
            STATUS="⚠️  Ошибка сети"
            IP_PUBLIC="нет ответа"
            IP_TRUE="нет ответа"
        elif [ -z "$DNS_STATUS" ]; then
            STATUS="❌ DNS не ответил"
            IP_PUBLIC="таймаут"
        elif [ -z "$IP_TRUE" ]; then
            STATUS="⚠️  Эталон недоступен"
            IP_TRUE="ошибка"
        # Если проверяемый DNS вернул NXDOMAIN (домен не найден), а эталон нашел IP -> это перехват!
        elif [ "$DNS_STATUS" = "NXDOMAIN" ] && [ -n "$IP_TRUE" ]; then
            IP_PUBLIC="NXDOMAIN"
            if [ "$SERVER_NAME" = "Yandex-Safe" ] || [ "$SERVER_NAME" = "Yandex-Family" ]; then
                STATUS="🛡️  Фильтрация Яндекса"
            else
                STATUS="🚨 ПОДМЕНА (NXDOMAIN)"
            fi
        # Если статус нормальный (NOERROR), но IP-адреса не вернулись
        elif [ -z "$IP_PUBLIC" ] && [ -n "$IP_TRUE" ]; then
            IP_PUBLIC="пустой ответ"
            STATUS="🚨 ПОДМЕНА (Пустой IP)"
        else
            # Умное сравнение подсетей для выданных IP
            SUBNET_PUBLIC=$(echo "$IP_PUBLIC" | cut -d. -f1-2)
            SUBNET_TRUE=$(echo "$IP_TRUE" | cut -d. -f1-2)
            
            MATCH_FOUND=0
            if [ "$IP_PUBLIC" = "$IP_TRUE" ]; then
                MATCH_FOUND=1
            elif [ "$SUBNET_PUBLIC" = "$SUBNET_TRUE" ]; then
                MATCH_FOUND=1
            else
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
