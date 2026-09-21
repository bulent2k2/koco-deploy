#!/bin/bash
# yedekle.sh -- canlı H2 veritabanının KUTU DIŞI, doğrulanmış, şifreli kopyası.
#
#   ./yedekle.sh                      # ~/koco-yedek altına
#   KOCO_YEDEK_DIZIN=/yol ./yedekle.sh
#   KOCO_YEDEK_PAROLA_DOSYASI=~/.koco-yedek-parola ./yedekle.sh   # etkileşimsiz (cron)
#
# NEDEN: Fly'ın günlük anlık görüntüsü var ve geri yüklenebilirliği 2026-09-17'de
# ÖLÇÜLDÜ (görüntüden türetilen kopya açıldı, 131 yazılımcık okundu). Ama hepsi
# aynı altyapıda, aynı bölgede duruyor: koco_data tek makineye bağlı, tek zone
# (fra/7a9a), Fly volume'leri çoğaltılmıyor. Zone kaybı = her şeyin kaybı.
# Yeri doldurulamaz veri yalnız koco.mv.db -- 1.5 MB. Kutu dışına çıkarmak ucuz.
#
# NEDEN DÜZ KOPYA YETİYOR: uygulama dosyayı açık tutarken alınan kopya
# 2026-09-17'de sınandı, açıldı ve okundu (133 yazılımcık). H2'nin MVStore'u
# çökmeye dayanıklı, yani sıcak kopya "elektrik kesintisi" anına denk ve
# açılışta kendini toparlıyor. AMA bir kez çalışması her zaman çalışacağı
# anlamına GELMEZ: yazma anına denk gelen bir kopya son işlemleri kaybedebilir.
# Bu yüzden aşağıdaki doğrulama adımı isteğe bağlı değil -- sınanmamış yedek
# yedek değil, umuttur.
set -euo pipefail

UYGULAMA=${KOCO_APP:-ikojo}
UZAK=${KOCO_UZAK_DB:-/data/koco.mv.db}
DIZIN=${KOCO_YEDEK_DIZIN:-$HOME/koco-yedek}
TUT_GUN=${KOCO_YEDEK_TUT_GUN:-30}
PAROLA_DOSYASI=${KOCO_YEDEK_PAROLA_DOSYASI:-}
BURASI=$(cd "$(dirname "$0")" && pwd)

# H2 jar'ı build ürünü (stage/ .gitignore'da). Yoksa DOĞRULAMA YAPILAMAZ, ve
# doğrulanmamış yedek üretmektense durmak doğru.
# `|| true` ŞART: `set -euo pipefail` altında glob eşleşmezse `ls` sıfırdan
# farklı çıkar, pipefail bunu boru hattının durumu yapar ve betik aşağıdaki
# dostane mesaja HİÇ ULAŞMADAN sessizce ölür (ölçüldü: çıkış 1, çıktı yok).
H2_JAR=${KOCO_H2_JAR:-$(ls "$BURASI"/stage/editor/lib/com.h2database.h2-*.jar 2>/dev/null | head -1 || true)}

hata() { echo "hata: $*" >&2; exit 1; }

command -v flyctl >/dev/null || hata "flyctl yok"
command -v gpg    >/dev/null || hata "gpg yok"
command -v java   >/dev/null || hata "java yok (H2 doğrulaması için gerekli)"
[ -n "$H2_JAR" ] && [ -f "$H2_JAR" ] || hata "H2 jar'ı bulunamadı.
       Beklenen: $BURASI/stage/editor/lib/com.h2database.h2-*.jar
       stage/ bir build ürünü (.gitignore'da): önce ./build.sh koşun,
       ya da KOCO_H2_JAR=<yol> ile gösterin."

mkdir -p "$DIZIN"
DAMGA=$(date +%Y%m%d-%H%M%S)
GECICI=$(mktemp -d)
trap 'rm -rf "$GECICI"' EXIT   # ham (ŞİFRESİZ) kopya her durumda silinsin

# --- 1. çek ---------------------------------------------------------------
echo "*** $UYGULAMA:$UZAK çekiliyor"
( cd "$GECICI" && flyctl ssh sftp get "$UZAK" -a "$UYGULAMA" >/dev/null ) \
  || hata "sftp get başarısız"
HAM="$GECICI/$(basename "$UZAK")"
[ -s "$HAM" ] || hata "çekilen dosya boş: $HAM"
BOYUT=$(wc -c < "$HAM" | tr -d ' ')
echo "    $BOYUT bayt"

# --- 2. DOĞRULA: dosya açılıyor mu, içinde ne var --------------------------
# H2 "dosya var" ile "dosya sağlam"ı ayırmaz; ayıran şey onu AÇMAK.
# (2026-09-17'de öğrenildi: "Wrong user name or password" hatası aslında
# dosyanın açıldığını kanıtlıyordu -- yapılandırmada user/password yok,
# uygulama boş kimlikle bağlanıyor.)
echo "*** doğrulanıyor (H2 ile açılıyor)"
KOK="${HAM%.mv.db}"
SAYIM=$(java -cp "$H2_JAR" org.h2.tools.Shell \
          -url "jdbc:h2:$KOK;MODE=PostgreSQL;IFEXISTS=TRUE" -user "" -password "" \
          -sql 'select count(*) from "fiddle"' 2>&1) \
  || hata "veritabanı AÇILMADI -- bu kopya atılıyor, Fly anlık görüntüsü devrede:
$SAYIM"
# YALNIZCA-rakam satırını ara. `sed -n 2p` kırılgandı: yukarıdaki 2>&1 stderr'i
# de $SAYIM'a katıyor, yani JVM tek bir uyarı satırı basarsa 2. satır sayı
# olmaz ve `tr -dc` oradaki rastgele rakamları ayıklardı ("Java 21" -> 21).
# `-x` sayesinde "(1 row, 18 ms)" gibi satırlar da elenir.
YAZILIMCIK=$(printf '%s\n' "$SAYIM" | grep -Ex '[0-9]+' | head -1 || true)
[ -n "$YAZILIMCIK" ] || hata "yazılımcık sayısı okunamadı:
$SAYIM"
echo "    $YAZILIMCIK yazılımcık"

# --- 3. SAYI GERİLEMESİ: dosya açılıyor ama içi boşalmışsa ----------------
# Açılabilen ama içeriği kaybolmuş bir veritabanı sessizce "iyi" görünür.
# Bir önceki koşunun sayısıyla karşılaştırmak o sınıfı yakalar.
DURUM="$DIZIN/.son-sayim"
ONCEKI=0
if [ -f "$DURUM" ]; then
  ONCEKI=$(cat "$DURUM")
  # Dosya elle bozulursa `-lt` stderr'e "integer expression expected" basıp
  # uyarısız geçerdi; sayı değilse tabanı yok say.
  case "$ONCEKI" in ''|*[!0-9]*) ONCEKI=0 ;; esac
