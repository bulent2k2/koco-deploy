#!/bin/sh
# Üç servisi yerelde paketler ve deploy/stage/ altına toplar.
# Yerelde yapılıyor çünkü ~/.ivy2 önbelleği olmadan bağımlılıklar çözülemiyor
# (plugins.sbt hâlâ ölü http://repo.typesafe.com'a bakıyor).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
IKOCO=$HERE/..
SBT=${SBT:-$HOME/bin/sbt}

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

echo "*** hazır:"
du -sh "$HERE/stage"/*
echo
echo "Şimdi:  docker build -t koco $HERE"
echo "Sonra:  docker run --rm -p 7860:7860 koco"
