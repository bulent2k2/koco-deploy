#!/bin/bash
# once_dene/dene.sh -- dağıtım öncesi (ya da sonrası) deneme: betikler/*.kojo'yu Koco'nun
# GERÇEK derleyicisine (/compile) gönderir; istenirse derlenmiş JS'i başsız Chromium'da
# çalıştırıp çalışma zamanı hatalarını, PIXI sürümünü ve çizim sayılarını toplar.
#
#   ./dene.sh                      # yalnız derleme (canlı: https://ikojo.fly.dev)
#   KOCO=http://localhost:7860 ./dene.sh -t     # yerel konteyner, derleme + tarayıcı
#   ./dene.sh -t -g                # sonuçları sonuclar/{derleme,calisma}.tsv'ye yaz
#   ./dene.sh -t betikler/05-gradyanlar.kojo    # tek betik
#
# Seçenekler
#   -t          tarayıcıda da çalıştır (node + playwright gerekir; bkz. tarayici/package.json)
#   -g          sonuçları sonuclar/ altına yaz (TSV + ekran görüntüleri); yoksa yalnız ekrana
#   -s SANİYE   tarayıcıda betik başına EN ÇOK bekleme (varsayılan 20); TAMAM/HATA görünür görünmez geçilir
#   -k DİZİN    tarayıcı kitaplıkları (pixi/jsts/howler .min.js); varsayılan: $KOCO/assets/javascript/
#               adresinden tarayici/kitaplik/ dizinine indirilir (bir kez)
#   KOCO_NOT    (ortam) TSV başlığına eklenecek not, ör. "core dd43d64, dev 32fb2f1, editor aa4e682"
#
# Durumlar
#   derleme : geçti / kaldı (derleyici hata verdi) / sunucu (HTTP 200 gelmedi -- sunucunun sorunu)
#   çalışma : geçti / kaldı (sayfa hatası; gerekli(...) tutmayınca da bu; çıktıda "HATA:") / eksik (sürede "TAMAM" yazılmadı)
#
# Çıkış kodu: herhangi bir "kaldı" ya da "eksik" varsa 1 (sunucu 2), yoksa 0.
#
# Taşınabilirlik: macOS /bin/bash 3.2 -- ilişkisel dizi yok; kabuk değişken adları ASCII.
# Sarmalayıcı (sar) kojojs-editor application.conf defaultSource ile AYNI olmalı
# (kojojs-dev/ornekler/ornekleri-dogrula.sh ile de birebir).
set -u
KOCO="${KOCO:-https://ikojo.fly.dev}"
KOCO_NOT="${KOCO_NOT:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"

TARAYICI=""; GUNCELLE=""; SANIYE=20; KITAPLIK=""
while getopts "tgs:k:h" opt; do
  case $opt in
    t) TARAYICI=1 ;;
    g) GUNCELLE=1 ;;
    s) SANIYE="$OPTARG" ;;
    k) KITAPLIK="$OPTARG" ;;
    h|*) sed -n '2,26p' "$0"; exit 0 ;;
  esac
done
shift $((OPTIND-1))

