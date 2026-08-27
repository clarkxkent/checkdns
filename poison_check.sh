#!/bin/sh

DNS_SERVERS="Cloudflare:1.1.1.1 1.0.0.1;Google:8.8.8.8 8.8.4.4;Quad9:9.9.9.9 149.112.112.112;AliDNS:223.5.5.5 223.6.6.6;DNS.SB:185.222.222.222;Yandex:77.88.8.8 77.88.8.1;AdGuardDNS:94.140.14.14 94.140.15.15;COMSS:212.109.195.93 83.220.169.155;OpenDNS:208.67.222.222 208.67.220.220;NextDNS:45.90.28.80 45.90.30.80;MSK-IX:62.76.76.62 62.76.62.76;ControlD:76.76.2.0 76.76.10.0"

DOMAINS="vk.com youtube.com wikipedia.org yandex.ru google.com instagram.com intel.com whatsapp.com rutracker.org telegram.org"

printf "%-15s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Домен" "Ответ DNS" "Эталон (Порт)" "Статус"
echo "-----------------------------------------------------------------------------------------------"

for SERVER_IP in $DNS_SERVERS;

    for DOMAIN in $DOMAINS; do
        # 1. Запрос к проверяемому DNS серверу на стандартный порт 53
        IP_PUBLIC=$(dig +short @"$SERVER_IP" "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)

        # 2. Получение ЧИСТОГО эталона в РФ через альтернативные порты, где нет перехвата ТСПУ
        # Попытка 1: Quad9
            IP_TRUE=$(dig +short @9.9.9.9 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)
        
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
