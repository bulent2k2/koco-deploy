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
# KOCO_SCALA_TR: yamalı jar'ların dizinini geçersiz kılar. Boşsa sırayla
# yan yana klonlanmış kojo/scala-tr/build/pack/lib ve
# ~/src/kojo/git/master/scala-tr/build/pack/lib denenir (ilk bulunan).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
IKOCO=$HERE/..
SBT=${SBT:-$HOME/bin/sbt}
KOCO_TOOLCHAIN=${KOCO_TOOLCHAIN:-tr}
SCALA_TR=${KOCO_SCALA_TR:-}
if [ -z "$SCALA_TR" ]; then
  for d in "$IKOCO/kojo/scala-tr/build/pack/lib" "$HOME/src/kojo/git/master/scala-tr/build/pack/lib"; do
    [ -f "$d/scala-compiler.jar" ] && { SCALA_TR=$d; break; }
  done
  # bulunamadıysa aşağıdaki takas adımı yolu adıyla söyleyip dursun
  : "${SCALA_TR:=$IKOCO/kojo/scala-tr/build/pack/lib}"
fi

# İKİ FARKLI JDK gerekiyor -- imajdaki çift JRE'nin derleme zamanı karşılığı:
#   kojojs-core  : Java 9+ ŞART. compiler-server FlatFileSystem.scala
#                  InputStream.readAllBytes() kullanıyor, Java 8'de yok
#                  ("value readAllBytes is not a member of java.io.InputStream").
#   kojojs-editor: sbt 0.13 + Play 2.6, Java 8 istiyor.
# Makinede `java` hangisiyse ona bırakmak birini kırıyor; her adım kendi
# JAVA_HOME'unu alsın. Boş bırakılırsa macOS'ta /usr/libexec/java_home
# listesinden javac'lı ilk uygun JDK seçilir (core: 11, yoksa 9+; editör: 8;
# javac şartı /Library/Internet Plug-Ins altındaki salt JRE'yi dışlar); başka
# yerde ortamdaki JDK kalır. İki durumda da sürüm sbt BAŞLAMADAN denetlenir:
# yanlış JDK'yle dakikalarca derleyip sonda patlamasın. Bu makinede denenmiş
# çift: Temurin 11.0.24 (core) + Oracle 1.8.0_271 (editör).
jdk_bul() {  # $1: ana sürüm ("8", "11") ya da en az ("9+"); javac'lı ilk eşleşme
  [ -x /usr/libexec/java_home ] || return 0
  /usr/libexec/java_home -V 2>&1 | sed -n 's/^ *\([0-9][0-9.]*\)[^/]*\(\/.*\)$/\1 \2/p' |
  while read -r ver home; do
    maj=${ver%%.*}
    if [ "$maj" = 1 ]; then maj=${ver#1.}; maj=${maj%%.*}; fi
    case $1 in
      *+) [ "$maj" -ge "${1%+}" ] || continue;;
      *)  [ "$maj" = "$1" ] || continue;;
    esac
    [ -x "$home/bin/javac" ] && { echo "$home"; break; }
  done
  return 0
}
KOCO_JDK_CORE=${KOCO_JDK_CORE:-$(jdk_bul 11)}
[ -n "$KOCO_JDK_CORE" ] || KOCO_JDK_CORE=$(jdk_bul 9+)
KOCO_JDK_EDITOR=${KOCO_JDK_EDITOR:-$(jdk_bul 8)}

# `java -version` ilk satırından ana sürüm: "1.8.0_271" -> 8, "11.0.24" -> 11
jdk_surum() {
  if [ -n "$1" ]; then j=$1/bin/java; else j=java; fi
  "$j" -version 2>&1 | sed -n '1s/.*"\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p' |
    awk '{ print ($1 == 1) ? $2 : $1 }'
}
jdk_denetle() {  # $1: JDK dizini (boş = ortamdaki), $2: en az, $3: en çok, $4: adım
  s=$(jdk_surum "$1")
  if [ -z "$s" ] || [ "$s" -lt "$2" ] || [ "$s" -gt "$3" ]; then
    echo "hata: $4 için Java $2..$3 gerekiyor; ${1:-ortamdaki} JDK ${s:-?} veriyor" >&2
    echo "      KOCO_JDK_CORE / KOCO_JDK_EDITOR ile doğru JDK dizinini geçin" >&2
    exit 1
  fi
}
jdk_denetle "$KOCO_JDK_CORE"   9 99 kojojs-core
jdk_denetle "$KOCO_JDK_EDITOR" 8  8 kojojs-editor
echo "*** JDK core: ${KOCO_JDK_CORE:-ortamdaki} | editör: ${KOCO_JDK_EDITOR:-ortamdaki}"
echo "*** scala-tr: $SCALA_TR"

# JAVA_HOME'u yalnız bir komut için kurar; PATH de gerekiyor çünkü sbt
# başlatıcısı `java`yı PATH'ten buluyor, JAVA_HOME'a bakmıyor.
ile_jdk() {
  jdk=$1; shift
  if [ -n "$jdk" ]; then
    [ -x "$jdk/bin/java" ] || { echo "hata: $jdk/bin/java yok" >&2; exit 1; }
    echo "    JDK: $("$jdk/bin/java" -version 2>&1 | head -1)"
    JAVA_HOME=$jdk PATH=$jdk/bin:$PATH "$@"
  else
    "$@"
  fi
}

case "$KOCO_TOOLCHAIN" in
  tr|en) ;;
  *) echo "hata: KOCO_TOOLCHAIN '$KOCO_TOOLCHAIN' tanınmıyor (tr ya da en olmalı)" >&2; exit 1;;
esac

# sbt'nin `stage` görevi HEDEF DİZİNİ TEMİZLEMİYOR: classpath'ten düşen jar'lar
# target/universal/stage/lib altında yaşamaya devam ediyor. 2.13 geçişinden
# sonra bu, 38 ölü 2.12 jar'ı (scala-compiler-2.12.10 dahil) demek -- hem imajı
# şişiriyor hem de aşağıdaki takas globunu ikiye çıkarıp derlemeyi durduruyor.
# rsync --delete bir alt katmanda aynı derdi çözüyor; kaynak burada temizlenmeli.
for d in "$IKOCO/kojojs-core/router" "$IKOCO/kojojs-core/compiler-server" \
         "$IKOCO/kojojs-editor/server"; do
  rm -rf "$d/target/universal/stage"
done

echo "*** kojojs-core: router + compilerServer paketleniyor"
(cd "$IKOCO/kojojs-core" && ile_jdk "$KOCO_JDK_CORE" "$SBT" -batch "router/stage" "compilerServer/stage")

echo "*** kojojs-editor: Play sunucusu paketleniyor"
(cd "$IKOCO/kojojs-editor" && ile_jdk "$KOCO_JDK_EDITOR" "$SBT" -batch "server/stage")

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
    [ -f "$src" ] || { echo "hata: $src yok (kojo klonu ve scala-tr pack gerekli; dizin farklıysa KOCO_SCALA_TR=... geçin)" >&2; exit 1; }
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
