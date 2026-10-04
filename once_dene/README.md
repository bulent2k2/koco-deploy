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
  tarayici/ornekle.js     tek betiği koşarken PIXI'nin iç durumunu ZAMAN İÇİNDE örnekler (aşağıya bak)
  tarayici/editor.js      GERÇEK editör sayfasını, /resultframe'i ve /api kapısını sınar (`-e`; aşağıya bak)
  tarayici/package.json   playwright bağımlılığı (npm install; npx playwright install chromium)
  sonuclar/derleme.tsv    son derleme sonucu (betik, durum, özet)
  sonuclar/calisma.tsv    son tarayıcı sonucu (durum, süre, pixi, çizim, kare, çocuk, doku, hata, uyarı, çıktı)
  sonuclar/editor.tsv     son editör yolu sonucu (sınama, durum, ayrıntı); yalnız `-e -g` ile
  sonuclar/gorseller/     betik başına tuval görüntüsü -- yerelde üretilir, git'e girmez (her koşuda değişirdi)
```

## Kullanım

```sh
./dene.sh                                    # canlı sunucuya karşı yalnız derleme
KOCO=http://localhost:7860 ./dene.sh -t      # yerel konteyner: derleme + tarayıcı
./dene.sh -t -g                              # sonuçları sonuclar/ altına yaz (TSV + görüntüler)
./dene.sh -t betikler/05-gradyanlar.kojo     # tek betik
./dene.sh -t -e                              # + editör yolu sınaması (kapının görmediği yerler)
./dene.sh -h                                 # seçenekler (-s saniye, -k kitaplık dizini)
```

Tarayıcı koşusu için bir kez: `cd tarayici && npm install && npx playwright install chromium`.

**Node 20 ya da üstü şart.** Playwright daha eski bir Node'da yüklenmez (`You are running Node.js
16.16.0. Playwright requires Node.js 20 or higher.`). Önce `node -v` bakın. Varsayılan `node`
eskiyse (bu makinede `/usr/local/bin/node` v16.16.0'dı) Homebrew'daki yenisini o komut için öne alın:

```sh
PATH=/usr/local/opt/node@26/bin:$PATH KOCO=http://localhost:7860 ./dene.sh -t -g
# ya da bu kabuk oturumu boyunca:  export PATH=/usr/local/opt/node@26/bin:$PATH
```

Kurulum da aynı Node ile yapılmalı: `npx playwright install chromium` eski Node'da yukarıdaki iletiyle
durur. Chromium macOS'ta `~/Library/Caches/ms-playwright` altına iner. (Eski `dene.sh` bu durumu
"playwright bulunamadı" diye gösteriyordu: paket kurulu olsa bile `require` Node sürümünden patlıyor,
ve ileti yanlış yöne çekiyordu. Şimdi Node sürümünü de yazıyor.)

Kitaplıklar (`pixi.min.js`, `jsts.min.js`, `howler.min.js`) ve kaplumbağa simgesi ilk koşuda
`$KOCO/assets/...` adresinden `tarayici/kitaplik/` ve `tarayici/assets/` altına indirilir
(git'e girmez); böylece tarayıcı **canlının sunduğu** PIXI sürümüyle koşar. Yerel bir
editör klonundan almak için `-k <editor>/server/src/main/assets/javascript`.

Router derleme sonuçlarını kaynak özetiyle önbelleklediği için `dene.sh` her betiğin başına zaman
damgalı bir yorum koyar; böylece her koşu gerçekten derlenir (yeni çalışma zamanı, eski JS değil).

### Yerel router + derleyici sunucusuna karşı koşmak

Bir kojojs-dev dalını canlıya çıkmadan denemek için `kojojs-core`'dan yerel bir
router (8880) ve derleyici sunucusu kurulabilir. Dört tuzak var:

1. **Türkçe jar'lar staging'de eziliyor.** `compilerServer/stage` stok Maven
   jar'larını koyuyor; yamalı derleyiciyi geri koymak gerek:
   ```sh
   D=compiler-server/target/universal/stage/lib
   P=<kojo>/scala-tr/build/pack/lib
   cp $P/scala-compiler.jar $D/org.scala-lang.scala-compiler-2.13.18.jar
   cp $P/scala-reflect.jar  $D/org.scala-lang.scala-reflect-2.13.18.jar
   ```
2. **Kütüphane listesi.** Router `extLibs`'i `http://localhost:9000/libraries/2.13`
   adresinden (editörden) okuyor; editör ayakta değilse liste boş kalıyor, ama
   router `defaultLibs`'i (scalajs-dom, scalatags) yine de her isteğe ekliyor ve
   derleyici `Library ... is not allowed` diyor. Router'a boş bir liste dosyası
   vermek yetiyor:
   ```sh
   echo '[]' > /tmp/libs.json
   ./router/target/universal/stage/bin/scalafiddle-router '-Dfiddle.extLibs={"2.13":"file:/tmp/libs.json"}'
   ```
   (`defaultLibs`'i boşaltmak ÇÖZÜM DEĞİL: scalajs-dom olmadan çalışma zamanı
   bağlanmıyor -- "Cannot access module for non-module org.scalajs.dom.package$".)
