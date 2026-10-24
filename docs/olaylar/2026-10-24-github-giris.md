# Olay: GitHub girişi `TooLongFrameException` ile düşüyordu (24 Ekim 2026)

**Durum:** giderildi (v108, koco-deploy #102). Altta yatan neden hâlâ bilinmiyor.

## Etki

GitHub ile giriş, `/authenticate/github?code=…` adımında şu hatayla düşüyordu:

```
A server error occurred: Unexpected exception[TooLongFrameException: HTTP header is larger than 8192 bytes.]
```

Günlükte 24 Ekim 13:39–13:42 UTC arasında birkaç deneme var; düzeltme 14:27 UTC'de v108 ile
çıktı ve kullanıcı girişin çalıştığını doğruladı. Sorunun ne zaman başladığı ve başkasını
etkileyip etkilemediği bilinmiyor: önceki bir başarılı girişin kaydı yok.

## Doğrudan neden (kanıtlı)

Editör girişi tamamlamak için GitHub'a iki çağrı yapıyor (belirteç değişimi ve
`api.github.com/user` profili). GitHub'dan gelen **yanıtın** başlıkları, Play'in gömülü HTTP
istemcisinin (AHC/Netty) 8192 baytlık varsayılan sınırını aştı. Hata gelen isteğin değil,
**giden çağrının yanıtının** sınırıydı.

Kanıtlar:

- Günlükteki yığın izi `play.shaded.ahc.io.netty…HttpClientCodec` ve `SslHandler` üzerinden
  geliyor (yanıt okuma yolu).
- Editör paketindeki aynı gömülü AHC ile, 9000 baytlık başlık döndüren sahte bir sunucuda
  hata birebir üretildi (`HTTP header is larger than 8192 bytes`); sınır yükseltilince 200 döndü.
- Düzeltme canlıda, gerçek GitHub girişinde doğrulandı.

## Altta yatan neden (bilinmiyor)

GitHub'ın hangi yanıtında ve hangi başlıkla 8 KB'ı aştığı görülmedi. Sahte belirteçle yapılan
isteklerde başlıklar yaklaşık 900 bayttı, yani gerçek yanıt farklıydı. Olası açıklamalar,
hiçbiri doğrulanmadı: GitHub'ın başlıkları büyütmesi; bu hesaba ya da çıkış IP'sine özgü bir
yanıt (örneğin uzun CSP'li bir hata sayfası); ya da hep bu boyutta olup bu yola hiç
girilmemiş olması.

## Düzeltme

`start.sh`, editör JVM'ine şu sistem özelliğini veriyor:

```
-Dplay.shaded.ahc.org.asynchttpclient.httpClientCodecMaxHeaderSize=65536
```

Ad gölgeli (`play.shaded.ahc.…`) olmak zorunda; gölgesiz `org.asynchttpclient.…` etkisiz.
Play'in `play.ws.ahc.*` ayarları bu alanı açmıyor. Ayar JVM geneline uygulanıyor (editördeki
tüm giden WS çağrıları 64 KB'a kadar başlık kabul eder).

## Ne iyi gitti

- Sorun aynı gün bulundu: yığın izi doğru katmanı gösterdi, hata yerelde yeniden üretildi,
  bağımsız inceleme yapıldı, düzeltme gerçek girişle doğrulandı.

## Ne kötü gitti

1. **Yanlış ilk tahmin.** İletideki "Netty" sözcüğünden gelen isteğin sınırı varsayıldı ve
   `play.server.netty.*` ayarına yönelindi. Editör akka-http çalıştırıyor, o ayar ölüydü.
   Yığın izine bakmak bunu hemen gösterdi; değişiklik commit'e girmeden geri alındı.
2. **Tespit kullanıcıdan geldi.** Alarm yok; sürüm kapısı girişi denemiyor (gerçek GitHub
   kimliği gerektirdiği için denemesi mümkün de değil).
3. **Kök neden yakalanamadı.** `fly logs` eski kayıtları attığı için, hata bildirildiğinde
   hangi çağrının şiştiği artık görünmüyordu.

## Yapılacaklar / yapılanlar

- [x] `start.sh` bayrağı (#102).
- [x] README "Tuzaklar"a not (bu PR).
- [ ] Editörde giriş adımlarının hangisinde düştüğünü ve profil yanıtının başlık boyutunu
      günlüğe yazan kayıt (kojojs-editor PR'ı). Belirteç değişiminin yanıtı Silhouette'in
      içinde okunuyor; bunun başlık boyutu uygulama katmanından **görülemez** (kod, yanıt
      ayrıştırılmadan önce düşüyor), yalnızca hangi adımın düştüğü kaydedilebilir.
- [ ] Bir sonraki benzer olayda kök nedeni yakalamak için: hata anında `fly logs -a ikojo`
      çıktısını hemen dosyaya kaydet.
