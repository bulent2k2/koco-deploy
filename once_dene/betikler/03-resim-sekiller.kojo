// Resim şekilleri: daire, dikdörtgen, kare, elips, yay, çizgiler, yoldan, noktadan, yazı;
// dizi/diziYatay/diziDikey/küme yerleşimleri; çizilen resmin sınırları.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
dez şekiller = Dizi(
  Resim.daire(40).boyalı(kırmızı),
  Resim.dikdörtgen(80, 50).boyalı(mavi).kalemRenkli(siyah),
  Resim.kare(50).boyalı(yeşil),
  Resim.elips(50, 30).boyalı(sarı),
  Resim.yay(40, 120).kalemRenkli(mor).kalemKalınlıklı(4),
  Resim.yatayÇizgi(80),
  Resim.dikeyÇizgi(60),
  Resim.yoldan { y => y.kondur(0, 0); y.doğruÇiz(60, 0); y.eğriÇiz(30, 60, 90, 40); y.başaDön() }.boyalı(turuncu),
  Resim.noktadan { gn => gn.başla(); gn.nokta(0, 0); gn.nokta(60, 0); gn.nokta(30, 50); gn.bitir() }.boyalı(camgöbeği)
)
çiz(götür(-380, 150) -> Resim.diziYatay(şekiller))
çiz(götür(-380, -250) -> Resim.diziDikey(Resim.kare(30).boyalı(gri), Resim.daire(15).boyalı(pembe), Resim.dikeyBoşluk(10), Resim.yatayBoşluk(10)))
çiz(götür(100, -100) -> Resim.dizi(Resim.kare(80).boyalı(açıkGri), Resim.daire(30).boyalı(koyuMavi)))
çiz(götür(250, -100) -> Resim.küme(Resim.kare(20).boyalı(Renkler.altın), götür(30, 30) -> Resim.kare(20).boyalı(Renkler.zeytin)))
çiz(götür(-100, -100) -> Resim.diziYatayDüzenli(Resim.kare(20), Resim.kare(40), Resim.kare(20)))
dez dd = Resim.dikdörtgen(80, 50).boyalı(Renkler.mercan)
çiz(götür(300, 100) -> dd)
dez s = dd.sınırları
gerekli(s.eni >= 80 && s.eni < 90, "dikdörtgen sınırı ~80 olmalı: " + s.eni)
gerekli(şekiller.boyu == 9, "dokuz şekil")
satıryaz("TAMAM: resim şekilleri")