3. **Router gzip yanıt veriyor**; elle `curl` ile derlerken `--compressed` şart.
4. **Süreç öldürürken `pkill -f` KULLANMAYIN**: kalıp kendi kabuğunuzla da eşleşip
   oturumu düşürüyor. Yalnız java süreçlerini seçin:
   ```sh
   ps -eo pid,comm,args | awk '$2=="java" && /scalafiddle-core/ {print $1}' | xargs -r kill
   ```

Sonra: `KOCO=http://127.0.0.1:8880 ./dene.sh -t`

Tarayıcı tarafında, Playwright'ın kendi indirdiği sürüm kapta yoksa hazır olanı
gösterin: `KOCO_CHROMIUM=/opt/pw-browsers/chromium`. (kojojs-dev'in kendi
tarayıcı testleri için karşılığı `KOJO_CHROME=/opt/pw-browsers/chromium ./test-tarayici.sh`.)

### Geçici görünmezlikleri yakalamak: `ornekle.js`

`dene.sh` "betik geçti mi" sorusuna bakar; betik sonunda `TAMAM` yazdığı sürece
arada bir şeyin **geçici olarak kaybolmuş** olduğunu göremez. `ornekle.js` tam
buna bakar -- tek bir derlenmiş betiği koşarken PIXI'nin iç durumunu 0,7 sn'de bir
örnekler:

```sh
KOCO_CHROMIUM=/opt/pw-browsers/chromium node tarayici/ornekle.js sonuclar/js/05-gradyanlar.js 12
```

Her örnekte kaplumbağa yolundaki Graphics için `b` (`geometry.batches.length`) ve
`p` (`graphicsData.length`) yazılır. **`b=0` iken `p>0` ise şekiller var ama PIXI
o kareyi bomboş çiziyor** -- çıktıdaki `korOrnek` bu örneklerin sayısıdır.
PIXI 5'in `validateBatching`'i geçersiz dokulu tek bir parça görünce Graphics'in
TAMAMI için batch kurmaz; kaplumbağanın bütün çizimi tek Graphics olduğu için
uzaktan yüklenen bir `DokumaBoya` beklenirken önceki her şey de kaybolur
(kojojs-dev#40 böyle bulundu ve böyle doğrulandı).

Tuvalden piksel okumak bu ölçüm için güvenilir değil: başsız swiftshader'da
Playwright'ın öğe ekran görüntüsü canlı durumu yansıtmıyor (ölçüldü: farklı
sürümler aynı görüntüyü verdi) ve `renderer.plugins.extract` tamamen saydam
dönüyor. `batches.length` ise doğrudan PIXI'nin kendi kararı.

