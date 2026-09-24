#!/bin/bash
# compilerServer süreçlerini başlatır ve ÖLÜRLERSE YENİDEN BAŞLATIR.
#
# NEDEN VAR (koco-deploy#17, 3. madde): ölçüldü -- canlı makinede bir
# compilerServer'a `kill -9` atılınca süreç geri GELMİYOR. Kapasite kalıcı
# olarak azalıyor ve ancak yeniden yayımla düzeliyor. İki derleyicinin ikisi
# de gidince sunucu her derlemeyi "Sunucu şu anda çok yoğun" ile reddediyor,
# yani örneğe tıklayan her çocuk hata alıyor.
#
# NEDEN AYRI DOSYA: entrypoint.sh onu `derleyici` kullanıcısıyla (uid 1001,
# #37), start.sh'ten ayrı bir kol olarak başlatıyor; start.sh koco olarak
# koştuğu için derleyicileri başka uid'e geçiremezdi. (Eskiden start.sh
# başlatıyordu; o da `exec nginx` ile bittiği için gözcü zaten ayrı bir
# arka plan süreci olmak zorundaydı.) İkinci sebep: sahte bir derleyici
# komutuyla (KOCO_DERLEYICI_KOMUTU, KOCO_GOZCU_ROUTER_PORT=) konteyner
# olmadan sınanabiliyor -- bu betiğin mantığı öyle ölçüldü.
#
# KAPSAM -- yalnız compilerServer. Router ve editör bilerek dışarıda: ikisi de
# start.sh'te sıralı bekleme (wait_for_port) ile açılıyor ve yeniden
# başlatmaları daha ağır (editör 100+ sn açılıyor, router'ın kütüphane çekişi
# kaçarsa ~50 dk tekrar denemiyor). Kaybı ölçülmüş ve kendiliğinden
# düzelmeyen tek şey derleyici kapasitesi.
#
# YOKLAMA, `wait -n` DEĞİL: `wait -n -p` bash 5.1 istiyor ve taban imaj
# değişirse sessizce kırılır; yoklamanın bedeli birkaç saniyede bir `kill -0`.
# `kill -0`ın zombi sürece "canlı" demesi riski ölçüldü ve YOK: bash arka plan
# çocuklarını SIGCHLD ile kendiliğinden topluyor, ölen çocukta `kill -0`
# başarısız oluyor. (Bu betik `wait` çağırmadığı için bu önemliydi.)
#
# ÇIKIŞ KODU OKUNMUYOR, ve bu bir SÖZLEŞME: her ölüm, kodu ne olursa olsun
# yeniden başlatılıyor. Router (kojojs-core CompilerManager) bir derleyiciyi
# yenilemek ya da takılmadan kurtarmak için ona Retire yolluyor; derleyici
# System.exit(0) ile PLANLI olarak çıkıyor (kojojs-core CompileActor) ve
# yerine taze bir JVM'i bu betiğin başlatması bekleniyor
# (SCALAFIDDLE_COMPILER_RECYCLE_AFTER, start.sh). Bu betiği ileride "yalnız
# hata kodunda yeniden başlat" diye değiştirmek, Retire alan her derleyiciyi
# KALICI olarak kaybettirir: router onu restartGrace (120 sn) boyunca
# "yeniden başlıyor" sayar, sonra /saglik 503'e döner ve Fly makineyi
# yeniden başlatır. Çıkış 0 = planlı, 0 dışı = çökme ayrımı yalnız
# günlükte anlamlı; yeniden başlatma kararında değil.
#
# set -e YOK: gözcünün işi düşen süreçle baş etmek; kendi düşerse koruma da
# gider. -u açık, yazım hatası sessiz kalmasın.
set -u

ADET="${COMPILER_INSTANCES:-2}"
# Sınanabilirlik kapısı: sahte bir komutla koşturulabilsin diye.
KOMUT="${KOCO_DERLEYICI_KOMUTU:-/app/compiler/bin/scalafiddle-core}"
# TIRNAKSIZ kullanılacak, bilerek: "-J-Xmx1100m -J-Xss4m" gibi birden çok
# bayrak taşıyor ve kelimelere ayrılması gerekiyor.
OPTS="${COMPILER_OPTS:-}"
NICE="${KOCO_GOZCU_NICE:-10}"

ARALIK="${KOCO_GOZCU_ARALIK:-5}"              # yoklama sıklığı (sn)
# Derleyicileri başlatmadan önce beklenen router portu; boş = bekleme (sınama).
ROUTER_PORT="${KOCO_GOZCU_ROUTER_PORT-8880}"
# Bundan kısa yaşadıysa: hızlı çöküş. YANLILIK: ölçülen şey ölüm anı değil
# TESPİT anı, yani gerçek ömre en çok ARALIK kadar ekleniyor -- 56-60 sn
# yaşayıp ölen bir süreç "normal ölüm" sayılabilir. 60/5 oranında etkisi
# yok denecek kadar az; bu ikisiyle oynayacak olan bilsin.
ASGARI_OMUR="${KOCO_GOZCU_ASGARI_OMUR:-60}"
GERI_TABAN="${KOCO_GOZCU_GERI_TABAN:-5}"      # ilk geri çekilme (sn)
GERI_TAVAN="${KOCO_GOZCU_GERI_TAVAN:-300}"    # geri çekilme tavanı (sn)

