#!/bin/bash
# root olarak çalışır: volume'ü hazırlar, iki kolu AYRI kullanıcılarla başlatır
# ve ayrıcalığı bırakır. Kendisi hiçbir JVM'i root olarak koşturmaz.
#
#   derleyici kolu (uid 1001 `derleyici`): derleyici-gozcusu.sh -> compilerServer'lar
#   ana kol        (uid 1000 `koco`):      start.sh -> editör, router, nginx
#
# NEDEN İKİ KULLANICI (koco-deploy#37): compilerServer kullanıcıdan gelen
# rastgele Scala kaynağını derliyor ve kum havuzu yok. Aynı uid'de koşunca
# derleme yolundan çalıştırılabilecek bir kod editörün ortamını
# (/proc/<pid>/environ: APPLICATION_SECRET, SILHOUETTE_KEY) okuyabilir ve H2
# veritabanını (/data/koco*) okuyup yazabilirdi. Ayrı uid ikisini de kapatıyor.
# (Bu bir istismarın bulunduğu anlamına gelmiyor; bkz. #18 ve #37.)
#
# KAPATMADIKLARI (tehdit modeli, #47 incelemesi): ele geçirilmiş bir derleyici
#  - başka kullanıcıların DERLEME ÇIKTISINI üretmeye devam ediyor; editörle aynı
#    kökenden (same-origin) tarayıcıya kötü JS verebilir. Kullanıcı ayrımı
#    bunu kapatamaz.
#  - /data/coursier'a (volume, kalıcı) yazabiliyor: zehirli bir jar yeniden
#    başlatmadan ve JVM yenilenmesinden sağ çıkar. Önbellek bütünlüğü ayrı iş.
#
# NEDEN BURADA: start.sh zaten `koco` olarak koşuyor, kendi çocuklarını başka
# bir uid'e geçiremez. Kullanıcı değiştirmek root ister ve root yalnız burada.
set -eu

# Türkçe adlı sınıflar UTF-8 yereli ister (bkz. start.sh); iki kol da miras alsın.
export LANG=C.UTF-8 LC_ALL=C.UTF-8

# --- Volume ---
# Fly volume'leri root'a ait olarak bağlanıyor. İmajda /data yaratmak yetmiyor:
# bağlama (mount) onu gölgeliyor, yani chown bağlamadan SONRA olmalı.
#
# /data koco'nun (H2 veritabanı); /data/coursier derleyicinin (kütüphane
# önbelleği; onu yalnız compilerServer kullanıyor). /data 711: derleyici
# içinden geçip coursier'a ulaşabiliyor ama dizini LİSTELEYEMİYOR. Geçmek
# dosya adını bilene okuma izni vermesin diye koco'nun dosyaları da go-rwx
# (eski imajlar 644 bırakmıştı; yenileri start.sh'in umask 077'si ile doğuyor).
mkdir -p /data /data/coursier
chown koco:koco /data
chmod 711 /data
find /data -mindepth 1 -maxdepth 1 ! -name coursier -exec chown -R koco:koco {} + -exec chmod -R go-rwx {} +
# /data/coursier GÜVENİLMEYEN kullanıcının yazabildiği bir dizin: root orada
# her açılışta özyinelemeli iş YAPMAMALI. Yapsaydı, derleme yolundan açılmış
# bir sabit bağ (`ln /data/koco.mv.db /data/coursier/x`; protected_hardlinks=0
# ise okuyamadığı dosyaya da açılabiliyor) bir sonraki açılışta `chown -R`
# ile veritabanını derleyiciye geçirirdi: veritabanı ona açılır, editöre
# kapanırdı. Bu yüzden sahiplik göçü (eski imajların koco'ya ait önbelleği)
# YALNIZ BİR KEZ, dizin henüz derleyicinin değilken; sonrasında derleyicinin
# yarattığı her şey zaten onun. `chmod` özyinelemesiz, yalnız dizinin kendisi.
if [ "$(stat -c %u /data/coursier)" != 1001 ]; then
  chown -R derleyici:derleyici /data/coursier
fi
chmod 700 /data/coursier
# Ek sigorta: sahibi olmadığı dosyaya sabit bağ açmayı çekirdek düzeyinde
# kapat. systemd bunu 1 yapıyor ama Fly'ın init'i systemd değil; yazılamazsa
# (izin yok, salt okunur /proc) zararsız, yukarıdaki kural yine koruyor.
sysctl -qw fs.protected_hardlinks=1 2>/dev/null || true

