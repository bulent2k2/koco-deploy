# Koco (KojoJS) — router + compilerServer + editör, tek konteynerde.
#
# NOT: Kaynaktan derlemiyoruz. Her iki repodaki project/plugins.sbt hâlâ
# http://repo.typesafe.com (düz HTTP, ölü) çözümleyicisini kullanıyor; soğuk
# önbellekle Docker içinde bağımlılık çözümlemesi çöker. Bu yüzden paketleme
# yerelde `./build.sh` ile yapılır, imaj yalnızca çıktıyı kopyalar.
FROM eclipse-temurin:8-jre-jammy

RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx ca-certificates \
 && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

# HF Spaces konteyneri root olmayan kullanıcıyla çalışır
RUN useradd -m -u 1000 koco

COPY nginx.conf        /etc/nginx/nginx.conf
COPY proxy_common.conf /etc/nginx/proxy_common.conf
COPY start.sh          /app/start.sh
COPY entrypoint.sh     /app/entrypoint.sh
COPY schema-h2.sql     /app/schema-h2.sql

COPY stage/router   /app/router
COPY stage/compiler /app/compiler
COPY stage/editor   /app/editor

RUN chmod +x /app/start.sh /app/router/bin/* /app/compiler/bin/* /app/editor/bin/* \
 && mkdir -p /var/lib/nginx /var/log/nginx /tmp/nginx-client /app/logs \
 && chown -R koco:koco /app /var/lib/nginx /var/log/nginx

# logback ./logs/application.log'a yazmak istiyor; CWD yazılabilir olmalı
WORKDIR /app

# setpriv HOME'u DEĞİŞTİRMİYOR. USER koco kullanırken Docker bunu kendisi
# ayarlıyordu; artık root'tan düştüğümüz için elle vermek şart, yoksa coursier
# /root/.cache'e yazmaya çalışıp "Permission denied" alıyor ve derleyici ölüyor.
ENV HOME=/home/koco

# USER koco YOK: entrypoint root olarak başlayıp volume'ü chown etmeli, sonra
# setpriv ile uid 1000'e düşüyor. JVM'lerin hiçbiri root çalışmıyor.
EXPOSE 7860
CMD ["/app/entrypoint.sh"]
