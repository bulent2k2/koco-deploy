// Canlandırma: canlandır + durdur, canlandırYenidenÇizerek, tepkiVer, ekranTazelemeHızınıGöster,
// kareSüresi; 60 karede kendini durdurur.
sil(); artalanıKur(siyah); yakınlaştırmayıKapat()
dez top = Resim.daire(20).boyalı(sarı); çiz(top)
dez uçan = götür(-300, 100) -> Resim.dikdörtgen(30, 10).boyalı(kırmızı); çiz(uçan)
uçan.tepkiVer { r => r.kaydır(2, 0) }
canlandırYenidenÇizerek[Kesir](0.0, _ + 2, x => götür(x - 200, -150) * boyaRengi(camgöbeği) -> Resim.kare(20))
ekranTazelemeHızınıGöster(beyaz, 12)
den kare = 0
den hız = Yöney2B(3, 2)
canlandır {
  kare += 1
  top.kaydır(hız)
  eğer (kare == 30) satıryaz("kare süresi (ms): " + kareSüresi)
  eğer (kare >= 60) {
    durdur()
    dez k = top.konum
    gerekli(mutlakDeğer(k.x - 180) < 1e-6, "60 kare x 3 = 180 birim: " + k.x)
    satıryaz("TAMAM: canlandırma " + kare + " kare")
  }
}
