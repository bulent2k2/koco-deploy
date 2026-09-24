# Koco — Türkçe Kojo, tarayıcıda

[Kojo](http://www.kogics.net/kojo)'nun Türkçe sürümü. Kaplumbağa grafiklerini
Türkçe komutlarla yazarsınız:

```scala
yinele(4) {
  ileri(100)
  sağ()
}
```

**Canlı:** https://ikojo.fly.dev

## Medya (`/media/...`)

Masaüstü Koco betikleri sesleri ve giysileri `Ses.vuruş` = `/media/collidium/hit.mp3`
gibi sabitlerle kullanır. `build.sh` kojojs-dev'deki `medya/` dizinini
`stage/medya` → `/app/medya` olarak imaja alır; `nginx.conf` `/media/` isteklerini
oraya bağlar (7 gün önbellek). Yeni dosya eklemek için kojojs-dev `medya/guncelle.sh`.

## Mimari

Tek konteynerde üç JVM servisi ve önlerinde nginx:

| Servis | Port | İşi |
|---|---|---|
| editör (Play) | 9000 | arayüz, yazılımcık kaydetme, GitHub girişi |
| router (akka-http) | 8880 | derleme isteklerini yönlendirir, gömülü görünüm |
| compilerServer × N | — | Scala derleyicisi + Scala.js linker; router'a WebSocket ile bağlanır. `build.sh` varsayılan olarak (KOCO_TOOLCHAIN=tr) scala-compiler/scala-reflect'i kojo/scala-tr'nin **Türkçe anahtar kelimeli** kopyalarıyla değiştirir |
| nginx | **7860** | tek genel port |

nginx yol ayrımı: `/compile`, `/complete`, `/embed`, `/codeframe`,
`/compileResult`, `/cache/*` → router; kalan her şey → editör.

Tarayıcı hem editöre hem router'a konuşuyor. nginx ikisini **aynı origin**
altında birleştirdiği için yapılandırma çok basitleşiyor.

## Kurulum / dağıtım

İki JDK gerekiyor (imajdaki çift JRE'nin derleme zamanı karşılığı):
`kojojs-core` Java 9+ ister (compiler-server `InputStream.readAllBytes()`
kullanıyor), `kojojs-editor` ise sbt 0.13 + Play 2.6 ile Java 8. `build.sh`
adım başına seçiyor:

```sh
export KOCO_JDK_CORE=/path/to/jdk11      # ya da 17/21
export KOCO_JDK_EDITOR=/path/to/jdk8
export KOCO_SCALA_TR=/path/to/kojo/scala-tr/build/pack/lib   # yan yana değilse
```

Üçü de isteğe bağlı. macOS'ta JDK'ler boş bırakılırsa `/usr/libexec/java_home`
listesinden javac'lı ilk uygun sürüm seçilir (core: 11, yoksa 9+; editör: 8);
sürüm tutmuyorsa `build.sh` sbt'yi başlatmadan durur. scala-tr için yan yana
klon yoksa `~/src/kojo/git/master/scala-tr/build/pack/lib` denenir.

```sh
./build.sh                 # üç servisi paketler -> stage/ (git'e girmez)
docker build -t koco .     # yerel test için
docker run --rm -p 7860:7860 --memory 4g koco
KOCO=http://localhost:7860 once_dene/dene.sh -t -g   # dağıtım öncesi deneme: 22 betik derlenir + tarayıcıda koşar (bkz. once_dene/README.md)
fly deploy                 # Fly.io'ya
```

`stage/` **kasıtlı olarak** git'te yok: `build.sh`'ın ürettiği 214 MB'lık türev.
Kaynaktan Docker içinde derleyemiyoruz: `kojojs-editor` hâlâ sbt 0.13 ve
`plugins.sbt`'si artık ölü olan `http://repo.typesafe.com` çözümleyicisine
bakıyor (`kojojs-core` Faz 3'te sbt 1'e geçti ve Maven Central'dan çözülüyor) —
paketleme sıcak bir `~/.ivy2` ile yerelde yapılmalı.

`build.sh` paketlemeden önce kaynak klonlarını denetler: `kojojs-core` ve
`kojojs-editor` `master` dalında, temiz ve `origin`'in gerisinde değilse devam
eder; `KOCO_TOOLCHAIN=tr` için scala-tr jar'larının geldiği klon (yan yana
`kojo` ya da yedek yol, hangisi bulunduysa) yalnız temizlik ve güncellik için
denetlenir — dal adı zorlanmaz (kojo'da yamalı 2.13.18 kendi dalında), kirlilik
yalnız `scala-tr` ağacında aranır, ayrık HEAD'de güncellik uyarıyla atlanır.
Aksi halde durur. Bilerek eski ya da yerel bir sürüm dağıtmak için
`KOCO_SKIP_GIT_CHECK=1`.

## Ortam değişkenleri

| Değişken | Etki |
|---|---|
| `GITHUB_CLIENT_ID` / `_SECRET` | GitHub girişi (yoksa giriş düğmesi çalışmaz) |
| `SILHOUETTE_KEY` | oturum imzalama; verilmezse rastgele üretilir ve **her yeniden başlatmada oturumlar düşer** |
| `APPLICATION_SECRET` | Play gizli anahtarı |
| `SCALAFIDDLE_SECRET` | router ↔ compilerServer `/compiler` kapısının ve `/durum` tanı ucunun anahtarı; verilmezse her açılışta rastgele üretilir (iki süreç de aynı açılıştan aldığı için sorun değil). **`/durum` konteyner DIŞINDAN yoklanacaksa** (ör. kapasiteyi izleyen bir health check) kalıcı bir değer şart: `flyctl secrets set SCALAFIDDLE_SECRET=…` — rastgele değerle dışarıdaki hiçbir şey o uca kimlik gösteremez |
| `COMPILER_INSTANCES` | eşzamanlı derleyici süreci sayısı (varsayılan 2) |
| `SCALAFIDDLE_COMPILER_RECYCLE_AFTER` | bir derleyici bu kadar cevaptan sonra taze bir JVM'le değiştirilir (varsayılan 0 = kapalı; taze derleyici ısınmadan açılmamalı, bkz. `start.sh`). Gözcü şart: router çıkan derleyicinin yeniden başlatılacağını varsayar (bkz. `start.sh`) |
| `SCALAFIDDLE_COMPILER_STALL_TIMEOUT` | bir derleme bundan uzun sürerse derleyici takılmış sayılıp değiştirilir (router öntanımlısı `180s`; `0` = kapalı) |
| `KOCO_GOZCU_ARALIK` | derleyici gözcüsünün yoklama sıklığı, sn (varsayılan 5) |
| `KOCO_GOZCU_ASGARI_OMUR` | bundan kısa yaşayan derleyici "hızlı çöküş" sayılır, sn (varsayılan 60) |
| `KOCO_GOZCU_GERI_TABAN` / `_TAVAN` | hızlı çöküşte üstel geri çekilmenin tabanı ve tavanı, sn (5 / 300) |
| `KOCO_GOZCU_NICE` | derleyicilerin nice değeri (varsayılan 10; bkz. `start.sh`) |
| `KOCO_DERLEYICI_KOMUTU` | gözcünün başlattığı komut; **yalnız sınama için** (varsayılan `/app/compiler/bin/scalafiddle-core`) |
| `PUBLIC_URL` | genel adresi elle belirle; yoksa `SPACE_HOST` / `FLY_APP_NAME` / yerelden türetilir |
| `KOCO_ORNEKLER` | editörün `/ornek/<yol>` ile sunduğu örnek dizini (imajda `/app/ornekler`) |

## Örnek betikler (`/ornek/<yol>`)

`build.sh`, `kojojs-dev/ornekler` dizinini (ikojo örnekleri + `masaustu/` altındaki
masaüstü Koco betikleri; yalnız `.kojo`, `.kojo.installed`, `README.md`,
`KAYNAK.txt`, `*.tsv`) `stage/ornekler` → `/app/ornekler` olarak imaja alır ve
`start.sh` editöre `KOCO_ORNEKLER=/app/ornekler` verir. Editör
`/ornek/01-ilk-adimlar.kojo` ya da
`/ornek/masaustu/src/main/resources/samples/tr/fern.kojo` gibi bir adresi, dosyanın
`// #yükle` satırlarını genişletip düzenleme penceresinde açar (kojojs-editor
`koco.OrnekYukleyici`). Bu yüzden `kojojs-dev` klonu da `build.sh`'ın klon
denetimine girer (`master`, `ornekler/` altı temiz).

## Tuzaklar

Bu kurulumu yeniden üretecek olan için, pahalıya mal olmuş dersler:

- **`SCALAFIDDLE_LIBRARIES_URL` iki serviste çakışıyor.** Editör bir dosya adı,
  router bir JSON haritası bekliyor. Global ayarlarsan editörün `Librarian`'ı
  `None.get` ile çöker. **Hiç ayarlama.**
- **`akka.actor.deployment./compilerRouter` ölü yapılandırma.** Scala kodunda
  kullanılmıyor. Eşzamanlılık, compilerServer **süreç** sayısıyla belirleniyor;
  router hepsi meşgulse kuyruğa almadan *"No suitable compiler available"* döner.
- **Yığın sınırlarının toplamı makine belleğini aşmamalı.** Ölçülen RSS'e göre
  ayarlarken toplamı kontrol etmezsen derleme sırasında 500'ler alırsın.
- **Silhouette 5.0.1 GitHub profilini `?access_token=` ile çekiyor**, GitHub bunu
  2021'de kaldırdı. `HeaderAuthGitHubProvider` (kojojs-editor'de) bunu düzeltiyor.
- **Aynı origin CORS'u kurtarmıyor**: tarayıcı same-origin POST'ta bile `Origin`
  gönderiyor. curl göndermediği için curl testi bu hatayı yakalamaz.
- **Veritabanı şeması kendiliğinden kurulmuyor.** `tables.sql` bir PostgreSQL
  *kurulum* betiği (`CREATE ROLE`/`CREATE DATABASE`/`GRANT`) ve Play evolutions
  kurulu değil, yani H2 boş açılıyor; GitHub girişi
  `Table "user" not found` ile patlıyor. `schema-h2.sql` + H2'nin
  `INIT=RUNSCRIPT`'i bunu çözüyor. Veri `/data` Fly volume'ündeki H2 dosyasında
  kalıcı (`start.sh`, `H2_URL`); çok makineli kurulum için
  `SCALAFIDDLE_SQL_URL` ile gerçek Postgres gerekir.
- **Port bekleme zaman aşımı ölümcül olmamalı.** Fly'ın paylaşımlı çekirdeğinde
  editör 100+ sn'de açılabiliyor; `exit` edersen makine sonsuz döngüye girer.

Kaynak: [kojojs-dev](https://github.com/bulent2k2/kojojs-dev) ·
[kojojs-core](https://github.com/bulent2k2/kojojs-core) ·
[kojojs-editor](https://github.com/bulent2k2/kojojs-editor)
