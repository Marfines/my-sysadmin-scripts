#!/bin/bash

INTERVAL=10
LOG_FILE="monitor.log"

while true
do
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---" >> "$LOG_FILE"

    if ! free -h >> "$LOG_FILE"; then
        echo "Ошибка: не удалось получить информацию о памяти" >> "$LOG_FILE"
    fi

    if ! df -h >> "$LOG_FILE"; then
        echo "Ошибка: не удалось получить информацию о дисках" >> "$LOG_FILE"
    fi

    if ! uptime >> "$LOG_FILE"; then
        echo "Ошибка: не удалось получить информацию о времени работы системы" >> "$LOG_FILE"
    fi

    sleep "$INTERVAL"
done
