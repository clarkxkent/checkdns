#!/bin/sh

# Список проверяемых публичных DNS серверов (Имя:Тип:IP)
DNS_SERVERS="
Google-DNS:Pri:8.8.8.8
Google-DNS:Sec:8.8.4.4
Cloudflare:Pri:1.1.1.1
Cloudflare:Sec:1.0.0.1
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
Quad9-Secure:Pri:9.9.9.9
Quad9-Secure:Sec:149.112.112.112
AdGuard-Default:Pri:94.140.14.14
AdGuard-Default:Sec:94.140.15.15
"

# Функция определения главного домена владельца IP через Reverse DNS (PTR)
get_ptr_domain() {
    local ip="$1"
    [ -z "$ip" ] && return
    local ptr=$(dig +short -x "$ip" 2>/dev/null | tail -n1 | tr 'A-Z' 'a-z')
    [ -z "$ptr" ] && return
    
    ptr=$(echo "$ptr" | sed 's/\.$//')
    echo "$ptr" | awk -F. '{ if (NF>=2) print $(NF-1)"."$NF; else print $0 }'
}

# Список доменов для проверки
DOMAINS="vkvideo.ru youtube.com discord.com rutracker.org pornhub.com instagram.com whatsapp.com telegram.org"

printf "%-15s | %-4s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Тип" "Домен" "Ответ DNS" "Эталон (DoH)" "Статус"
echo "------------------------------------------------------------------------------------------------------"

for SERVER_INFO in $DNS_SERVERS; do
    # Разбираем строку формата Имя:Тип:IP без использования bash-массивов
    SERVER_NAME=$(echo "$SERVER_INFO" | cut -d: -f1)
    SERVER_TYPE=$(echo "$SERVER_INFO" | cut -d: -f2)
    SERVER_IP=$(echo "$SERVER_INFO" | cut -d: -f3)

    [ -z "$SERVER_IP" ] && continue

    for DOMAIN in $DOMAINS; do
        # 1. Запрашиваем ПОЛНЫЙ ответ от проверяемого DNS
        DIG_OUTPUT=$(dig @$SERVER_IP $DOMAIN A +time=1 +tries=2 2>/dev/null)
        
        DNS_STATUS=$(echo "$DIG_OUTPUT" | grep -o 'status: [A-Z]*' | awk '{print $2}')
        ALL_PUBLIC=$(echo "$DIG_OUTPUT" | awk '/;; ANSWER SECTION:/ {flag=1; next} /;;/ {flag=0} flag' | grep -E 'IN[[:space:]]+A' | awk '{print $NF}')
        IP_PUBLIC=$(echo "$ALL_PUBLIC" | head -n1)

        # 2. Получаем эталонные IP через защищенный DoH
        ALL_TRUE=$(dig +short @8.8.8.8 +https "$DOMAIN" A +time=1 +tries=2 2>/dev/null | grep -E '^[0-9.]+$')
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
        elif [ "$DNS_STATUS" = "NXDOMAIN" ] && [ -n "$IP_TRUE" ]; then
            IP_PUBLIC="NXDOMAIN"
            if [ "$SERVER_NAME" = "Yandex-Safe" ] || [ "$SERVER_NAME" = "Yandex-Family" ]; then
                STATUS="🛡️  Фильтрация Яндекса"
            else
                STATUS="🚨 ПОДМЕНА (NXDOMAIN)"
            fi
        elif [ -z "$IP_PUBLIC" ] && [ -n "$IP_TRUE" ]; then
            IP_PUBLIC="пустой ответ"
            STATUS="🚨 ПОДМЕНА (Пустой IP)"
        else
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

            # 4. Динамическая проверка владельца инфраструктуры через Reverse DNS (PTR)
            if [ "$MATCH_FOUND" -eq 0 ]; then
                PTR_PUBLIC=$(get_ptr_domain "$IP_PUBLIC")
                PTR_TRUE=$(get_ptr_domain "$IP_TRUE")
                
                if [ -n "$PTR_PUBLIC" ] && [ "$PTR_PUBLIC" = "$PTR_TRUE" ]; then
                    MATCH_FOUND=1
                elif [ "$PTR_PUBLIC" = "1e100.net" ] && [ "$PTR_TRUE" = "google.com" ]; then
                    MATCH_FOUND=1
                elif [ "$PTR_PUBLIC" = "google.com" ] && [ "$PTR_TRUE" = "1e100.net" ]; then
                    MATCH_FOUND=1
                fi
            fi

            # Назначение итогового статуса
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

        printf "%-15s | %-4s | %-15s | %-15s | %-15s | %-s\n" "$SERVER_NAME" "$SERVER_TYPE" "$DOMAIN" "$IP_PUBLIC" "$IP_TRUE" "$STATUS"
    done
    echo "------------------------------------------------------------------------------------------------------"
done
