#!/bin/bash
# Üç JVM servisi + nginx'i tek konteynerde başlatır.
#
# Sıra ÖNEMLİ ve beklemeli:
#  - compilerServer router'a WebSocket ile bağlanır; Manager.connect() ilk
#    denemede başarısız olursa YENİDEN ZAMANLAMIYOR (yalnızca CompilerTerminated
#    üzerine), o yüzden router'ı beklemek şart.
#  - router kütüphane listesini editörden çeker ve refreshLibraries 3000s;
#    ilk denemeyi kaçırırsa ~50 dakika tekrar denemez.
set -eu

# Genel adres barındırıcıya göre değişiyor. Sırayla:
#   PUBLIC_URL    -> elle geçersiz kılma (özel alan adı vb.)
#   SPACE_HOST    -> Hugging Face Spaces
#   FLY_APP_NAME  -> Fly.io
#   yoksa         -> yerel test
if [ -n "${PUBLIC_URL:-}" ]; then
  :
elif [ -n "${SPACE_HOST:-}" ]; then
  PUBLIC_URL="https://$SPACE_HOST"
elif [ -n "${FLY_APP_NAME:-}" ]; then
  PUBLIC_URL="https://$FLY_APP_NAME.fly.dev"
else
  PUBLIC_URL="http://localhost:7860"
fi
echo "[koco] genel adres: $PUBLIC_URL"

# Tarayıcı hem editöre hem router'a AYNI origin üzerinden gidiyor (nginx ayırıyor),
# bu yüzden compilerURL de aynı genel adres olmalı. Aynı origin => CORS gerekmez.
export SCALAFIDDLE_URL="$PUBLIC_URL"
export SCALAFIDDLE_COMPILER_URL="$PUBLIC_URL"

# GitHub girişinin geri dönüş adresi (silhouette.conf callbackBaseURL).
# Elle ayarlanmadıysa genel adresten türet; GitHub OAuth App'teki
# "Authorization callback URL" bununla AYNI olmalı: <adres>/authenticate/github
export SCALAFIDDLE_AUTH_URL="${SCALAFIDDLE_AUTH_URL:-$PUBLIC_URL/authenticate}"

# Servisler arası konuşma konteyner içinde localhost üzerinden
export SCALAFIDDLE_ROUTER_URL="ws://localhost:8880/compiler"
export SCALAFIDDLE_SOURCE_URL="http://localhost:9000/raw/"
export SCALAFIDDLE_EDIT_URL="http://localhost:9000/"

# DİKKAT: SCALAFIDDLE_LIBRARIES_URL'i SAKIN burada ayarlama.
# İki servis aynı değişkeni FARKLI formatlarda okuyor:
#   editör -> librariesURL, bir kaynak dosya adı bekliyor ("libraries.json")
#   router -> extLibs,      bir JSON haritası bekliyor ({"2.12": "..."})
# Global olarak ayarlanırsa editörün Librarian'ı None.get ile çöker,
# /libraries/2.12 boş [] döner ve compilerServer kütüphaneleri yükleyemez.
# Her ikisinin varsayılanı tek konteyner için zaten doğru.

# Yığın sınırları. DİKKAT: toplamları makinenin belleğini AŞMAMALI -- ilk
# sürümde 1200+512+384 = 2096m koymuştum, makine 2048m'di; üstüne JVM'lerin
# metaspace/stack/code cache'i gelince derleme sırasında 500'ler alıyorduk.
# 4 GB makinede: 2 derleyici x 1100m + editör 640m + router 384m = 3224m,
# JVM ek yükü icin ~870m pay.
ROUTER_OPTS="-J-Xmx384m"
COMPILER_OPTS="-J-Xmx1100m -J-Xss4m"
EDITOR_OPTS="-J-Xmx640m"

# Eşzamanlı kullanıcı sayısı.
#
# TUZAK: reference.conf'taki akka.actor.deployment./compilerRouter
# (nr-of-instances = 1) ÖLÜ YAPILANDIRMA -- Scala kodunda hiçbir yerde
# kullanılmıyor, ScalaFiddle'dan kalma. Onu değiştirmek hiçbir şey yapmıyor.
#
# Gerçek mekanizma: her compilerServer SÜRECİ router'a bir WebSocket açıyor ve
# CompilerManager'a BİR derleyici kaydediyor. Hepsi meşgulse router kuyruğa
# almıyor, "No suitable compiler available" ile REDDEDİYOR. Yani eşzamanlı N
# kullanıcı için N süreç gerekiyor.
COMPILER_INSTANCES="${COMPILER_INSTANCES:-2}"

# Coursier önbelleğini KALICI diske koy. Aksi halde her yeniden başlatmada
# jar'lar yeniden indirilip açılıyor ve ilk derleme 30-60 sn gecikiyor.
# Volume'de tutunca bu bedel ömürde bir kez ödeniyor.
export COURSIER_CACHE="${COURSIER_CACHE:-/data/coursier}"

mkdir -p /tmp/nginx-client /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi

