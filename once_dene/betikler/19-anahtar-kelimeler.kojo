// Yamalı derleyicinin Türkçe ANAHTAR KELİMELERİ (kojo/scala-tr): tanım dez den eğer yoksa için eşle durum
// doğru yanlış getir yeni örtük sınıf nesne özellik tür yayar birlikte baskın dene yakala sonunda
// yineleDoğruKaldıkça geriDön miskin yok bu; ayrıca Türkçe harfli tanımlayıcılar.
getir scala.collection.mutable.ArrayBuffer
özellik Canlı { tanım ses: Yazı; tanım selam: Yazı = ses + "!" }
soyut sınıf Hayvan(dez ad: Yazı) yayar Canlı { baskın tanım toString = ad }
sınıf Kedi(ad: Yazı) yayar Hayvan(ad) { tanım ses = "miyav" }
sınıf Köpek(ad: Yazı) yayar Hayvan(ad) birlikte Canlı { tanım ses = "hav"; miskin dez uzunAd = ad + " köpek" }
nesne Çiftlik { dez hayvanlar = Dizi(yeni Kedi("Tekir"), yeni Köpek("Karabaş")) }
tür Sayaç = Sayı
tanım sınıfla(h: Hayvan): Yazı = h eşle {
  durum k: Kedi => "kedi " + k.ses
  durum k: Köpek => "köpek " + k.uzunAd
  durum _ => "bilinmeyen"
}
tanım ilkÇift(xs: Dizin[Sayı]): Belki[Sayı] = {
  için (x <- xs) { eğer (x % 2 == 0) geriDön Biri(x) }
  Hiçbiri
}
den sayaç: Sayaç = 0
yineleDoğruKaldıkça (sayaç < 5) { sayaç += 1 }
dez çiftler = için (i <- 1 |-| 6 eğer i % 2 == 0) ver i * i
dez şğüöçİı_değişken = "Türkçe harfli tanımlayıcı"
dez boşDeğer: Yazı = yok
örtük sınıf SayıUzantısı(n: Sayı) { tanım ikiKatı = n * 2 }
gerekli(sayaç == 5 && çiftler == Dizin(4, 16, 36), "döngüler: " + çiftler)
gerekli(Çiftlik.hayvanlar.işle(sınıfla) == Dizi("kedi miyav", "köpek Karabaş köpek"), "eşle/durum")
gerekli(ilkÇift(Dizin(1, 3, 4, 5)) == Biri(4) && ilkÇift(Dizin(1)).yokMu, "geriDön")
gerekli(Çiftlik.hayvanlar.başı.selam == "miyav!" && (5).ikiKatı == 10, "özellik/örtük")
gerekli(boşDeğer == yok && şğüöçİı_değişken.boyu > 0 && doğru && !yanlış, "yok/doğru/yanlış")
dez ab = ArrayBuffer(1); ab += 2
gerekli(ab.boyu == 2, "getir")
satıryaz("TAMAM: anahtar kelimeler")
