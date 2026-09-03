#!/bin/sh
# Üç servisi yerelde paketler ve deploy/stage/ altına toplar.
#
# kojojs-core artık sbt 1 + Scala 2.13.18 (Faz 3, bkz. kojojs-dev/oneri-scala-2.13.md)
# ve bağımlılıkları HTTPS Maven Central'dan çözülüyor. Editör hâlâ sbt 0.13 --
# yerel ~/.ivy2 önbelleği onun için gerekmeye devam ediyor. Resmi sbt betiği iki
# sürümü de (project/build.properties'e bakarak) çalıştırabilir.
#
# KOCO_TOOLCHAIN=tr (varsayılan): compilerServer'ın scala-compiler +
# scala-reflect jar'ları kojo/scala-tr'nin YAMALI (Türkçe anahtar kelimeli)
# kopyalarıyla değiştirilir -- ikojo-tr'nin özü. KOCO_TOOLCHAIN=en stok bırakır.
# KOCO_SCALA_TR: yamalı jar'ların dizinini geçersiz kılar (varsayılan:
# yan yana klonlanmış kojo/scala-tr/build/pack/lib).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
IKOCO=$HERE/..
SBT=${SBT:-$HOME/bin/sbt}
KOCO_TOOLCHAIN=${KOCO_TOOLCHAIN:-tr}
SCALA_TR=${KOCO_SCALA_TR:-$IKOCO/kojo/scala-tr/build/pack/lib}

case "$KOCO_TOOLCHAIN" in
  tr|en) ;;
  *) echo "hata: KOCO_TOOLCHAIN '$KOCO_TOOLCHAIN' tanınmıyor (tr ya da en olmalı)" >&2; exit 1;;
esac

echo "*** kojojs-core: router + compilerServer paketleniyor"
(cd "$IKOCO/kojojs-core" && "$SBT" -batch "router/stage" "compilerServer/stage")

echo "*** kojojs-editor: Play sunucusu paketleniyor"
(cd "$IKOCO/kojojs-editor" && "$SBT" -batch "server/stage")

echo "*** deploy/stage/ toplanıyor"
rm -rf "$HERE/stage"
mkdir -p "$HERE/stage"
# rsync --delete: cp asla silmez, eski jar'lar sessizce hayatta kalır
rsync -a --delete "$IKOCO/kojojs-core/router/target/universal/stage/"          "$HERE/stage/router/"
rsync -a --delete "$IKOCO/kojojs-core/compiler-server/target/universal/stage/" "$HERE/stage/compiler/"
rsync -a --delete "$IKOCO/kojojs-editor/server/target/universal/stage/"        "$HERE/stage/editor/"

if [ "$KOCO_TOOLCHAIN" = "tr" ]; then
  echo "*** yamalı Türkçe derleyici takas ediliyor (KOCO_TOOLCHAIN=tr)"
  # Yama yalnızca compiler + reflect'te (bkz. kojo/scala-tr/turkish-keywords.patch);
  # scala-library stok kalır. İkisi BİRLİKTE takas edilmeli (NoSuchMethodError).
  for base in scala-compiler scala-reflect; do
    set -- "$HERE/stage/compiler/lib/"org.scala-lang.$base-*.jar
    if [ $# -ne 1 ] || [ ! -f "$1" ]; then
      echo "hata: stage'de tek bir org.scala-lang.$base-*.jar bekleniyordu; bulunan: $*" >&2
      exit 1
    fi
    dest=$1
    src="$SCALA_TR/$base.jar"
    [ -f "$src" ] || { echo "hata: $src yok (kojo klonu ve scala-tr pack gerekli)" >&2; exit 1; }
    if [ "$base" = "scala-compiler" ]; then
      # Sürüm eşleşmesini doğrula: scala-tr farklı bir 2.13.x'ten pack'lenmişse
      # takas sessizce başarılı olur ama çalışma zamanında NoSuchMethodError
      # çıkar -- burada erken ve adıyla patlasın. (compiler.properties yalnız
      # scala-compiler.jar'da var; reflect aynı pack'ten geldiği için yeterli.)
      want=$(basename "$dest" .jar); want=${want##*-}
      if command -v unzip >/dev/null 2>&1; then
        got=$(unzip -p "$src" compiler.properties | sed -n 's/^version.number=//p')
        case "$got" in
          "$want"*) ;;
          *) echo "hata: scala-tr derleyicisi $got sürümünde, stage $want bekliyor" >&2
             echo "      (scala-tr'yi yeniden pack'leyin ya da kojojs-core scalaVersion'ını eşitleyin)" >&2
             exit 1;;
        esac
      else
        echo "    uyarı: unzip bulunamadı, scala-tr sürüm doğrulaması atlandı" >&2
      fi
    fi
    cp "$src" "$dest"
    echo "    $(basename "$dest") <- scala-tr/$base.jar"
  done
else
  echo "*** stok derleyici bırakıldı (KOCO_TOOLCHAIN=$KOCO_TOOLCHAIN)"
fi

echo "*** hazır:"
du -sh "$HERE/stage"/*
echo
echo "Şimdi:  docker build -t koco $HERE"
echo "Sonra:  docker run --rm -p 7860:7860 koco"
