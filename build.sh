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
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
IKOCO=$HERE/..
SBT=${SBT:-$HOME/bin/sbt}
KOCO_TOOLCHAIN=${KOCO_TOOLCHAIN:-tr}
SCALA_TR=${KOJO_SCALA_TR:-$IKOCO/kojo/scala-tr/build/pack/lib}

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
    dest=$(ls "$HERE/stage/compiler/lib/"org.scala-lang.$base-*.jar)
    src="$SCALA_TR/$base.jar"
    [ -f "$src" ] || { echo "hata: $src yok (kojo klonu ve scala-tr pack gerekli)" >&2; exit 1; }
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
