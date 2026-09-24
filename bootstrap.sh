#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "==> [1/6] Пакеты"
sudo apt-get update
sudo apt-get install -y docker.io mdadm lvm2 nginx openssl

echo "==> [2/6] Образ"
sudo docker build -t my-script .

echo "==> [3/6] RAID1 + LVM на loop-устройствах"
sudo mkdir -p /mnt/raid-lab
cd /mnt/raid-lab
sudo dd if=/dev/zero of=disk1.img bs=1M count=512 status=none
sudo dd if=/dev/zero of=disk2.img bs=1M count=512 status=none
sudo dd if=/dev/zero of=disk3.img bs=1M count=512 status=none

# --show печатает имя устройства в момент создания — не парсим losetup -a
LOOP1=$(sudo losetup -fP --show disk1.img)
LOOP2=$(sudo losetup -fP --show disk2.img)
LOOP3=$(sudo losetup -fP --show disk3.img)
echo "    loop: $LOOP1 $LOOP2 $LOOP3"

yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid

yes | sudo pvcreate "$LOOP3"
sudo vgcreate vg_data "$LOOP3"
yes | sudo lvcreate -L 200M -n lv_logs vg_data
sudo mkfs.ext4 -F /dev/vg_data/lv_logs
sudo mkdir -p /mnt/logs
sudo mount /dev/vg_data/lv_logs /mnt/logs

echo "==> [4/6] TLS-сертификат"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key \
  -out /etc/ssl/certs/my-app.crt \
  -subj "/CN=my-app.local"

echo "==> [5/6] nginx"
sudo tee /etc/nginx/sites-available/my-app > /dev/null <<'NGINX'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate     /etc/ssl/certs/my-app.crt;
    ssl_certificate_key /etc/ssl/private/my-app.key;
    location / { proxy_pass http://127.0.0.1:8080; }
}
NGINX
sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

echo "==> [6/6] Контейнер + systemd"
sudo docker rm -f my-app 2>/dev/null || true
sudo docker run -d -p 8080:8080 --name my-app my-script

sudo tee /etc/systemd/system/my-app.service > /dev/null <<'UNIT'
[Unit]
Description=my-app service
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start -a my-app
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable my-app
sudo systemctl start my-app

sleep 3   # иначе curl поймает 502, пока приложение в контейнере поднимается
sudo systemctl status my-app --no-pager || true
echo "--- проверка HTTPS ---"
curl -kI https://127.0.0.1 || true
echo "==> Готово"
