// Canlandırma: canlandır + durdur, canlandırYenidenÇizerek, tepkiVer/canlan (her kare), davran (bir kez),
// ekranTazelemeHızınıGöster, kareSüresi; 60 karede kendini durdurur ve sayaçları denetler (kojojs-dev #34 anlamları).
sil(); artalanıKur(siyah); yakınlaştırmayıKapat()
dez top = Resim.daire(20).boyalı(sarı); çiz(top)
dez uçan = götür(-300, 100) -> Resim.dikdörtgen(30, 10).boyalı(kırmızı); çiz(uçan)
den tepkiSayacı = 0
den canlanSayacı = 0
den davranSayacı = 0
uçan.tepkiVer { r => r.kaydır(2, 0); tepkiSayacı += 1 }     // her kare
uçan.canlan { r => canlanSayacı += 1 }                      // tepkiVer'in öbür adı: her kare
davran { k => k.ileri(5); davranSayacı += 1 }               // kaplumbağa: BİR kez
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
    gerekli(davranSayacı == 1, "davran bir kez çalışmalı: " + davranSayacı)
    gerekli(tepkiSayacı >= 50 && canlanSayacı >= 50, "tepkiVer/canlan her kare çalışmalı: " + tepkiSayacı + "/" + canlanSayacı)
    gerekli(mutlakDeğer(uçan.konum.x - (-300 + 2 * tepkiSayacı)) < 1e-6, "tepkiVer kaydırması sayaçla tutmalı: " + uçan.konum.x)
    satıryaz("TAMAM: canlandırma " + kare + " kare, tepki " + tepkiSayacı)
  }
}
