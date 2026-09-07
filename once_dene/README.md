# once_dene — dağıtım öncesi deneme takımı

Koco'yu (ikojo) canlıya almadan **önce** (ya da aldıktan hemen sonra) çalışma zamanının
ve derleyicinin ayakta olduğunu gösteren, elle yazılmış bir betik kümesi ve onu koşturan
araçlar. `kojojs-dev/ornekler/ornekleri-dogrula.sh` masaüstü örneklerini yalnız **derler**;
burası ayrıca betikleri **tarayıcıda çalıştırır**: PIXI (çizim, doku, yazı, sprite),
JTS (çarpışma), howler (ses), Türkçe standart kitaplık ve yamalı derleyicinin Türkçe
anahtar kelimeleri gerçekten çalışıyor mu diye bakar.

```
once_dene/
  dene.sh                 koşucu: derle (+ isteğe bağlı tarayıcıda çalıştır), TSV yaz
  betikler/*.kojo         22 deneme betiği (aşağıdaki tablo)
  tarayici/sahne.html     editörün resultframe.scala.html'inin başsız eşi (aynı öğe kimlikleri)
  tarayici/cizdir.js      Playwright koşucusu: hata, çıktı, PIXI sürümü, çizim/kare sayıları
  tarayici/package.json   playwright bağımlılığı (npm install; npx playwright install chromium)
  sonuclar/derleme.tsv    son derleme sonucu (betik, durum, özet)
  sonuclar/calisma.tsv    son tarayıcı sonucu (durum, pixi, çizim, kare, çocuk, doku, hata, uyarı, çıktı)
  sonuclar/gorseller/     betik başına ekran görüntüsü (tuval)
```

## Kullanım

```sh
./dene.sh                                    # canlı sunucuya karşı yalnız derleme
KOCO=http://localhost:7860 ./dene.sh -t      # yerel konteyner: derleme + tarayıcı
./dene.sh -t -g                              # sonuçları sonuclar/ altına yaz (TSV + görüntüler)
./dene.sh -t betikler/05-gradyanlar.kojo     # tek betik
./dene.sh -h                                 # seçenekler (-s saniye, -k kitaplık dizini)
```

