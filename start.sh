#!/bin/bash
# Editör, router ve nginx'i `koco` (uid 1000) olarak başlatır.
#
# compilerServer'lar BURADA DEĞİL: entrypoint.sh onları ayrı bir kullanıcıyla
# (`derleyici`, uid 1001; koco-deploy#37) derleyici-gozcusu.sh üzerinden
# başlatıyor. Bu betik koco olarak koştuğu için onları başka uid'e geçiremezdi.
#
# Sıra ÖNEMLİ ve beklemeli:
#  - compilerServer router'a WebSocket ile bağlanır; router'ı gözcü bekliyor.
#  - router kütüphane listesini editörden çeker ve refreshLibraries 3000s;
#    ilk denemeyi kaçırırsa ~50 dakika tekrar denemez.
set -eu

# Bu kolun yarattığı her dosya yalnız koco'ya (H2 veritabanı, günlükler,
# /tmp/router.conf, nginx geçicileri). Derleyici kullanıcısı bunları
# okuyamasın diye (#37); /data'daki eski dosyaları entrypoint.sh daraltıyor.
umask 077

# Türkçe adlı sınıflar (fiddle'lardaki nesne/sınıf adları dahil) UTF-8 yereli
# ister: POSIX yerelde JVM dosya adlarını yazamayıp InvalidPathException veriyor
# (Faz 0 PoC bulgusu, bkz. kojojs-dev/poc/faz0-yamali-derleyici/SONUC.md).
export LANG=C.UTF-8 LC_ALL=C.UTF-8

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

# Editörün /ornek/<yol> rotasının okuduğu örnek betikler (Dockerfile: stage/ornekler).
# application.conf'taki varsayılan (../kojojs-dev/ornekler) geliştirme klonu için.
export KOCO_ORNEKLER="${KOCO_ORNEKLER:-/app/ornekler}"

# Router ile compilerServer arasındaki /compiler WebSocket'inin ve router'ın
# /durum tanı ucunun anahtarı. entrypoint.sh üretiyor (verilmediyse) ve iki
# kola da veriyor: derleyici kolu ile bu kol AYNI değeri görmeli. Bu betiği
# entrypoint'siz koşturmak artık desteklenmiyor -- derleyiciler de gelmez.
: "${SCALAFIDDLE_SECRET:?entrypoint.sh üzerinden başlatılmalı (SCALAFIDDLE_SECRET yok)}"
export SCALAFIDDLE_SECRET

# Servisler arası konuşma konteyner içinde localhost üzerinden.
# (SCALAFIDDLE_ROUTER_URL'i yalnız compilerServer okuyor; entrypoint.sh veriyor.)
export SCALAFIDDLE_SOURCE_URL="http://localhost:9000/raw/"
export SCALAFIDDLE_EDIT_URL="http://localhost:9000/"

# DİKKAT: SCALAFIDDLE_LIBRARIES_URL'i SAKIN burada ayarlama.
# İki servis aynı değişkeni FARKLI formatlarda okuyor:
#   editör -> librariesURL, bir kaynak dosya adı bekliyor ("libraries.json")
#   router -> extLibs,      bir JSON haritası bekliyor ({"2.13": "..."})
# Global olarak ayarlanırsa editörün Librarian'ı None.get ile çöker,
# /libraries/2.13 boş [] döner ve compilerServer kütüphaneleri yükleyemez.
# Her ikisinin varsayılanı tek konteyner için zaten doğru.

# Yığın sınırları. DİKKAT: toplamları makinenin belleğini AŞMAMALI -- ilk
# sürümde 1200+512+384 = 2096m koymuştum, makine 2048m'di; üstüne JVM'lerin
# metaspace/stack/code cache'i gelince derleme sırasında 500'ler alıyorduk.
# 4 GB makinede: 2 derleyici x 1100m + editör 640m + router 384m = 3224m,
# JVM ek yükü icin ~870m pay.
ROUTER_OPTS="-J-Xmx384m"
EDITOR_OPTS="-J-Xmx640m"
# COMPILER_OPTS (öntanımlı "-J-Xmx1100m -J-Xss4m") entrypoint.sh'te: derleyici
# kolu oradan başlıyor. Yukarıdaki toplamı değiştiren, ikisine birden baksın.

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
# export: router'ın /bilgi ucu bunu okuyor (derleyiciSayisi). Export edilmezse
# uç boş gösteriyordu -- ölçüldü. Dışarıdan /saglik?enAz=N kuran taraf N'i
# buradan doğrulayabilsin diye görünür olması gerekiyor.
export COMPILER_INSTANCES

