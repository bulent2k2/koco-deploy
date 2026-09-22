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
# /durum tanı ucunun anahtarı. reference.conf'taki ÖNTANIMLI DEĞER "secret" ve
# yukarı akış ScalaFiddle deposunda herkese açık; ayarlanmazsa iki kapı da
# fiilen korumasız kalıyor. Bugüne kadar ayarlanmıyordu.
#
# Rastgele üretmek burada SORUN DEĞİL (SILHOUETTE_KEY'den farkı bu): anahtarı
# okuyan iki süreç de bu betikten, aynı açılışta başlıyor, yani değer her
# yeniden başlatmada değişse bile ikisi hep aynısını görüyor. Kullanıcıya
# yansıyan bir durumu yok -- düşecek oturum, bozulacak çerez yok.
#
# Gözcünün yeniden başlattığı compilerServer da bunu miras alıyor (export).
if [ -z "${SCALAFIDDLE_SECRET:-}" ]; then
  # Komşudaki SIL_KEY satırından farklı biçim, bilerek: `base64 | tr -dc` önce
  # üretip sonra `+/` karakterlerini attığı için DEĞİŞKEN uzunluk veriyor
  # (ölçüldü: 32 yerine 31 çıktı). Böylesi tam 32 karakter garanti ediyor.
  #
  # pipefail EKLENİRSE BURAYA BAK: `head` boruyu erken kapatınca `tr` SIGPIPE
  # ile ölüyor. Bugün sorun yok, çünkü bu betikte yalnız `set -eu` var ve boru
  # hattının durumu `head`'inki (0). Biri `set -o pipefail` eklerse (yedekle.sh
  # o deseni kullanıyor) bu atama betiği AÇILIŞTA sessizce düşürür.
  #
  # DIŞARIDAN /durum yoklanacaksa rastgele değer işe yaramaz: kalıcı bir
  # anahtar verin (flyctl secrets set SCALAFIDDLE_SECRET=...). Ayrıntı README.
  SCALAFIDDLE_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
  echo "[koco] SCALAFIDDLE_SECRET verilmedi, bu açılış için rastgele üretildi."
fi
export SCALAFIDDLE_SECRET

# Servisler arası konuşma konteyner içinde localhost üzerinden
export SCALAFIDDLE_ROUTER_URL="ws://localhost:8880/compiler"
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
# Editör Java 8 ile koşar (Play 2.6 + eski silhouette Java 21'de sorunlu);
# router ve compilerServer taban imajın Java 21'ini kullanır (2.13.18 orada
# doğrulandı). /opt/java8 Dockerfile'ın kurduğu mimariden bağımsız symlink
# (amd64/arm64 paket dizinleri farklı); `env` tek komut olduğu için araya
# satır girse de önek kaybolmaz.
#
# JAVACMD DEĞİL, JAVA_HOME: sbt-native-packager'ın bash betiği JAVACMD diye bir
# değişken tanımıyor (bkz. bin/server:105 get_java_cmd -- yalnız JAVA_HOME'a ve
# -java-home bayrağına bakıyor). JAVACMD sessizce yok sayılıyordu ve editör
# taban imajın Java 21'iyle açılıp şu hatayla ölüyordu:
#   InaccessibleObjectException: ... module java.base does not "opens java.lang"
# nginx ayakta kaldığı için sonuç 502'ydi, açık bir çökme değil.
env JAVA_HOME=/opt/java8 \
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

# Derleyicileri artık GÖZCÜ başlatıyor ve ölürlerse geri getiriyor
# (derleyici-gozcusu.sh; koco-deploy#17, 3. madde). Eskiden burada düz bir
# döngü vardı ve ölen süreç GERİ GELMİYORDU: kapasite kalıcı olarak azalıyor,
# ikisi birden gidince sunucu her derlemeyi "Sunucu şu anda çok yoğun" ile
# reddediyordu. Ölçüldü (gerçek ikililerle, /durum ucundan): kill -9 sonrası
# kapasite 1 -> 0 -> 1, üç saniyede geri geliyor.
#
# GÖZCÜ BURADA, exec'ten ÖNCE arka plana alınmalı: aşağıdaki `exec nginx`
# kabuğu devralıyor, yani bu noktadan sonra betiğin kendisi bir şey
# bekleyemez. Gözcü kendi döngüsünde yaşamaya devam ediyor.
#
# nice: Scala.js optimizer'ı tek paylaşımlı çekirdeği doyuruyor (ölçüldü: bir
# derleme 118 sn). Önceliği düşürmezsek nginx sağlık kontrolüne cevap veremiyor,
# Fly makineyi derlemenin ORTASINDA öldürüyor ve sonsuz yeniden başlatma oluyor.
# Değeri gözcünün öntanımlısı (10); değiştirmek gerekirse KOCO_GOZCU_NICE.
#
# Her sürece kendi kütüphane önbelleği (/tmp/extlibs-$i) gözcünün içinde
# veriliyor: aynı dizine iki süreç yazarsa birbirini bozabilir. Coursier
# önbelleği paylaşılabilir (kendi kilidi var).
echo "[koco] compilerServer başlıyor (nice 10, $COMPILER_INSTANCES süreç, gözcülü)..."
COMPILER_INSTANCES="$COMPILER_INSTANCES" COMPILER_OPTS="$COMPILER_OPTS" \
  /app/derleyici-gozcusu.sh &

echo "[koco] nginx 7860'ta dinliyor"
exec nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
