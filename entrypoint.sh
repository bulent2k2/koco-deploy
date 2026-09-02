#!/bin/bash
# root olarak çalışır, SADECE volume'ü hazırlar, sonra ayrıcalığı bırakır.
#
# Fly volume'leri root'a ait olarak bağlanıyor; JVM'ler koco (uid 1000) olarak
# çalıştığı için H2 veritabanı dosyasını oraya yazamaz. İmajda /data yaratmak
# yetmiyor: bağlama (mount) onu gölgeliyor, yani chown bağlamadan SONRA olmalı.
set -eu

mkdir -p /data /data/coursier
chown -R koco:koco /data

# nginx access_log /dev/stdout'a yazıyor; o boru root'a ait ve uid düştükten
# sonra AÇILAMIYOR ("Permission denied"), nginx de sessizce çıkıyor.
chmod 0666 /proc/self/fd/1 /proc/self/fd/2 2>/dev/null || true

exec setpriv --reuid=1000 --regid=1000 --clear-groups /app/start.sh
