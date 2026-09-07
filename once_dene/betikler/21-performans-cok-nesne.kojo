// Çok nesne: 300 durağan daire + hareketli kare. Sahnede 150'den çok çocuk olunca durağan
// resimler dokuya "pişirilir" (kojojs-dev #6); pişirme/geri alma yolu da böylece çalışır.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
için (i <- 0 |- 300) {
  çiz(götür(-380 + (i % 30) * 26, -280 + (i / 30) * 30) -> Resim.daire(6).boyalı(rastgeleRenk))
}
dez gezgin = Resim.kare(20).boyalı(kırmızı); çiz(gezgin)
dez yazıR = götür(-380, 250) -> Resim.yazıRenkli("kare: 0", 16, siyah); çiz(yazıR)
den kare = 0
canlandır {
  kare += 1
  gezgin.kondur(-300 + kare * 5, 0)
  yazıR.güncelle("kare: " + kare)
  eğer (kare == 60) { çiz(götür(0, 200) -> Resim.daire(15).boyalı(mavi)) } // pişmişken yeni çocuk
  eğer (kare >= 120) { durdur(); satıryaz("TAMAM: 300 nesne + canlandırma") }
}
