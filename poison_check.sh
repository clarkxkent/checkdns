#!/bin/bash

# Проверяемые публичные DNS-серверы
DNS_SERVERS=(
    "Google:8.8.8.8"
    "Google:8.8.4.4"
    "Cloudflare:1.1.1.1"
    "Cloudflare:1.0.0.1"
    "Quad9:9.9.9.9"
    "Quad9:149.112.112.112"
    "OpenDNS:208.67.222.222"
    "OpenDNS:208.67.220.220"
    "AdGuard:94.140.14.14"
    "AdGuard:94.140.15.15"
    "Yandex:77.88.8.8"
    "Yandex:77.88.8.1"
)

# Сайты для тестирования
DOMAINS="vk.com lkfl2.nalog.ru youtube.com github.com wikipedia.org yandex.ru google.com instagram.com intel.com whatsapp.com rutracker.org telegram.org"

printf "%-18s | %-15s | %-15s | %-15s | %-s\n" "DNS Сервер" "Домен" "Ответ DNS" "Эталон (DoH)" "Статус"
echo "-----------------------------------------------------------------------------------------------"

for SERVER_INFO in "${DNS_SERVERS[@]}"; do
    SERVER_NAME="${SERVER_INFO%%:*}"
    SERVER_IP="${SERVER_INFO##*:}"

    for DOMAIN in $DOMAINS; do
        # 1. Запрос к проверяемому обычному DNS серверу
        IP_PUBLIC=$(dig +short @"$SERVER_IP" "$DOMAIN" A 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)

        # 2. Получение эталона через нативный DoH в dig (сначала Яндекс, затем Google)
        # Для dig таймаут ставим 2 секунды, чтобы скрипт не зависал
        IP_TRUE=$(dig +short @77.88.8.8 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)

        # Резервный DoH через Google (указываем напрямую сервер @8.8.8.8 с флагом +https для обхода SNI-блокировок)
        if [ -z "$IP_TRUE" ]; then
            IP_TRUE=$(dig +short @8.8.8.8 +https "$DOMAIN" A +time=2 +tries=1 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)
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

        printf "%-10s | %-20s | %-15s | %-15s | %-s\n" "$SERVER_NAME" "$DOMAIN" "$IP_PUBLIC" "$IP_TRUE" "$STATUS"
    done
    echo "-----------------------------------------------------------------------------------------------"
done
