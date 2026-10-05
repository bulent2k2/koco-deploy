#!/bin/bash
# once_dene/cevir-seli.sh -- /cevir seli altında DERLEMENİN ne kadar yavaşladığını ölçer (koco-deploy#70).
#
#   KOCO=http://127.0.0.1:7880 ./cevir-seli.sh [örnek sayısı=8] [sel istek/sn=8]
#
# Üç evre, her birinde N sıralı derleme (her kaynak benzersiz): yüksüz, 60 KB'lık /cevir seli altında,
# sel bittikten sonra yüksüz (router'ın kuyruğu boşalana dek beklenir; bekleme süresi de yazılır).
# Oran = sel altındaki medyan / yüksüz medyan. v84, --cpus 2, elle ölçüm: yüksüz ~0.8 sn, sel altında
# ~3.4 sn. Düzeltmeden sonra oran 1'e yaklaşmalı.
#
# GÜVENLİK: yalnız yerel adreslere (localhost / 127.0.0.1) koşar. Sınırdaki 64 KB'lık istekler üretimin
# 2 çekirdeğini doldurabilir; canlıya bilerek koşmak için KOCO_SEL_IZNI=1 verin.
#
# Tuzaklar: (1) router derleme sonucunu kaynak ÖZETİYLE önbellekler; her isteğe benzersiz yorum
# girmezse önbellekten dönen 0.3 sn'lik yanıtları ölçersiniz. (2) İlk derlemeler soğuk (derleyici başına
# ~13 sn); önce atılan ısınma derlemeleri var. (3) "Yüksüz" taban ısınmayla sürüklenir: bu yüzden
# karşılaştırma sel ÖNCESİYLE değil sel SONRASIYLA yapılıyor.
set -u
KOCO="${KOCO:-http://127.0.0.1:7860}"
N="${1:-8}"; HIZ="${2:-8}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Konak AYRIŞTIRILARAK denetlenir; kalıp eşleştirmek yetmez: http://127.0.0.1:1@baska.example kalıba
# uyar ama curl'ün gittiği konak baska.example'dır (userinfo). Userinfo içeren adres hiç kabul edilmez.
yerel=$(python3 -c '
import sys, urllib.parse as u
p = u.urlparse(sys.argv[1])
ok = p.scheme in ("http", "https") and "@" not in p.netloc and p.hostname in ("localhost", "127.0.0.1", "::1")
print("1" if ok else "")' "$KOCO")
[ -n "$yerel" ] || [ -n "${KOCO_SEL_IZNI:-}" ] || { echo "reddedildi: $KOCO yerel değil (canlıya sel için KOCO_SEL_IZNI=1)" >&2; exit 2; }

# Sarmalayıcı dene.sh'tekiyle AYNI olmalı: üçüncü bir kopya tutmak yerine oradan çekiliyor
eval "$(sed -n '/^sar() {/,/^}/p' "$DIR/dene.sh")"
type sar >/dev/null 2>&1 || { echo "dene.sh'ten sar() çıkarılamadı" >&2; exit 2; }

GOVDE=$(mktemp); KAYNAK=$(mktemp); SEL=""
# Selin curl'leri alt kabuğun ($SEL) çocuğu, $$'ın değil: önce çocukları, sonra alt kabuğu öldür
seli_durdur() { [ -n "$SEL" ] || return 0; pkill -P "$SEL" 2>/dev/null; kill "$SEL" 2>/dev/null; wait "$SEL" 2>/dev/null; SEL=""; }
trap 'seli_durdur; rm -f "$GOVDE" "$KAYNAK"' EXIT
python3 -c "import sys; sys.stdout.write('ileri(10)\n' * 6000)" > "$GOVDE"   # 60 000 bayt (sınır 65 536)

derle() {  # benzersiz kaynak, "HTTP süre" yazar
  { printf '// cevir-seli %s %s\n' "$(date +%s%N 2>/dev/null || date +%s)" "$RANDOM$RANDOM"; printf 'satıryaz(%s)\n' "$RANDOM"; } | sar /dev/stdin > "$KAYNAK"
  curl -s -m 120 -X POST --data-binary @"$KAYNAK" -H 'Content-Type: text/plain; charset=utf-8' \
    "$KOCO/compile?opt=fast" -o /dev/null -w '%{http_code} %{time_total}\n'
}
evre() {  # N derleme; süreleri $1 dosyasına, kodları ekrana
  : > "$1"; local i k s
  for i in $(seq 1 "$N"); do read -r k s < <(derle); echo "$s" >> "$1"; [ "$k" = 200 ] || echo "  uyarı: HTTP $k" >&2; done
}
medyan() { sort -n "$1" | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }
satir() { printf '  %-28s medyan %s sn   [%s]\n' "$1" "$(medyan "$2")" "$(sort -n "$2" | tr '\n' ' ')"; }

echo "Hedef: $KOCO   N=$N   sel: ${HIZ}/sn, 60 KB"
echo "ısınma (4 derleme, atılır)..."; for i in 1 2 3 4; do derle >/dev/null; done
A=$(mktemp); B=$(mktemp); C=$(mktemp)
evre "$A"
(  # sel: ~HIZ istek/sn, 60 KB'lık /cevir
  ara=$(awk -v h="$HIZ" 'BEGIN{printf "%.3f", 1/h}')
  while :; do
    curl -s -o /dev/null -m 20 -X POST --data-binary @"$GOVDE" "$KOCO/cevir?yon=tr2en" &
    sleep "$ara"
  done
) &
SEL=$!
evre "$B"
seli_durdur
# Sel kesilince router kuyruğundaki çeviri isteklerini hâlâ işliyor olabilir; hemen ölçmek "sel sonrası"nı
# şişirir (ilk sürümde 0.8 yerine 2.3 sn çıktı). Küçük bir /cevir isteği hızlanana kadar bekle, süreyi yaz.
t0=$SECONDS; hizli=0
while [ $((SECONDS-t0)) -lt 90 ] && [ "$hizli" -lt 3 ]; do
  s=$(printf 'ileri(1)' | curl -s -o /dev/null -m 20 -X POST --data-binary @- "$KOCO/cevir?yon=tr2en" -w '%{time_total}')
  if awk -v s="$s" 'BEGIN{exit !(s < 0.25)}'; then hizli=$((hizli+1)); else hizli=0; sleep 1; fi
done
BOSALMA=$((SECONDS-t0))
evre "$C"

echo "sel kesildikten sonra /cevir'in toparlanması: ${BOSALMA} sn (küçük istek <0.25 sn olana dek)"
echo "sonuç (derleme süresi):"
satir "yüksüz (sel öncesi)" "$A"
satir "/cevir seli altında" "$B"
satir "yüksüz (sel sonrası)" "$C"
awk -v a="$(medyan "$A")" -v b="$(medyan "$B")" -v c="$(medyan "$C")" 'BEGIN{printf "oran: sel altı / sel öncesi %.1fx, sel altı / sel sonrası %.1fx\n", b/a, b/c}'
rm -f "$A" "$B" "$C"
