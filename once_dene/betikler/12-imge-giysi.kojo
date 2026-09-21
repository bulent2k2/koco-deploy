// İmgeler ve giysiler: Resim.imge (sprite), giysili kaplumbağa, giysi değiştirme/büyütme.
// Dosyalar /media'dan yüklenir; başsız dosya:// koşusunda yüklenemez, yalnız API ve çökmezlik denenir.
sil(); artalanıKur(beyaz)
dez araba = Resim.imge(Görünüş.araba); çiz(götür(-200, 100) -> araba)
dez top = Resim.imge(Çizim.top1); çiz(götür(100, 100) -> top)
dez zarflı = Resim.imge(Görünüş.kalem, Resim.dikdörtgen(60, 60)); çiz(götür(250, 100) -> zarflı)
dez k = yeniKaplumbağa(0, -100, Görünüş.yarasa1a)
k.giysileriKur(Görünüş.yarasa1a, Görünüş.yarasa1b); k.birsonrakiGiysi(); k.giysiyiBüyült(1.5); k.ileri(30)
giysiKur(Görünüş.kalem); ileri(20)
çiz(götür(-300, -200) -> Resim.imge(Artalan.demiryolu))
satıryaz("TAMAM: imge/giysi (dosyalar /media'dan yüklenir)")
