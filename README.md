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

## Mimari

Tek konteynerde üç JVM servisi ve önlerinde nginx:

| Servis | Port | İşi |
|---|---|---|
| editör (Play) | 9000 | arayüz, yazılımcık kaydetme, GitHub girişi |
| router (akka-http) | 8880 | derleme isteklerini yönlendirir, gömülü görünüm |
| compilerServer × N | — | Scala derleyicisi + Scala.js linker; router'a WebSocket ile bağlanır |
| nginx | **7860** | tek genel port |

nginx yol ayrımı: `/compile`, `/complete`, `/embed`, `/codeframe`,
`/compileResult`, `/cache/*` → router; kalan her şey → editör.

Tarayıcı hem editöre hem router'a konuşuyor. nginx ikisini **aynı origin**
altında birleştirdiği için yapılandırma çok basitleşiyor.

## Kurulum / dağıtım

```sh
./build.sh                 # üç servisi paketler -> stage/ (git'e girmez)
docker build -t koco .     # yerel test için
docker run --rm -p 7860:7860 --memory 4g koco
fly deploy                 # Fly.io'ya
```

`stage/` **kasıtlı olarak** git'te yok: `build.sh`'ın ürettiği 214 MB'lık türev.
Kaynaktan Docker içinde derleyemiyoruz, çünkü her iki `plugins.sbt` de artık ölü
olan `http://repo.typesafe.com` çözümleyicisine bakıyor — paketleme sıcak bir
`~/.ivy2` ile yerelde yapılmalı.

## Ortam değişkenleri

| Değişken | Etki |
|---|---|
| `GITHUB_CLIENT_ID` / `_SECRET` | GitHub girişi (yoksa giriş düğmesi çalışmaz) |
| `SILHOUETTE_KEY` | oturum imzalama; verilmezse rastgele üretilir ve **her yeniden başlatmada oturumlar düşer** |
| `APPLICATION_SECRET` | Play gizli anahtarı |
| `COMPILER_INSTANCES` | eşzamanlı derleyici süreci sayısı (varsayılan 2) |
| `PUBLIC_URL` | genel adresi elle belirle; yoksa `SPACE_HOST` / `FLY_APP_NAME` / yerelden türetilir |

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
- **Port bekleme zaman aşımı ölümcül olmamalı.** Fly'ın paylaşımlı çekirdeğinde
  editör 100+ sn'de açılabiliyor; `exit` edersen makine sonsuz döngüye girer.

Kaynak: [kojojs-dev](https://github.com/bulent2k2/kojojs-dev) ·
[kojojs-core](https://github.com/bulent2k2/kojojs-core) ·
[kojojs-editor](https://github.com/bulent2k2/kojojs-editor)