Çıkış kodu: derleme ya da çalışma zamanında "kaldı"/"eksik" varsa 1, sunucu hatası varsa 2.
Dağıtım akışında `build.sh` → `docker run` → `KOCO=http://localhost:7860 ./dene.sh -t -g`
→ yeşilse `fly deploy` şeklinde kullanılması düşünüldü.

### Tuzak: Türkçe anahtar kelimeler değişken adı olamaz

Yamalı derleyici (`kojo/scala-tr`) Scala'nın **her** anahtar kelimesine bir Türkçe
karşılık tanımlıyor, ve o karşılıklar da anahtar kelime -- yani betikte (ve sonda
kodunda) **değişken, parametre ya da yöntem adı olarak kullanılamıyorlar**. Günlük
Türkçede çok geçen sözcükler olduğu için bu tuzağa düşmek kolay; hata iletisi de
("illegal start of simple pattern") sebebi söylemiyor.

En sık çarpılanlar:

| kaçın | çünkü | yerine |
|---|---|---|
| `son` | `final` | `bitiş`, `sonuncu` |
| `yeni` | `new` | `yenisi`, `taze` |
| `üst` | `super` | `yukarıdaki`, `üstü` |
| `yoksa` | `else` | `boşsaÖbürü`, `değilse` |
| `tür` | `type` | `türü`, `çeşit` |
| `bu` | `this` | `bunu`, `şu` |
| `dene` | `try` | `deneme`, `sonda` |
| `durum` | `case` | `durumu`, `hâl` |
| `yok` | `null` | `yoklama`, `boş` |
| `doğru` / `yanlış` | `true` / `false` | -- (zaten değer) |

Tam liste: `kojo/src/main/scala/net/kogics/kojo/lite/i18n/tr/dict.scala`
içindeki `turkishKeywords` (40 sözcük) ve `keywordTranslation`.

Aynı tuzak **kabuk betiklerinde de var ama başka sebeple**: bash Türkçe karakterli
değişken adı kabul etmiyor, o yüzden `dene.sh` ve `ornekleri-dogrula.sh` içindeki
değişken adları ASCII.

## Durumlar