Tarayıcı koşusu için bir kez: `cd tarayici && npm install && npx playwright install chromium`.
Kitaplıklar (`pixi.min.js`, `jsts.min.js`, `howler.min.js`) ve kaplumbağa simgesi ilk koşuda
`$KOCO/assets/...` adresinden `tarayici/kitaplik/` ve `tarayici/assets/` altına indirilir
(git'e girmez); böylece tarayıcı **canlının sunduğu** PIXI sürümüyle koşar. Yerel bir
editör klonundan almak için `-k <editor>/server/src/main/assets/javascript`.

Çıkış kodu: derleme ya da çalışma zamanında "kaldı"/"eksik" varsa 1, sunucu hatası varsa 2.
Dağıtım akışında `build.sh` → `docker run` → `KOCO=http://localhost:7860 ./dene.sh -t -g`
→ yeşilse `fly deploy` şeklinde kullanılması düşünüldü.

## Durumlar

| aşama | durum | anlamı |
|---|---|---|
| derleme | geçti / kaldı / sunucu | derleyici hata verdi (kaldı) ya da HTTP 200 gelmedi (sunucu: betiğin değil sunucunun sorunu) |
| çalışma | geçti | sayfa hatası yok **ve** betik `TAMAM` yazdı |
| çalışma | kaldı | sayfa hatası: fırlayan kural dışı durum, `gerekli(...)` tutmadı, yakalanmamış söz (Promise) |
| çalışma | eksik | hata yok ama `TAMAM` yazılmadı: betik takıldı ya da beklenen kare sayısına gelmedi |

Betikler kendini denetler: `gerekli(koşul, ileti)` tutmazsa fırlayan hata sayfa hatası olur.
Her betik sonunda `satıryaz("TAMAM: ...")` yazar; canlandırmalı olanlar belli bir kare sayısında
`durdur()` deyip öyle yazar (koşucu betik başına varsayılan 5 s bekler).

Ağ/medya yüklenememesi (dosya:// koşusunda `/media/...` yok) **uyarı** sayılır, kaldı değil;
`sonuclar/calisma.tsv` uyarılar sütununda görünür.

## Betikler ve kapsadıkları

| betik | kapsam |
|---|---|
| 01-kaplumbaga-temel | ileri/sağ/zıpla, kalem/boya, daire/yay/kare/üçgen, nokta, yazı, bellek, konumuOku |
| 02-kaplumbaga-coklu | yeniKaplumbağa, çevir, noktayaDön/noktayaGit, geri, gizle/göster |
| 03-resim-sekiller | Resim.daire/dikdörtgen/kare/elips/yay/çizgi/yoldan/noktadan, dizi/diziYatay/diziDikey/küme/düzenli, sınırları |
| 04-resim-donusturuculer | götür/döndür/büyüt/boyaRengi/kalemRengi/kalemBoyu/saydamlık zincirleri, yerinde değişim, kopyası, sil |
| 05-gradyanlar | doğrusal/çoklu/merkezden/döngülü gradyan, RenkDD, zincir ortasında ve dizide boyaRengi(boya), DokumaBoya (gömülü veri adresi), kym/ada/adas |
| 06-renk-yapicilar | Renk(k,y,m[,s]), renkKur, Renk.kym/kyms/rgb, 26 adlı renk, rastgeleRenk |
| 07-yazi | Resim.yazı/yazıRenkli, yazıyüzü ve Font, kalın/eğik, dönüştürücü arkasında güncelle, çizMerkezdeYazı, yazıÇerçevesi |
| 08-canlandirma | canlandır+durdur, canlandırYenidenÇizerek, tepkiVer, ekranTazelemeHızınıGöster, kareSüresi |
| 09-carpisma | çarpışıyorMu/çarptıMı/çarpışma/çarpışmalar, sınırları/içeriyorMu/uzaklık, çizSahne, sahnedenSek/resimdenSek, dokunuyorMu |
| 10-klavye-fare | tuşaBasınca/tuşuBırakınca/tuşBasılıMı, resim fare olayları, fareKonumu, kumandaKolu |
| 11-ses | sesMp3üÇal, müzik çal/kapat/döngü, yeniMp3Çalar, notaÇalgısınıKur/notaÇal (howler) |
| 12-imge-giysi | Resim.imge (zarflı dahil), giysili kaplumbağa, giysileriKur/birsonrakiGiysi/giysiyiBüyült |
| 13-sahne-tuval | artalanıKur (düz/dik/yatay), tuvalAlanı/tuvalSınırları, eksen/ızgara, yaklaş/kaydır/döndür, bakış açıları, tuvalBoyutlarınıKur |
| 14-koleksiyonlar | Dizi, Dizin, Yöney, Eşlem, Küme, Dizik, EsnekDizik, Kuyruk, Yığın, MiskinDizin, aralıklar |
| 15-yazi-sayi-matematik | Yazı/Harf uzantıları (Türkçe İ/ı dahil), Sayı/Kesir, Matematik, Belki, Bölümselİşlev, rastgele |
| 16-yoney-nokta | Nokta, Dikdörtgen, Yöney2B aritmetiği ve ayrıştırma |
| 17-gelecek-zaman | Gelecek, zamanTut, BuAn/buAn, durakla, artalandaOynat |
| 18-hatalar | dene/yakala/sonunda, yedi hata türü |
| 19-anahtar-kelimeler | tanım dez den eğer yoksa için eşle durum getir yeni örtük sınıf nesne özellik tür yayar birlikte baskın miskin geriDön yineleDoğruKaldıkça ver yok; Türkçe harfli tanımlayıcılar |
| 20-kucuk-oyun | top+raket oyun döngüsü: çarpışma, sekme, sahne kenarı, skor yazısı |
| 21-performans-cok-nesne | 300 durağan resim + canlandırma → iz pişirme (kojojs-dev #6) yolu |
| 22-uc-yildiz | üç yıldız benzetimi (ikojo W7AI4IV): iz bırakan canlandırma, çizim toplama (#5) |

## Bu koşuda öğrenilenler (masaüstüyle farklar)

- `Dizi(1)(5)` **fırlatmaz**: `Dizi.apply` varargs'ı olduğu gibi döndürüyor (Scala.js `WrappedVarArgs`),
  dizin denetimi yok. `Dizin` (List) fırlatır. 18-hatalar bu yüzden Dizin kullanır.
- `sinüs`/`kosinüs` **radyan** alır (masaüstüyle aynı); `dereceye`/`radyana` ile çevrilir.
- `kenarPayınıÇıkar` = `stripMargin`; `trim` için `kısalt`.
- `Eşlem` değişebilir (mutable) bir eşlemdir: `eşEkle` / `+=` yerinde ekler; `işle` sonucu düz `mutable.Map`.
- Sahne kenarları (`çizSahne`) kaplumbağa resmidir; geometrileri kaplumbağa kuyruğu bitince oluşur.
  Sahneye bağlı çarpışma denetimleri çizimden hemen sonra değil, birkaç kare sonra yapılmalı.
- `dokunuyorMu(resim) { … }` geri çağrımı bu koşuda yalnız üst düzeyden çağrılınca çalıştı;
  `canlandır` içinden çağrılanı gelmedi (bkz. 09 çıktısı) -- kojojs-dev'de bakılacak.
- `fareKonumu` fare hiç gelmemişse (-999999, -999999) döner.
- `sonuclar/gorseller/05-gradyanlar.png` bilinen bir kusuru gösterir: doğrusal gradyan uç noktasından
  sonra sabitlenmek yerine başa sarıyor (PIXI 5 `GraphicsGeometry.updateBatches` doku sarmasını REPEAT'e
  çeviriyor; kojojs-core #11 incelemesi, düzeltme kojojs-dev'de). Düzeltme gelince bu görüntü değişmeli.
