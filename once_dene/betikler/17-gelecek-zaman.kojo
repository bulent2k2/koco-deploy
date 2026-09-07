// Gelecek (Future), zamanTut, BuAn/buAn, durakla, artalandaOynat.
// Bir sözün (Gelecek) içindeki gerekli(...) sayfa hatası ÜRETMEZ -- başarısız bir Future olur ve
// kimse bakmaz (inceleme bulgusu). O yüzden söz denetimleri onComplete ile kanala bağlanır:
// tutmayan denetim "HATA:" satırı yazar (koşucu bunu "kaldı" sayar), TAMAM ancak üç söz de bitince yazılır.
getir scala.util.{Success, Failure}
den bitenSöz = 0
tanım sözBitti(): Birim = { bitenSöz += 1; eğer (bitenSöz == 3) satıryaz("TAMAM: gelecek/zaman") }
tanım denetle[T](ad: Yazı, g: Gelecek[T])(koşul: T => İkil): Birim = g.onComplete {
  durum Success(v) => eğer (!koşul(v)) satıryaz("HATA: " + ad + " tutmadı: " + v) yoksa satıryaz(ad + " tamam: " + v); sözBitti()
  durum Failure(e) => satıryaz("HATA: " + ad + " başarısız: " + e); sözBitti()
}
dez g = Gelecek.başarılı(5).işle(_ * 2)
denetle("işle", g)(_ == 10)
dez g2 = g.düzİşle(n => Gelecek.başarılı(n + 1)).ele(_ > 0)
denetle("düzİşle/ele", g2)(_ == 11)
dez gh: Gelecek[Sayı] = Gelecek.başarısız(new KuralDışı("olmadı"))
denetle("başarısız/recover", gh.recover { durum _ => -1 })(_ == -1)
dez z = zamanTut("toplam") { (1 |-| 1000).toList.sum }()
gerekli(z == 500500, "zamanTut sonucu: " + z)
dez ş = BuAn()
satıryaz(ş.saat + ":" + ş.dakika + ":" + ş.saniye + " " + ş.gün + "." + ş.ay + "." + ş.yıl)
gerekli(ş.yıl >= 2026, "yıl")
dez t: Uzun = buAn
gerekli(t > 0L, "buAn")
durakla(0.2); duraklaMiliSaniye(50)
artalandaOynat { satıryaz("artalanda çalıştı") }
ileri(10)