# $1 port, $2 ad, $3 azami saniye
wait_for_port() {
  local port=$1 name=$2 limit=${3:-90} n=0
  while ! (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; do
    n=$((n+1))
    if [ "$n" -ge "$limit" ]; then
      # Ölümcül DEĞİL. Erken sürümde 90 sn sınırı Fly'ın paylaşımlı çekirdeğinde
      # dolup script'i öldürüyor, makine sonsuz yeniden başlama döngüsüne
      # giriyordu -- oysa editör tam açılmak üzereydi. Uyar ve devam et.
      echo "[koco] UYARI: $name ($port) $limit saniyede açılmadı, yine de devam ediliyor" >&2
      return 0
    fi
    sleep 1
  done
  exec 3<&- 2>/dev/null || true
  echo "[koco] $name hazır ($port, ${n}s)"
}

# --- Veritabanı şeması ---
# kojojs-editor'ün tables.sql'i bir PostgreSQL KURULUM betiği (CREATE ROLE /
# CREATE DATABASE / GRANT) ve elle çalıştırılmak için yazılmış; Play evolutions
# da kurulu değil. Sonuç: bellek-içi H2 boş açılıyor ve GitHub girişi
# "Table \"user\" not found" ile patlıyor.
# H2'nin INIT=RUNSCRIPT'i ile bağlantı anında şemayı kuruyoruz.
#
# NOT: hâlâ BELLEK-İÇİ. Makine yeniden başlarsa kaydedilen yazılımcıklar ve
# kullanıcılar gider. Kalıcılık için SCALAFIDDLE_SQL_URL ile gerçek Postgres.
# DOSYA kipi: /data bir Fly volume, yani yeniden başlatmalarda kalıcı.
# INIT=RUNSCRIPT her bağlantıda çalışıyor; schema-h2.sql CREATE TABLE IF NOT
# EXISTS kullandığı için bu idempotent.
H2_URL="${H2_URL:-jdbc:h2:/data/koco;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;INIT=RUNSCRIPT FROM '/app/schema-h2.sql'}"

# --- Silhouette (GitHub girişi) ---
# silhouette.conf'ta imzalama/şifreleme anahtarları "[changeme]" olarak SABİT ve
# env override'ları YOK. JcaSigner/JcaCrypter bunları AES için kullanıyor; 10
# karakterlik "[changeme]" hem güvensiz hem çalışmıyor. Typesafe Config'te
# sistem özellikleri (-D) en yüksek önceliğe sahip olduğu için oradan veriyoruz.
SIL_KEY="${SILHOUETTE_KEY:-}"
if [ -z "$SIL_KEY" ]; then
  SIL_KEY=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-32)
  echo "[koco] UYARI: SILHOUETTE_KEY yok, geçici anahtar üretildi."
  echo "[koco]         Yeniden başlatınca giriş yapmış herkes düşer."
fi

# HTTPS'te çerez Secure işaretli olmalı; yerelde (http) olmamalı, yoksa hiç kurulmaz.
case "$PUBLIC_URL" in
  https://*) SECURE_COOKIE=true ;;
  *)         SECURE_COOKIE=false ;;
esac

if [ -n "${GITHUB_CLIENT_ID:-}" ]; then
  echo "[koco] editör başlıyor... (GitHub girişi: yapılandırıldı)"
else
  echo "[koco] editör başlıyor... (GitHub girişi: YAPILANDIRILMADI — GITHUB_CLIENT_ID yok)"
fi
/app/editor/bin/server $EDITOR_OPTS \
  -Dplay.http.secret.key="${APPLICATION_SECRET:-koco-yerel-gelistirme-anahtari-en-az-32-karakter}" \
  -Dsilhouette.authenticator.signer.key="$SIL_KEY" \
  -Dsilhouette.authenticator.crypter.key="$SIL_KEY" \
  -Dsilhouette.socialStateHandler.signer.key="$SIL_KEY" \
  -Dsilhouette.csrfStateItemHandler.signer.key="$SIL_KEY" \
  -Dsilhouette.oauth1TokenSecretProvider.cookie.signer.key="$SIL_KEY" \
  -Dsilhouette.oauth1TokenSecretProvider.crypter.key="$SIL_KEY" \
  -Dsilhouette.authenticator.secureCookie=$SECURE_COOKIE \
  -Dsilhouette.csrfStateItemHandler.secureCookie=$SECURE_COOKIE \
  -Dh2.db.url="$H2_URL" \
  -Dhttp.port=9000 &

wait_for_port 9000 "editör" 300   # Fly shared-cpu-1x: yerelde 6 sn, orada 100+ sn

# Router'ın corsOrigins listesi reference.conf'ta SABİT ve ortam değişkeniyle
# değiştirilemiyor. Tarayıcı same-origin POST'ta bile Origin başlığı gönderdiği
# için (curl göndermez -- bu yüzden curl testi yanıltıcıydı), genel adresimiz
# listede yoksa akka-http-cors isteği reddediyor:
#   "CORS: invalid origin 'http://localhost:7860'"
# Config ConfigFactory.load() kullandığından -Dconfig.file ile geçersiz kılıyoruz.
cat > /tmp/router.conf <<CONF
fiddle {
  corsOrigins = ["$PUBLIC_URL", "http://localhost:7860"]
}
CONF

echo "[koco] router başlıyor..."
/app/router/bin/scalafiddle-router $ROUTER_OPTS -Dconfig.file=/tmp/router.conf &

wait_for_port 8880 "router" 180

# nice: Scala.js optimizer'ı tek paylaşımlı çekirdeği doyuruyor (ölçüldü: bir
# derleme 118 sn). Önceliği düşürmezsek nginx sağlık kontrolüne cevap veremiyor,
# Fly makineyi derlemenin ORTASINDA öldürüyor ve sonsuz yeniden başlatma oluyor.
echo "[koco] compilerServer başlıyor (nice 10, $COMPILER_INSTANCES süreç)..."
i=1
while [ "$i" -le "$COMPILER_INSTANCES" ]; do
  # Her sürece kendi kütüphane önbelleği: aynı dizine iki süreç yazarsa
  # birbirini bozabilir. Coursier önbelleği paylaşılabilir (kendi kilidi var).
  SCALAFIDDLE_LIBCACHE="/tmp/extlibs-$i" \
    nice -n 10 /app/compiler/bin/scalafiddle-core $COMPILER_OPTS &
  i=$((i + 1))
done

echo "[koco] nginx 7860'ta dinliyor"
exec nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
