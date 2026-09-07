// Küçük oyun döngüsü: top + raket, çarpışma ve sekme, sahne kenarı; 120 karede kendini durdurur.
sil(); artalanıKur(siyah); yakınlaştırmayıKapat()
çizSahne(koyuGri)
dez ta = tuvalAlanı
dez top = Resim.daire(12).boyalı(beyaz); çiz(top)
dez raket = götür(-40, ta.y + 20) -> Resim.dikdörtgen(80, 12).boyalı(camgöbeği); çiz(raket)
dez skor = götür(ta.x + 10, ta.y + ta.boyu - 30) -> Resim.yazıRenkli("sekme: 0", 18, beyaz); çiz(skor)
den hız = Yöney2B(4, 5)
den kare = 0
den sekme = 0
canlandır {
  kare += 1
  top.kaydır(hız)
  eğer (top.çarpışıyorMu(raket)) { hız = resimdenSek(top, hız, raket); sekme += 1; skor.güncelle("sekme: " + sekme) }
  yoksa eğer (top.çarpışıyorMu(sahneKenarı)) { hız = sahnedenSek(top, hız); sekme += 1; skor.güncelle("sekme: " + sekme) }
  raket.konumuKur(top.konum.x - 40, ta.y + 20)
  eğer (kare >= 120) {
    durdur()
    gerekli(sekme >= 1, "120 karede en az bir sekme olmalı")
    satıryaz("TAMAM: küçük oyun, " + sekme + " sekme")
  }
}
