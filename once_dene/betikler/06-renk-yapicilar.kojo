// Renk yapıcıları ve adlandırılmış renkler; Renk(k, y, m[, s]) masaüstü biçimi (kojojs-dev #19 bulgusu).
sil(); artalanıKur(beyaz)
dez a = Renk(204, 102, 0)
dez b = Renk(90, 199, 255, 128)
dez c = renkKur(10, 20, 30); dez d = renkKur(10, 20, 30, 40)
gerekli(Renk.kym(255, 0, 0) == Renkler.kırmızı, "kym kırmızı")
gerekli(Renk.rgb(255, 0, 0) == Renk.kym(255, 0, 0), "rgb = kym")
gerekli(mutlakDeğer(Renk.kyms(0, 0, 255, 128).alpha.get - 128 / 255.0) < 1e-6, "kyms saydamlık")
dez adlılar = Dizi(kırmızı, mavi, yeşil, sarı, mor, pembe, kahverengi, siyah, beyaz, gri, koyuGri, açıkGri, turuncu,
  camgöbeği, Renkler.altın, Renkler.zeytin, Renkler.mercan, Renkler.turkuaz, Renkler.menekşe, Renkler.haki, Renkler.gökMavisi, koyuMavi, koyuYeşil, koyuKırmızı, renksiz, saydam)
gerekli(adlılar.boyu == 26, "adlı renkler")
gerekli(Renkler.mercan.kırmızısı.get > 200, "mercan kırmızı ağırlıklı")
dez rr = rastgeleRenk; dez rş = rastgeleŞeffafRenk
için ((renk, i) <- adlılar.ikileSırayla) çiz(götür(-380 + i * 30, 0) -> Resim.kare(25).boyalı(renk))
çiz(götür(-380, -100) -> Resim.kare(40).boyalı(a)); çiz(götür(-320, -100) -> Resim.kare(40).boyalı(b))
çiz(götür(-260, -100) -> Resim.kare(40).boyalı(c)); çiz(götür(-200, -100) -> Resim.kare(40).boyalı(d))
satıryaz("TAMAM: renk yapıcıları")