# nginx access_log /dev/stdout'a yazıyor; o boru root'a ait ve uid düştükten
# sonra AÇILAMIYOR ("Permission denied"), nginx de sessizce çıkıyor. İki kolun
# da günlüğü aynı borudan Fly'a gidiyor.
chmod 0666 /proc/self/fd/1 /proc/self/fd/2 2>/dev/null || true

# --- İki kolun paylaştığı ayarlar ---
# Router ile compilerServer arasındaki /compiler WebSocket'inin ve router'ın
# /durum tanı ucunun anahtarı. İki kol da AYNISINI görmeli, o yüzden artık
# burada, dallanmadan önce üretiliyor (eskiden start.sh'teydi). reference.conf'taki
# öntanımlı "secret" yukarı akışta herkese açık; ayarlanmazsa kapı korumasız.
#
# Rastgele üretmek sorun değil: anahtarı okuyan iki süreç de bu açılıştan.
# DIŞARIDAN /durum yoklanacaksa kalıcı verin (flyctl secrets set SCALAFIDDLE_SECRET=...).
#
# `head` boruyu erken kapatınca `tr` SIGPIPE ile ölüyor; bu betikte pipefail
# YOK, boru hattının durumu `head`'inki (0). pipefail eklenirse buraya bakın.
# Tam 32 karakter: `base64 | tr -dc` değişken uzunluk veriyordu (ölçüldü).
if [ -z "${SCALAFIDDLE_SECRET:-}" ]; then
  SCALAFIDDLE_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
  echo "[koco] SCALAFIDDLE_SECRET verilmedi, bu açılış için rastgele üretildi."
fi
export SCALAFIDDLE_SECRET

# Eşzamanlı derleyici sayısı ve yığınları. start.sh de okuyor (router'ın /bilgi
# ucu derleyiciSayisi; bellek hesabı orada), o yüzden iki kola da export.
# Eşzamanlılığın gerçek mekanizması ve bellek toplamı: start.sh.
export COMPILER_INSTANCES="${COMPILER_INSTANCES:-2}"
export COMPILER_OPTS="${COMPILER_OPTS:--J-Xmx1100m -J-Xss4m}"

# --- Derleyici kolu (uid 1001) ---
# Ortam BEYAZ LİSTEYLE temizleniyor: kök ortamında Fly secret'ları var
# (APPLICATION_SECRET, SILHOUETTE_KEY, GITHUB_CLIENT_SECRET...) ve derleyicinin
# hiçbirine ihtiyacı yok. `env -i A=... komut` DEĞİL: env'in argv'si `ps`'te
# görünür (SCALAFIDDLE_SECRET dahil); `unset` kabuk yerleşiği, hiçbir yere düşmüyor.
#
# Gözcü router'ı kendisi bekliyor (derleyici-gozcusu.sh), yani iki kolun sırası
# burada önemli değil. Kolun ömrü: gözcü döngüsü; kol ölürse derleyiciler geri
# gelmez -- onu /saglik?enAz=N denetimi yakalar (fly.toml).
(
  for v in $(compgen -e); do
    case "$v" in
      PATH|LANG|LC_ALL|TZ|JAVA_HOME) ;;
      SCALAFIDDLE_SECRET|SCALAFIDDLE_COMPILER_CACHE) ;;
      COMPILER_INSTANCES|COMPILER_OPTS|KOCO_GOZCU_*|KOCO_DERLEYICI_KOMUTU) ;;
      *) unset "$v" 2>/dev/null || true ;;   # salt okunur olan varsa kol düşmesin
    esac
  done
  export HOME=/home/derleyici
  export SCALAFIDDLE_ROUTER_URL="ws://localhost:8880/compiler"
  # Kalıcı disk: yoksa her yeniden başlatmada jar'lar yeniden indirilir ve ilk
  # derleme 30-60 sn gecikir. Yalnız compilerServer kullanıyor.
  export COURSIER_CACHE=/data/coursier
  cd /home/derleyici
  # --no-new-privs: derleme yolundan çalışan kod imajdaki setuid ikililerle
  # (su, passwd, mount...) yetki kazanamasın. Çocuklara miras kalıyor, yani
  # gözcünün yeniden başlattığı derleyiciler de kapsanıyor.
  exec setpriv --reuid=1001 --regid=1001 --clear-groups --no-new-privs /app/derleyici-gozcusu.sh
) &

# --- Ana kol (uid 1000) ---
exec setpriv --reuid=1000 --regid=1000 --clear-groups /app/start.sh
