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
#  - kendi ev dizinine ve /tmp'ye yazabiliyor (compilerServer'ın açılmış jar
#    önbelleği /tmp/extlibs-N, bkz. derleyici-gozcusu.sh). Oraya konan bir şey
#    aynı açılışta yeniden başlatılan derleyicilere geçer; makine yeniden
#    başlayınca imajdan gelen temiz kök dosya sistemine döner. Kalıcı
#    yazabildiği bir yer ARTIK YOK: kütüphane
#    önbelleği imajda ve salt okunur (koco-deploy#51; eskiden volume'deki
#    /data/coursier'dı ve zehirli bir jar yeniden başlatmadan sağ çıkardı).
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
# /data YALNIZ koco'nun (H2 veritabanı), 700: derleyici içine giremiyor.
# Kütüphane önbelleği artık imajda (/opt/coursier, koco-deploy#51).
#
# Eski imajların /data/coursier'ı (önce koco'nun, #47'den sonra derleyicinin):
# derleyicinin yazabildiği her şey güvenilmez, o yüzden sahiplik değiştirmek
# yerine SİLİNİYOR. `rm -rf` sembolik bağları izlemiyor; sabit bağın yalnız
# bu adını siliyor, işaret ettiği dosyaya dokunmuyor. Derleyici henüz
# başlamadı, yani silerken yarışacak kimse yok. /data 700 olduğundan derleyici
# onu yeniden yaratamaz: pratikte bir kez çalışır.
rm -rf /data/coursier
mkdir -p /data
chown koco:koco /data
chmod 700 /data
# Eski imajlar 644 bırakmıştı; yenileri start.sh'in umask 077'si ile doğuyor.
find /data -mindepth 1 -maxdepth 1 -exec chown -R koco:koco {} + -exec chmod -R go-rwx {} +
# Sigorta: sahibi olmadığı dosyaya sabit bağ açmayı çekirdek düzeyinde kapat
# (derleyici /tmp gibi ortak bir yerde koco'nun bir dosyasına bağ açıp onu
# kendine kalıcılaştıramasın). systemd bunu 1 yapıyor ama Fly'ın init'i
# systemd değil; yazılamazsa (izin yok, salt okunur /proc) zararsız.
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
  # Kütüphane önbelleği imajda, root'a ait ve salt okunur (koco-deploy#51;
  # build.sh dolduruyor). ÇEVRİMDIŞI: eksik bir jar indirilmeye çalışılmaz,
  # derleyici "not found" ile Ready olamaz; /saglik?enAz=N bunu kojojs-core#56
  # ile görüyor (öncesinde düşen derleyicinin bağlantısı kayıtlı kalıyordu) -- sessizce
  # internetten çekip yazılamayan önbellekte kilit hatasıyla düşmekten iyi.
  # (Çevrimiçi kipte coursier salt okunur önbellekte .structure.lock
  # yaratamayıp düşüyor; ölçüldü.)
  export COURSIER_CACHE=/opt/coursier
  export COURSIER_MODE=offline
  # LibraryManager önce ivy2Local'a (~/.ivy2/local) bakıyor ve bu dosya deposu
  # ÇEVRİMDIŞI kipte de okunuyor. ~ derleyicinin yazabildiği ev dizini: oraya
  # konan bir jar imajdakinin önüne geçerdi. Yok olan ve yaratılamayan bir
  # yola çevir (/ root'un).
  export JAVA_OPTS="-Divy.home=/nonexistent"
  cd /home/derleyici
  # --no-new-privs: derleme yolundan çalışan kod imajdaki setuid ikililerle
  # (su, passwd, mount...) yetki kazanamasın. Çocuklara miras kalıyor, yani
  # gözcünün yeniden başlattığı derleyiciler de kapsanıyor.
  exec setpriv --reuid=1001 --regid=1001 --clear-groups --no-new-privs /app/derleyici-gozcusu.sh
) &

# --- Ana kol (uid 1000) ---
exec setpriv --reuid=1000 --regid=1000 --clear-groups /app/start.sh