# Derleyici yenilenmesi (koco-deploy#17, 0. madde): router bir derleyiciyi bu
# kadar cevaptan sonra emekliye ayırıyor -- derleyici süreci bitiriyor, gözcü
# (derleyici-gozcusu.sh) TAZE bir JVM başlatıyor. Sebep ölçülmüş bir büyüme:
# derleme başına ~2 MB düzleşmeyen RSS artışı (konu yorumu, 110 derleme). Bu
# kurulumda yukarıdaki hesaba göre ~870m pay var; 200 cevapta derleyici başına
# ~200-400 MB büyüme o payın içinde kalıyor.
#
# ÖNTANIMLI KAPALI (0), çünkü bedeli ölçülünce beklenenden ağır çıktı. Taze
# derleyicinin İLK derlemesi soğuk (yerelde 18-30 sn, Fly'da 118 sn
# ölçülmüştü) ve seçim taze olanı hep sona bıraktığı için sıralı trafikte o
# derleyici hiç ısınmıyor. Eşi emekli olunca sıradaki istek doğrudan soğuk
# derleyiciye düşüyor. İmajda RECYCLE_AFTER=5 ile 40 sıralı derleme: her
# yenilenme turunda iki soğuk derleme (23-30 sn), biri `ask`'ın 30 sn'sini
# aşıp HTTP 500 aldı. Fly'da bu, her turda #17'nin belirtisini kısa süre geri
# getirirdi. Taze derleyici kendini ısıtmadan açılmamalı.
#
# Bu değer > 0 iken router, çıkan derleyicinin YENİDEN BAŞLATILACAĞINI
# varsayıyor -- yani gözcüsüz bir kurulumda açılmamalı. Aynı ayar, takılan
# (180 sn'den uzun Compiling) derleyiciye de Retire yollatıyor: takılmanın
# sebebi JVM'in kendisiyse aynı süreç geri gelmesin. Kapatmak için 0.
# (kojojs-core'un bu ayarı tanımayan eski bir sürümünde değişkenin etkisi yok.)
export SCALAFIDDLE_COMPILER_RECYCLE_AFTER="${SCALAFIDDLE_COMPILER_RECYCLE_AFTER:-0}"

# Coursier önbelleği (/data/coursier) yalnız compilerServer'ın; entrypoint.sh
# derleyici koluna veriyor ve dizin artık derleyici kullanıcısına ait.

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
# silhouette.conf'ta imzalama/şifreleme anahtarları "[changeme]" olarak sabit;
# JcaSigner/JcaCrypter bunları AES için kullanıyor, "[changeme]" hem güvensiz
# hem çalışmıyor. kojojs-editor bunları artık SILHOUETTE_KEY ortam
# değişkeninden okuyor (play.http.secret.key'i de APPLICATION_SECRET'tan).
# Değerler aşağıda YALNIZ editör sürecinin ortamına veriliyor (bkz. editör
# başlatma satırı ve koco-deploy#18).
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
# Editör Java 8 ile koşar (Play 2.6 + eski silhouette Java 21'de sorunlu);
# router ve compilerServer taban imajın Java 21'ini kullanır (2.13.18 orada
# doğrulandı). /opt/java8 Dockerfile'ın kurduğu mimariden bağımsız symlink
# (amd64/arm64 paket dizinleri farklı). Aşağıdaki alt kabukta export ediliyor,
# yani yalnız editöre gidiyor; router ve gözcü Java 21'de kalıyor.
#
# JAVACMD DEĞİL, JAVA_HOME: sbt-native-packager'ın bash betiği JAVACMD diye bir
# değişken tanımıyor (bkz. bin/server:105 get_java_cmd -- yalnız JAVA_HOME'a ve
# -java-home bayrağına bakıyor). JAVACMD sessizce yok sayılıyordu ve editör
# taban imajın Java 21'iyle açılıp şu hatayla ölüyordu:
#   InaccessibleObjectException: ... module java.base does not "opens java.lang"
# nginx ayakta kaldığı için sonuç 502'ydi, açık bir çökme değil.
#
# ANAHTARLAR -D İLE DEĞİL, ORTAMLA (koco-deploy#18): süreç komut satırı
# (/proc/<pid>/cmdline) herkese okunur ve `ps` çıktısında görünür; eskiden
# play.http.secret.key ve altı Silhouette anahtarı orada açık duruyordu.
# Ortam (/proc/<pid>/environ) yalnız sahibine okunur. Bu, aynı kullanıcıdaki
# süreçlere karşı koruma DEĞİL (onu #37 izliyor); kazara sızmayı kapatıyor.
#
# Alt kabukta `export`, `env A=... komut` DEĞİL: `env`'in kendi argv'si de
# `ps`'te görünür, exec edene kadar kısa bir an bile olsa. export kabuğun
# yerleşiği, hiçbir sürecin komut satırına düşmüyor. Alt kabuk, değerlerin
# bu betiğin ortamına -- dolayısıyla sonra başlayan router'a ve gözcü
# üzerinden derleyicilere -- sızmasını önlüyor. (Fly secret'ları zaten
# konteynerin ortamında; alt kabuk yalnız buradaki geri düşüş değerlerini
# ve SIL_KEY'in geçici üretilmişini editöre sınırlıyor.)
(
  export APPLICATION_SECRET="${APPLICATION_SECRET:-koco-yerel-gelistirme-anahtari-en-az-32-karakter}"
  export SILHOUETTE_KEY="$SIL_KEY"
  export JAVA_HOME=/opt/java8
  exec /app/editor/bin/server $EDITOR_OPTS \
    -Dsilhouette.authenticator.secureCookie=$SECURE_COOKIE \
    -Dsilhouette.csrfStateItemHandler.secureCookie=$SECURE_COOKIE \
    -Dh2.db.url="$H2_URL" \
    -Dhttp.port=9000
) &

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