declare -a PID BASLANGIC ARDISIK YENIDEN

# printf'in zaman biçimi bash 4.2'den beri var ve süreç ÇATALLAMIYOR;
# `date +%s` 5 sn'lik yoklamayla günde ~17 bin fork demekti. `wait -n -p`
# için kaçınılan bash 5.1 bağımlılığını getirmiyor (inceleme notu).
simdi() { printf '%(%s)T' -1; }

baslat() {
  local i=$1
  # Her sürece kendi kütüphane önbelleği: aynı dizine
  # iki süreç yazarsa birbirini bozabiliyor.
  SCALAFIDDLE_LIBCACHE="/tmp/extlibs-$i" nice -n "$NICE" $KOMUT $OPTS &
  PID[$i]=$!
  BASLANGIC[$i]=$(simdi)
  YENIDEN[$i]=0
  echo "[koco] derleyici $i başladı (pid ${PID[$i]})"
}

# ROUTER'I BEKLE. Gözcü artık start.sh'ten değil entrypoint.sh'ten, ayrı bir
# kullanıcıyla (derleyici, #37) ve router'dan ÖNCE başlıyor; eskiden start.sh
# onu router'ın portu açıldıktan sonra başlatıyordu. İki sebep:
#  - Erken başlayan derleyici editörün açılışıyla aynı paylaşımlı çekirdeği
#    yarıştırır (Fly'da editör 100+ sn açılıyor).
#  - Eski sıra (önce router, sonra derleyiciler) ölçülmüş ve çalışan sıra;
#    router'sız bir derleyicinin ilk bağlantı hatasında ne yaptığına
#    güvenmek yerine onu koruyoruz.
# Süre sınırı YOK, bilerek: router hiç gelmezse derleyici de işe yaramaz, ve
# o durumu /saglik?enAz=N denetimi yakalıyor.
if [ -n "$ROUTER_PORT" ]; then
  echo "[koco] derleyici gözcüsü router'ı ($ROUTER_PORT) bekliyor..."
  n=0
  while ! (exec 3<>"/dev/tcp/127.0.0.1/$ROUTER_PORT") 2>/dev/null; do
    sleep 1
    n=$((n + 1))
  done
  echo "[koco] router hazır (${n}s), derleyiciler başlıyor"
fi

i=1
while [ "$i" -le "$ADET" ]; do
  ARDISIK[$i]=0
  baslat "$i"
  i=$((i + 1))
done

echo "[koco] derleyici gözcüsü çalışıyor ($ADET süreç, ${ARALIK}s yoklama)"

while true; do
  sleep "$ARALIK"
  s=$(simdi)
  i=1
  while [ "$i" -le "$ADET" ]; do
    if [ "${PID[$i]}" -ne 0 ] && kill -0 "${PID[$i]}" 2>/dev/null; then
      i=$((i + 1))
      continue
    fi

    if [ "${PID[$i]}" -ne 0 ]; then
      # Ölüm yeni fark edildi: hızlı çöküş mü, uzun yaşamış mı?
      omur=$((s - BASLANGIC[i]))
      if [ "$omur" -lt "$ASGARI_OMUR" ]; then
        ARDISIK[$i]=$((ARDISIK[i] + 1))
        bekle=$GERI_TABAN
        k=1
        while [ "$k" -lt "${ARDISIK[$i]}" ] && [ "$bekle" -lt "$GERI_TAVAN" ]; do
          bekle=$((bekle * 2))
          k=$((k + 1))
        done
        [ "$bekle" -gt "$GERI_TAVAN" ] && bekle=$GERI_TAVAN
        # GERİ ÇEKİLME NEDEN VAR: derleyici her açılışta hemen çöküyorsa
        # (yanlış yapılandırma, bellek yok) geri çekilmesiz bir gözcü sıkı
        # döngüye girer -- tek paylaşımlı çekirdeği doyurur ve günlüğü
        # doldurur, yani arızayı büyütür. TAMAMEN PES ETMEK de yok: kapasite
        # sıfırda kalıcı olarak takılmak daha kötü, o yüzden yalnız tavan var.
        echo "[koco] UYARI: derleyici $i ${omur}s sonra öldü (üst üste ${ARDISIK[$i]}.), ${bekle}s sonra yeniden" >&2
        YENIDEN[$i]=$((s + bekle))
      else
        ARDISIK[$i]=0
        echo "[koco] derleyici $i öldü (${omur}s yaşadı), yeniden başlatılıyor" >&2
        YENIDEN[$i]=0
      fi
      PID[$i]=0
    fi

    if [ "$s" -ge "${YENIDEN[$i]}" ]; then
      baslat "$i"
    fi
    i=$((i + 1))
  done
done