| aşama | durum | anlamı |
|---|---|---|
| derleme | geçti / kaldı / sunucu | derleyici hata verdi (kaldı) ya da HTTP 200 gelmedi (sunucu: betiğin değil sunucunun sorunu) |
| çalışma | geçti | sayfa hatası yok **ve** betik `TAMAM` yazdı |
| çalışma | kaldı | sayfa hatası: fırlayan kural dışı durum, `gerekli(...)` tutmadı, yakalanmamış söz (Promise); ya da çıktıda `HATA:` satırı |
| çalışma | eksik | hata yok ama `-s` süresinde (varsayılan 20 s) `TAMAM` yazılmadı: betik takıldı ya da beklenen kare sayısına gelmedi |
| editör | geçti / kaldı | sınama tuttu / tutmadı (ayrıntı `sonuclar/editor.tsv`'de ya da ekranda `✗` satırında) |
| editör | eksik | bir **önkoşul** tutmadığı için ölçülemedi. Başarısızlık sayılır: ölçülmeyen şey geçmiş sayılmaz |

Betikler kendini denetler: `gerekli(koşul, ileti)` tutmazsa fırlayan hata sayfa hatası olur.
Her betik sonunda `satıryaz("TAMAM: ...")` yazar; canlandırmalı olanlar belli bir kare sayısında
`durdur()` deyip öyle yazar. Koşucu `TAMAM` ya da `HATA:` görünür görünmez (ya da ilk sayfa hatasında)
geçer, `-s` yalnız üst sınırdır; geçen süre `süre` sütununa yazılır. **Bir sözün (Gelecek) içindeki
`gerekli` sayfa hatası üretemez** -- başarısız bir Future olur ve kaybolur; bu yüzden söz denetimleri
`onComplete` ile `HATA: ...` satırı yazar (17-gelecek-zaman böyle yapar).

Ağ/medya yüklenememesi (dosya:// koşusunda `/media/...` yok) **uyarı** sayılır, kaldı değil;
`sonuclar/calisma.tsv` uyarılar sütununda görünür.

## Editör yolu sınaması (`-e`)

Kapı derlenmiş betiği **kendi `sahne.html`'inde** koşturur; yani editör sayfasını, `/resultframe`'in
sunucu başlıklarını ve `/api` kapısını hiç görmez; bu üç yerdeki bir gerileme 22/22'yi bozmaz.
Somut örnek kojojs-editor#51 (ilk "Çalıştır"da ses yok): v80 ve v81'in iki "düzeltmesi" kapıyı 22/22 ile
geçip canlıya çıktı, belirti sürdü ve ancak elle ölçülünce görüldü. Öbür ikisi aynı kör noktada:
#45 (çocuğun kodu editörle aynı kökende koşuyordu) ve #47 (`/api`'ye başka bir sitenin formu
ulaşabiliyordu). `-e` bunları `tarayici/editor.js` ile gerçek editör sayfasında, gerçek sunucu
başlıklarıyla sınar. Node 20+ gerekir (yukarı bak).

```sh
KOCO=http://127.0.0.1:7860 ./dene.sh -t -e -g          # kapı + editör yolu, sonuçları yaz
KOCO=https://ikojo.fly.dev ./dene.sh -e betikler/05-gradyanlar.kojo   # editör yolu (+ yalnız bir derleme)
node tarayici/editor.js http://127.0.0.1:7860           # yalnız sınamalar (~15 sn, derleyici sıcaksa); stdout'a TSV satırları
```

| grup | sınamalar | neyi korur |
|---|---|---|
| önkoşul | `editör-sayfası-açılıyor`, `derleyici-adresi-aynı-köken` | sayfa kendi derleyicisini sınanan adreste arıyor (aşağıdaki tuzak) |
| `/resultframe` (#45) | `-sandbox-başlığı`, `-opak-köken`, `-betik-koşuyor`, `-varlıklar-opak-kökenden`, `-pixi-yükleniyor` | kod editörün kökeninde koşmaz (`window.origin === "null"`), ama varlıkları CORS ile yükleyebilir |
| ilk ve ikinci koşu (#51) | `ilk-koşu-kod-dalı`, `-allow-özniteliği`, `-sandbox-özniteliği`, `-autoplay-izni`, `-tek-belge-isteği`, `ikinci-koşu-autoplay-izni`, `-tek-ek-istek`, `editör-sayfa-hatası-yok` | taze sayfada İLK "Çalıştır"da çerçevede `allowsFeature("autoplay") == true` ve `/resultframe`'e TEK belge isteği |
| `/api` (#47) | `api-başlıksız-…`, `-yanlış-değer-…`, `-opak-köken-reddediliyor`, `-doğru-başlık-kapıdan-geçiyor`, `-cors-ön-uçuşu-yok` | `X-Requested-With: koco` şart, `Origin: null` olamaz, CORS'a açık değil |

`api-doğru-başlık-kapıdan-geçiyor` yalnız 403 **olmadığını** ölçer (yol uydurma, gövde boş; kapıyı
geçince 500 de dönebilir). API'nin kendi sağlığı hakkında bir şey söylemez.

**Tuzak: yerel konteynerde adres.** Sayfa derleyici adresini `PUBLIC_URL`'den (yoksa
`http://localhost:7860`) gömer. Başka bir adresten açarsanız ("Çalıştır") derleme isteği boş yere gider
ve `Sunucuya ulaşılamadı` der. `localhost` ile `127.0.0.1` ayrı kökenlerdir. Sınama bunu
`derleyici-adresi-aynı-köken` ile yakalar (sekiz koşu sınaması `eksik` kalır, 120 sn takılmaz):

```sh
docker run -d -p 7870:7860 -e PUBLIC_URL=http://127.0.0.1:7870 -e SCALAFIDDLE_SECRET=yerel koco
KOCO=http://127.0.0.1:7870 ./dene.sh -t -e
```

**Nasıl doğrulandı, sınırı ne.** Canlıya (v82) karşı 21/21. Sandbox ve `/api` kapısından ÖNCEki bir
imajla (editor `265f54c`) 7 sınama kırmızı: sandbox başlığı, opak köken, `allow`, `sandbox`
özniteliği (`allow-same-origin` var) ve `/api`'nin üç reddi. Ama:

- Autoplay sınamaları o eski imajda **geçer**: aynı kökenli çerçevede autoplay zaten varsayılan olarak
  açık, #51 yalnız opak kökenli çerçevede çıkar. Kırmızıya döndüğü ayrıca gösterildi: istemci JS'inden
  `autoplay` çıkarılınca (Playwright `route` ile, sunucuya dokunmadan) `-allow-özniteliği` ve iki
  `-autoplay-izni` kırmızı oldu.
- `-tek-belge-isteği` ve `-tek-ek-istek` sayaçlarının kırmızısı **gösterilemedi**: #52'nin iki istek
  davranışını üreten bir imaj elinde yoktu; sayaç yalnız geçen tarafta (değer 1) doğrulandı.

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
| 08-canlandirma | canlandır+durdur, canlandırYenidenÇizerek, tepkiVer/canlan (her kare, sayaçla), davran (bir kez), ekranTazelemeHızınıGöster, kareSüresi |
| 09-carpisma | çarpışıyorMu/çarptıMı/çarpışma/çarpışmalar, sınırları/içeriyorMu/uzaklık, çizSahne, sahnedenSek/resimdenSek, dokunuyorMu |
| 10-klavye-fare | tuşaBasınca/tuşuBırakınca/tuşBasılıMı, resim fare olayları, fareKonumu, kumandaKolu |
| 11-ses | sesMp3üÇal, müzik çal/kapat/döngü, yeniMp3Çalar, notaÇalgısınıKur/notaÇal (howler) |
| 12-imge-giysi | Resim.imge (zarflı dahil), giysili kaplumbağa, giysileriKur/birsonrakiGiysi/giysiyiBüyült |
| 13-sahne-tuval | artalanıKur (düz/dik/yatay), tuvalAlanı/tuvalSınırları, eksen/ızgara, yaklaş/kaydır/döndür, bakış açıları, tuvalBoyutlarınıKur |
| 14-koleksiyonlar | Dizi, Dizin, Yöney, Eşlem, Küme, Dizik, EsnekDizik, Kuyruk, Yığın, MiskinDizin, aralıklar |
| 15-yazi-sayi-matematik | Yazı/Harf uzantıları (Türkçe İ/ı dahil), Sayı/Kesir, Matematik, Belki, Bölümselİşlev, rastgele |
| 16-yoney-nokta | Nokta, Dikdörtgen, Yöney2B aritmetiği ve ayrıştırma |
| 17-gelecek-zaman | Gelecek (onComplete ile kanala bağlı denetim), zamanTut, BuAn/buAn, durakla, artalandaOynat |
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
- Gradyan sarma kusuru (kojojs-core #11 incelemesi) kojojs-dev #35 ile kapandı: 05'in görüntüsünde
  doğrusal gradyanlar ucunda sabitleniyor. Sonuçlar 3ba6992 (#37) senkronuyla alındı.
- `fareKonumu` fare hiç gelmemişse (-999999, -999999) döner.
- `sonuclar/gorseller/05-gradyanlar.png` bilinen bir kusuru gösterir: doğrusal gradyan uç noktasından
  sonra sabitlenmek yerine başa sarıyor (PIXI 5 `GraphicsGeometry.updateBatches` doku sarmasını REPEAT'e
  çeviriyor; kojojs-core #11 incelemesi, düzeltme kojojs-dev'de). Düzeltme gelince bu görüntü değişmeli.