fi
GERILEDI=0
if [ "$YAZILIMCIK" -lt "$ONCEKI" ]; then
  GERILEDI=1
  echo "    UYARI: yazılımcık sayısı DÜŞTÜ ($ONCEKI -> $YAZILIMCIK)." >&2
  echo "           Yedek yine de alınıyor, ama veri kaybı olabilir; bakın." >&2
  echo "           Taban KORUNUYOR: bilerek budadıysanız $DURUM dosyasını silin." >&2
fi

# --- 4. şifrele -----------------------------------------------------------
# Veritabanı KİŞİSEL VERİ taşıyor: "user" tablosunda ad/e-posta, "access"
# tablosunda source_ip. Şifresiz bırakılmamalı, ve koco-deploy HERKESE AÇIK
# bir depo -- yedek oraya asla girmemeli (bu yüzden .gitignore'a da eklendi).
HEDEF="$DIZIN/koco-$DAMGA.mv.db.gpg"
echo "*** şifreleniyor (AES256)"
if [ -n "$PAROLA_DOSYASI" ]; then
  [ -f "$PAROLA_DOSYASI" ] || hata "parola dosyası yok: $PAROLA_DOSYASI"
  # --pinentry-mode loopback ŞART: gpg 2.1'den beri --passphrase-file tek
  # başına YOK SAYILABİLİR ve gpg pinentry'ye düşer. Terminalde sınarken
  # pinentry açılıp geçtiği için sorun görünmez; cron/launchd'de (tty ve
  # DISPLAY yok) pinentry açılamaz, betik düşer ve o gece yedek alınmaz --
  # yani tam da bu kipin var olma sebebi kırılır.
  gpg --batch --yes --pinentry-mode loopback --symmetric --cipher-algo AES256 \
      --passphrase-file "$PAROLA_DOSYASI" -o "$HEDEF" "$HAM"
else
  gpg --symmetric --cipher-algo AES256 -o "$HEDEF" "$HAM"
fi
[ -s "$HEDEF" ] || hata "şifreli dosya oluşmadı"
chmod 600 "$HEDEF"

# Şifreli KATMANI da doğrula: "sınanmamış yedek yedek değil" ilkesi ham dosya
# kadar gpg çıktısı için de geçerli. 1.5 MB'da gidiş-dönüş bedava.
# Yalnız parola dosyalı kipte: etkileşimli kipte ikinci bir parola sorusu olurdu.
if [ -n "$PAROLA_DOSYASI" ]; then
  echo "*** şifreli kopya geri açılıyor (gidiş-dönüş)"
  gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$PAROLA_DOSYASI" \
      -d "$HEDEF" 2>/dev/null | cmp -s - "$HAM" \
    || hata "şifreli kopya ham dosyayla AYNI DEĞİL -- bu yedeğe güvenilemez: $HEDEF"
  echo "    aynı"
fi

# Taban ancak BURADA ilerlesin: şifreleme ya da gidiş-dönüş patlarsa bu koşum
# başarısız sayılır ve bir sonraki koşum aynı tabana karşı karşılaştırır.
# Gerileme varsa taban KORUNUR, yoksa uyarı yalnız ilk koşuda çıkar ve ertesi
# gün düşük sayı yeni normal olurdu -- tam da yakalamak istediğimiz sınıf.
if [ "$GERILEDI" = 0 ]; then
  echo "$YAZILIMCIK" > "$DURUM"
fi

# --- 5. budama ------------------------------------------------------------
ESKI=$(find "$DIZIN" -name 'koco-*.mv.db.gpg' -type f -mtime +"$TUT_GUN" 2>/dev/null | wc -l | tr -d ' ')
find "$DIZIN" -name 'koco-*.mv.db.gpg' -type f -mtime +"$TUT_GUN" -delete 2>/dev/null || true

echo "*** hazır"
echo "    $HEDEF"
echo "    $YAZILIMCIK yazılımcık, $BOYUT bayt (şifresiz), $(wc -c < "$HEDEF" | tr -d ' ') bayt (şifreli)"
echo "    $(find "$DIZIN" -name 'koco-*.mv.db.gpg' -type f | wc -l | tr -d ' ') yedek elde, $ESKI tanesi budandı (>$TUT_GUN gün)"
echo
echo "    Geri almak için:"
echo "      gpg -o koco.mv.db -d $HEDEF"
