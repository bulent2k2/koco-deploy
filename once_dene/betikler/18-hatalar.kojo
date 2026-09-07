// Hata türleri ve dene/yakala/sonunda (Türkçe anahtar kelimeler) -- yakalanan her hata sayılır.
dez yakalananlar = EsnekDizik[Yazı]()
tanım yakalandı(ad: Yazı): Birim = yakalananlar += ad
den sonundaÇalıştı = yanlış
dene { throw new KuraldışıGirdiHatası("deneme") } yakala { durum _: KuraldışıGirdiHatası => yakalandı("girdi") } sonunda { sonundaÇalıştı = doğru }
// NOT: Dizi(1)(5) Scala.js'te FIRLATMAZ -- Dizi.apply varargs'ı olduğu gibi (WrappedVarArgs) döndürüyor,
// dizin denetimi yok, undefined gelir. Dizin (List) fırlatır; masaüstüyle fark olarak bilinsin.
dene { dez d = Dizin(1); d(5) } yakala { durum _: SınırDışınaTaşmaHatası => yakalandı("sınır") }
dene { gerekli(yanlış, "bilerek") } yakala { durum e: KuraldışıGirdiHatası => gerekli(e.getMessage.içeriyorMu("bilerek")); yakalandı("gerekli") }
dene { dez sıfır = 0; 1 / sıfır } yakala { durum _: MatematikselHata => yakalandı("matematik") }
dene { throw new KuralDışı("genel") } yakala { durum e: KuralDışı => yakalandı("genel") }
dene { "abc".sayıya } yakala { durum _: NumberFormatException => yakalandı("sayıBiçimi") }
dene { Hiçbiri.al } yakala { durum _: NoSuchElementException => yakalandı("öğeYok") }
gerekli(yakalananlar.boyu == 7, "yedi hata yakalanmalı, yakalananlar: " + yakalananlar.yazıYap(","))
gerekli(sonundaÇalıştı, "sonunda çalışmalı")
dez hataTürleri: Dizin[Yazı] = Dizin("MatematikselHata", "BelirtimHatası", "EksikTanımHatası", "BoşGöstergeHatası")
gerekli(hataTürleri.boyu == 4)
satıryaz("TAMAM: hatalar")