# Sürüm damgası -> router'ın /bilgi ucu (kojojs-core#34). build.sh yazıyor,
# Dockerfile imaja alıyor. Dosya yoksa (damgasız imaj) değişkenler boş kalır ve
# uç boş alanlarla cevap verir -- açılışı düşürmesi için bir sebep yok.
if [ -r /app/SURUM.txt ]; then
  # `.` ile kaynak almıyoruz: dosya build.sh'in ürettiği veri, kabuk kodu değil.
  # Bir gün içeriği beklenmedik bir şey olursa onu çalıştırmayalım.
  KOCO_SURUM_CORE=$(sed -n 's/^core=//p'   /app/SURUM.txt)
  KOCO_SURUM_DEV=$(sed -n 's/^dev=//p'     /app/SURUM.txt)
  KOCO_SURUM_EDITOR=$(sed -n 's/^editor=//p' /app/SURUM.txt)
  KOCO_SURUM_TARIH=$(sed -n 's/^tarih=//p' /app/SURUM.txt)
  export KOCO_SURUM_CORE KOCO_SURUM_DEV KOCO_SURUM_EDITOR KOCO_SURUM_TARIH
  echo "[koco] sürüm damgası: core=$KOCO_SURUM_CORE dev=$KOCO_SURUM_DEV editor=$KOCO_SURUM_EDITOR ($KOCO_SURUM_TARIH)"
else
  echo "[koco] sürüm damgası yok (/app/SURUM.txt); /bilgi boş alanlarla cevap verecek."
fi

echo "[koco] router başlıyor..."
/app/router/bin/scalafiddle-router $ROUTER_OPTS -Dconfig.file=/tmp/router.conf &

wait_for_port 8880 "router" 180

# Derleyicileri GÖZCÜ başlatıyor ve ölürlerse geri getiriyor
# (derleyici-gozcusu.sh; koco-deploy#17, 3. madde) -- ama artık buradan değil,
# entrypoint.sh'ten, `derleyici` kullanıcısıyla (#37). Gözcü router'ın portu
# açılana kadar bekliyor, yani yukarıdaki sıra korunuyor.
#
# nice (Scala.js optimizer'ı tek paylaşımlı çekirdeği doyuruyor; önceliği
# düşmezse nginx sağlık kontrolüne cevap veremiyor) ve süreç başına kütüphane
# önbelleği (/tmp/extlibs-$i) gözcünün içinde.

echo "[koco] nginx 7860'ta dinliyor"
exec nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
