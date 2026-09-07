// Gelecek (Future), zamanTut, BuAn/buAn, durakla, artalandaOynat.
dez g = Gelecek.başarılı(5).işle(_ * 2)
g.işle { v => gerekli(v == 10, "gelecek 10 olmalı: " + v); satıryaz("gelecek geldi: " + v) }
dez g2 = g.düzİşle(n => Gelecek.başarılı(n + 1)).ele(_ > 0)
dez gh: Gelecek[Sayı] = Gelecek.başarısız(new KuralDışı("olmadı"))
gh.recover { durum _ => -1 }.işle { v => gerekli(v == -1, "kurtarma") }
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
satıryaz("TAMAM: gelecek/zaman")