hedefler=()
if [ $# -eq 0 ]; then
  for f in "$DIR"/betikler/*.kojo; do hedefler+=("$f"); done
else
  for h in "$@"; do
    if [ -d "$h" ]; then for f in "$h"/*.kojo; do hedefler+=("$f"); done
    elif [ -f "$h" ]; then hedefler+=("$h")
    else echo "bulunamadı: $h" >&2; exit 2; fi
  done
fi

JS_DIZINI="$DIR/sonuclar/js"; GORSEL_DIZINI="$DIR/sonuclar/gorseller"
mkdir -p "$JS_DIZINI"
[ -n "$GUNCELLE" ] && mkdir -p "$GORSEL_DIZINI"

# ScalaFiddle sarmalayıcısı -- application.conf defaultSource ile aynı
sar() {
  cat <<'PRE'
import fiddle.Fiddle.println
import scalajs.js

@js.annotation.JSExportTopLevel("ScalaFiddle")
object ScalaFiddle {
    import kojo.{SwedishTurtle, TurkishTurtle, Turtle, KojoWorldImpl, Vector2D, Picture}
    import kojo.doodle.Color._
    import kojo.Speed._
    import kojo.RepeatCommands._
    import kojo.syntax.Builtins
    implicit val kojoWorld: kojo.KojoWorld = new KojoWorldImpl()
    val builtins = new Builtins()
    import builtins._
    import turtle._
    import svTurtle._
    import trTurtle._
PRE
  # Router derleme sonucunu KAYNAK ÖZETİYLE önbellekler: betik değişmemişse eski çalışma zamanıyla
  # bağlanmış JS'i geri verir. Her koşu gerçek bir derleme olsun diye gövdeye zaman damgalı yorum girer.
  printf '// once_dene %s\n' "$(date +%s)$$"
  cat "$1"
  printf '\n}\n'
}

# Tarayıcı kitaplıkları: yoksa canlıdan indir (editörün sunduğu dosyaların aynısı)
kitaplik_hazirla() {
  local hedef="$DIR/tarayici/kitaplik" k
  mkdir -p "$hedef"
  for k in pixi.min.js jsts.min.js howler.min.js; do
    if [ -n "$KITAPLIK" ]; then
      [ -f "$KITAPLIK/$k" ] || { echo "kitaplık dosyası yok: $KITAPLIK/$k" >&2; exit 2; }
      cp "$KITAPLIK/$k" "$hedef/$k"
    elif [ ! -s "$hedef/$k" ]; then
      echo "  indiriliyor: $KOCO/assets/javascript/$k"
      curl -sfL -m 120 "$KOCO/assets/javascript/$k" -o "$hedef/$k" || { echo "indirilemedi: $k" >&2; exit 2; }
    fi
  done
  # kaplumbağa simgesi: çalışma zamanı assets/images/turtle32.png'yi sahneye göreli yükler
  local simge="$DIR/tarayici/assets/images/turtle32.png"
  if [ ! -s "$simge" ]; then
    mkdir -p "$(dirname "$simge")"
    curl -sfL -m 60 "$KOCO/assets/images/turtle32.png" -o "$simge" || echo "  uyarı: turtle32.png indirilemedi (kaplumbağa simgesi görünmez)" >&2
  fi
  local surum
  surum=$(grep -o 'VERSION="[0-9.]*"' "$hedef/pixi.min.js" | head -1 | tr -d 'VERSION="')
  echo "  tarayıcı kitaplığı: PIXI $surum"
}

if [ -n "$TARAYICI" ]; then
  command -v node >/dev/null || { echo "node yok; -t için Node.js ve Playwright gerekir (tarayici/package.json)" >&2; exit 2; }
  if [ -d "$DIR/tarayici/node_modules/playwright" ]; then export NODE_PATH="$DIR/tarayici/node_modules${NODE_PATH:+:$NODE_PATH}"; fi
  node -e "require('playwright')" 2>/dev/null || { echo "playwright bulunamadı: cd tarayici && npm install && npx playwright install chromium" >&2; exit 2; }
  kitaplik_hazirla
fi

cikti=$(mktemp); ann_dosya=$(mktemp); d_sonuc=$(mktemp); c_sonuc=$(mktemp)
trap 'rm -f "$cikti" "$ann_dosya" "$d_sonuc" "$c_sonuc"' EXIT

# Isınma: derleyici kayıt olmadan gelen ilk istekler 5xx döner
isin() {
  local govde kod i
  govde=$(mktemp); printf 'satıryaz(1)\n' | sar /dev/stdin > "$govde"
  for i in $(seq 1 15); do
    kod=$(curl -s -m 120 -X POST --data-binary @"$govde" -H "Content-Type: text/plain; charset=utf-8" \
      "$KOCO/compile?opt=fast" -o /dev/null -w "%{http_code}")
    [ "$kod" = "200" ] && { rm -f "$govde"; return 0; }
    echo "  derleyici hazır değil (HTTP $kod), bekleniyor..." >&2; sleep 8
  done
  rm -f "$govde"; echo "UYARI: derleyici ısınmadı ($KOCO)" >&2
}
echo "Koco: $KOCO"
isin

d_gecti=0; d_kaldi=0; d_sunucu=0; c_gecti=0; c_kaldi=0; c_eksik=0
for f in "${hedefler[@]}"; do
  ad=$(basename "$f")
  govde=$(mktemp); sar "$f" > "$govde"
  kod=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    kod=$(curl -s -m 300 -X POST --data-binary @"$govde" -H "Content-Type: text/plain; charset=utf-8" \
      "$KOCO/compile?opt=fast" -o "$cikti" -w "%{http_code}")
    case "$kod" in 000|502|503|504) sleep 8 ;; *) break ;; esac
  done
  rm -f "$govde"
  durum="kaldı"; ozet=""; js_yolu="$JS_DIZINI/${ad%.kojo}.js"; rm -f "$js_yolu"
  if [ "$kod" != "200" ]; then
    durum="sunucu"
    ozet="HTTP $kod: $( (gzip -dc "$cikti" 2>/dev/null || cat "$cikti") | head -c 80 | tr '\n\t' '  ')"
  else
    ann=$(python3 -c "
import gzip,json,io,sys
try: d=json.loads(gzip.open(sys.argv[1],'rt',encoding='utf-8').read())
except OSError: d=json.load(io.open(sys.argv[1],encoding='utf-8'))
a=[x for x in (d.get('annotations') or []) if x.get('tpe','error')!='warning']
print(len(a))
if a:
    x=a[0]; t=x.get('text', x.get('message', ''))
    if isinstance(t, list): t=' '.join(str(s) for s in t)
    sys.stderr.write((str(int(x.get('row', 17))-16)+': '+str(t)).replace('\n',' ')[:200])
elif d.get('jsCode'):
    io.open(sys.argv[2],'w',encoding='utf-8').write(d['jsCode'][0])
" "$cikti" "$js_yolu" 2>"$ann_dosya")
    if [ "$ann" = "0" ] && [ -s "$js_yolu" ]; then durum="geçti"
    else ozet="$ann hata: $(cat "$ann_dosya")"; case "$ozet" in *"optimizer crashed"*) durum="sunucu" ;; esac; fi
  fi
  case "$durum" in geçti) d_gecti=$((d_gecti+1)); echo "✓ $ad" ;;
    sunucu) d_sunucu=$((d_sunucu+1)); echo "⚠ $ad -- $ozet" ;;
    *) d_kaldi=$((d_kaldi+1)); echo "✗ $ad -- $ozet" ;; esac
  printf '%s\t%s\t%s\n' "$ad" "$durum" "$ozet" >> "$d_sonuc"

  if [ -n "$TARAYICI" ] && [ "$durum" = "geçti" ]; then
    gorsel=""; [ -n "$GUNCELLE" ] && gorsel="$GORSEL_DIZINI/${ad%.kojo}.png"
    satir=$(node "$DIR/tarayici/cizdir.js" "$js_yolu" "$SANIYE" "$gorsel" | python3 -c "
import sys,json
d=json.loads(sys.stdin.readline() or '{}')
h=' | '.join(d.get('hatalar',[]))[:300]; u=' | '.join(d.get('uyarilar',[]))[:200]
c=d.get('cikti','').replace('\n',' | ')[:200]
print('\t'.join(str(x) for x in [d.get('durum','kaldı'), d.get('sure',''), d.get('pixi',''), d.get('cizim',''), d.get('kare',''), d.get('cocuk',''), d.get('dokuOnbellegi',''), h, u, c]))")
    c_durum=$(printf '%s' "$satir" | cut -f1)
    c_hata=$(printf '%s' "$satir" | cut -f8)
    case "$c_durum" in
      geçti) c_gecti=$((c_gecti+1)); echo "    ▶ çalıştı  $(printf '%s' "$satir" | cut -f2)s (PIXI $(printf '%s' "$satir" | cut -f3), çizim $(printf '%s' "$satir" | cut -f4), çocuk $(printf '%s' "$satir" | cut -f6))" ;;
      eksik) c_eksik=$((c_eksik+1)); echo "    ▶ eksik -- ${SANIYE}s içinde TAMAM yazılmadı: $(printf '%s' "$satir" | cut -f10)" ;;
      *) c_kaldi=$((c_kaldi+1)); echo "    ▶ KALDI -- $c_hata" ;;
    esac
    printf '%s\t%s\n' "$ad" "$satir" >> "$c_sonuc"
  fi
done

echo
echo "derleme -- geçti: $d_gecti   kaldı: $d_kaldi   sunucu: $d_sunucu   toplam: ${#hedefler[@]}"
[ -n "$TARAYICI" ] && echo "çalışma -- geçti: $c_gecti   kaldı: $c_kaldi   eksik: $c_eksik"

if [ -n "$GUNCELLE" ]; then
  mkdir -p "$DIR/sonuclar"
  { echo "# once_dene/dene.sh derleme sonucu -- $(date -u +%Y-%m-%d) -- $KOCO${KOCO_NOT:+ -- $KOCO_NOT}"
    echo "# geçti: $d_gecti   kaldı: $d_kaldi   sunucu: $d_sunucu"
    printf 'betik\tdurum\tözet\n'; cat "$d_sonuc"; } > "$DIR/sonuclar/derleme.tsv"
  echo "yazıldı: sonuclar/derleme.tsv"
  if [ -n "$TARAYICI" ]; then
    { echo "# once_dene/dene.sh tarayıcı sonucu -- $(date -u +%Y-%m-%d) -- $KOCO${KOCO_NOT:+ -- $KOCO_NOT} -- betik başına ${SANIYE}s"
      echo "# geçti: $c_gecti   kaldı: $c_kaldi   eksik: $c_eksik"
      printf 'betik\tdurum\tsüre\tpixi\tçizim\tkare\tçocuk\tdokuÖnbelleği\thatalar\tuyarılar\tçıktı\n'; cat "$c_sonuc"; } > "$DIR/sonuclar/calisma.tsv"
    echo "yazıldı: sonuclar/calisma.tsv (+ sonuclar/gorseller/*.png -- git'e girmez)"
  fi
fi

if [ "$d_sunucu" -gt 0 ]; then exit 2; fi
[ "$d_kaldi" -eq 0 ] && [ "$c_kaldi" -eq 0 ] && [ "$c_eksik" -eq 0 ]
