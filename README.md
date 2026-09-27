# my-sysadmin-scripts

Сквозной проект по дисциплине «Системное администрирование» (ДЗ1 + ДЗ2, капстоун).
Скрипт мониторинга системы, упакованный в Docker-контейнер и развёрнутый как сервис
за Nginx с HTTPS и systemd.

## Состав проекта

| Файл | Назначение |
|------|-----------|
| `script.sh` | Сборщик метрик (вариант Б): память, диски, uptime → `monitor.log` каждые 10 сек |
| `Dockerfile` | Образ на базе `ubuntu:22.04` + `python3` + `procps`; скрипт + `http.server` на 8080 |
| `bootstrap.sh` | Поднимает весь проект с нуля: пакеты → образ → RAID/LVM → TLS → nginx → systemd |
| `.gitignore` | Исключает рабочий `monitor.log` из репозитория |

## Как это работает end-to-end

1. **Скрипт** (`script.sh`) в бесконечном цикле пишет метрики в `monitor.log`.
2. **Контейнер** запускает скрипт и `python3 -m http.server 8080`, отдавая содержимое `/var/www` по HTTP.
3. **Nginx** принимает HTTPS (443), проксирует на `127.0.0.1:8080`, HTTP (80) редиректит на HTTPS (301).
4. **systemd** (`my-app.service`) держит контейнер запущенным (`docker start -a my-app`) и перезапускает при сбое.
5. **RAID 1** (`/dev/md0`) и **LVM** (`vg_data/lv_logs`) смонтированы в `/mnt/raid` и `/mnt/logs`.

## Быстрый запуск на чистой машине

    git clone https://github.com/Marfines/my-sysadmin-scripts.git
    cd my-sysadmin-scripts
    chmod +x bootstrap.sh
    ./bootstrap.sh

После выполнения: `https://127.0.0.1` отдаёт `200 OK` через Nginx, `docker ps` показывает `my-app` Up, `/proc/mdstat` показывает активный `md0`.

## Проверка

    docker ps                                    # контейнер my-app Up
    docker exec my-app cat /var/www/monitor.log  # метрики пишутся
    sudo nginx -t                                # конфиг валиден
    sudo systemctl status my-app --no-pager      # служба active (running) + enabled
    curl -kI https://127.0.0.1                   # HTTP/1.1 200 OK
    cat /proc/mdstat                             # md0 : active raid1
    sudo lvs; df -h /mnt/raid /mnt/logs          # LVM и монтирования

## Стек

- Ubuntu 22.04 (Multipass VM)
- Docker 29.x, Python 3.10
- mdadm (RAID 1), LVM2
- Nginx 1.18, OpenSSL (self-signed TLS)
- systemd
