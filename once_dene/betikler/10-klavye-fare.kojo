// Klavye ve fare: tuşaBasınca/tuşuBırakınca/tuşBasılıMı, resim fare olayları, fareKonumu, kumanda kolu.
// Olaylar kayıt edilir (başsız tarayıcıda tuş/fare gelmez); kumanda kolu 20 kare işletilir.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
dez top = Resim.daire(25).boyalı(mavi); çiz(top)
tuşaBasınca { t => eğer (t == tuşlar.boşluk) top.boyamaRenginiKur(kırmızı) }
tuşuBırakınca { t => satıryaz("bırakıldı: " + t) }
gerekli(!tuşBasılıMı(tuşlar.sol) && !tuşaBasılıMı(tuşlar.yukarı), "başta tuş basılı olmamalı")
top.fareyeTıklayınca { (x, y) => top.kondur(x, y) }
top.fareyeBasınca { (x, y) => satıryaz("basıldı " + x + "," + y) }
top.fareyiBırakınca { (x, y) => () }
top.fareGirince { (x, y) => top.saydamlığınıKur(0.5) }
top.fareÇıkınca { (x, y) => top.saydamlığınıKur(1) }
top.fareyleSürükleyince { (x, y) => top.kondur(x, y) }
dez fk = fareKonumu
satıryaz("fare: " + fk.x + ", " + fk.y)
dez kol = kumandaKolu(60)
kol.çiz(); kol.konumuKur(-300, -200); kol.kolRenginiKur(kırmızı); kol.çevreRenginiKur(gri); kol.çevreKalemRenginiKur(siyah)
dez y: Yöney2B = kol.yöney
den kare = 0
canlandır {
  kare += 1
  kol.oynatSahneİçinde(top, 3.0)
  eğer (kare >= 20) { durdur(); satıryaz("TAMAM: klavye/fare") }
}
