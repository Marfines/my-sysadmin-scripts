FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

EXPOSE 8080

# script.sh пишет monitor.log в cwd = /var/www,
# http.server отдаёт содержимое этой директории по HTTP.
CMD ["/bin/bash", "-c", "/usr/local/bin/script.sh & exec python3 -m http.server 8080"]
