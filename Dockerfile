# Koco (KojoJS) — router + compilerServer + editör, tek konteynerde.
#
# NOT: Kaynaktan derlemiyoruz. Her iki repodaki project/plugins.sbt hâlâ
# http://repo.typesafe.com (düz HTTP, ölü) çözümleyicisini kullanıyor; soğuk
# önbellekle Docker içinde bağımlılık çözümlemesi çöker. Bu yüzden paketleme
# yerelde `./build.sh` ile yapılır, imaj yalnızca çıktıyı kopyalar.
# Faz 3/4 (bkz. kojojs-dev/oneri-scala-2.13.md): router + compilerServer artık
# Scala 2.13.18 / Scala.js 1.20 ve Java 21 üzerinde doğrulandı; editör (Play
# 2.6, sbt 0.13 ile derleniyor) hâlâ Java 8 istiyor. İki JRE bir arada:
# taban imaj 21, editör için apt'ten openjdk-8 (start.sh JAVACMD ile seçiyor).
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx ca-certificates openjdk-8-jre-headless \
 && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

# Java 8'in paket dizini mimariye göre değişir (java-8-openjdk-amd64 / -arm64).
# start.sh'ın kullandığı sabit /opt/java8 symlink'ini burada kur: yol yanlışsa
# `java -version` imaj derlemesinde patlar, çalışma zamanına sarkmaz.
RUN ln -s /usr/lib/jvm/java-8-openjdk-* /opt/java8 \
 && /opt/java8/bin/java -version

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
# Örnek betikler (kojojs-dev/ornekler); editör /ornek/<yol> ile sunar (KOCO_ORNEKLER, start.sh)
COPY stage/ornekler /app/ornekler

RUN chmod +x /app/start.sh /app/router/bin/* /app/compiler/bin/* /app/editor/bin/* \
 && mkdir -p /var/lib/nginx /var/log/nginx /app/logs \
 && chown -R koco:koco /app /var/lib/nginx /var/log/nginx
# /tmp/nginx-* burada YARATILMAZ: start.sh çalışma anında koco olarak yaratıyor.
# Önceden root'la yaratılan /tmp/nginx-client, koco kullanıcısıyla koşan nginx'e
# yazılamaz kalıyordu; bellek tamponunu (~10 KB) aşan her /compile gövdesi diske
# yazılamayıp nginx 500 veriyordu -- canlıda büyük betikler derlenemiyordu.

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
