// Dönüştürücüler: götür/döndür/büyüt/boyaRengi/kalemRengi/kalemBoyu/saydamlık zincirleri,
// yöntem biçimleri (taşınmış, döndürülmüş...), yerinde değiştirme (döndür, taşı, kaydır...), kopyası, sil.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
dez temel = Resim.kare(60)
dez r1 = götür(-200, 100) * döndür(30) * büyüt(1.5) * boyaRengi(kırmızı) * kalemRengi(siyah) * kalemBoyu(2) -> temel
dez r2 = götür(0, 100) * saydamlık(0.5) * boyaRengi(mavi) -> Resim.daire(40)
dez r3 = götür(200, 100) * büyüt(2, 0.5) -> Resim.daire(30).boyalı(yeşil)
çiz(r1, r2, r3)
dez r4 = Resim.dikdörtgen(60, 40).boyalı(mor).taşınmış(-200, -100).döndürülmüş(15).büyütülmüş(1.2).saydamlıklı(0.8)
çiz(r4)
dez r5 = Resim.daire(20).veBoya(turuncu).veKalemRengiyle(siyah).veKalemKalınlığıyla(3).veKondur(0, -100)
r5.veÇiz()
r5.döndür(45); r5.taşı(10, 0); r5.kaydır(Yöney2B(5, 5)); r5.büyüt(1.1); r5.yansıtX(); r5.yansıtY()
r5.saydamlığınıKur(0.6); r5.kalemRenginiKur(kırmızı); r5.boyamaRenginiKur(sarı); r5.kalemKalınlığınıKur(1)
r5.öneAl(); r5.arkayaAt(); r5.gizle(); r5.göster()
gerekli(r5.görünürMü, "göster sonrası görünür olmalı")
dez k = r5.konum
gerekli(mutlakDeğer(k.x - 15) < 1e-6 && mutlakDeğer(k.y + 95) < 1e-6, "konum (15, -95) olmalı: " + k)
dez kopya = r4.kopyası
çiz(kopya.taşınmış(100, 0))
dez yayR = götür(Nokta(200, -150)) * döndür(30) * büyüt(2) -> Resim.yay(50, 90)
çiz(yayR)
yayR.kondur(Nokta(250, -150)); yayR.konumuKur(Nokta(250, -160)); yayR.götür(1, 2)
r2.sil()
satıryaz("TAMAM: dönüştürücüler")
