// Üç yıldız benzetimi (ikojo W7AI4IV): yörünge izi bırakan canlandırma; 150 karede durur.
// Çizim toplama (#5) ve iz pişirme (#6) yollarını gerçek bir betikle dener.
sil(); artalanıKur(siyah); yakınlaştırmayıKapat()
dez (konum, hız, boy, ölçek, örnekle) = (50, 1.0, 5, 100, 4)
dez fırça = 0.2
tanım boya(r: Renk, r2: Resim): Resim = r2.kalemRenkli(r).boyalı(r)
dez (r1, r3, r2) = (kırmızı, mavi, yeşil)
dez d1 = boya(r1, Resim.daire(boy)); dez d2 = boya(r2, Resim.daire(boy)); dez d3 = boya(r3, Resim.daire(boy))
tanım dürt = rastgele(10)
çiz(d1.taşınmış(konum + dürt, konum + dürt), d2.taşınmış(-konum + dürt, -konum + dürt), d3.taşınmış(-konum + dürt, konum + dürt))
den (dx1, dy1) = (hız, 0.0); den (dx2, dy2) = (-hız, 0.0); den (dx3, dy3) = (-rasgele / 3.0, rasgele / 3.0)
tanım açısı(n1: Nokta, n2: Nokta): Kesir = tanjantınAçısı(mutlakDeğer((n1.y - n2.y) / (n1.x - n2.x)))
tanım uzaklığı(n1: Nokta, n2: Nokta): Kesir = karekökü(kuvveti(n1.x - n2.x, 2) + kuvveti(n1.y - n2.y, 2))
tanım çekim(u: Kesir) = ölçek / kuvveti(enİrisi(boy * 3, u), 2)
tanım dv(n1: Nokta, n2: Nokta) = {
  dez a = açısı(n1, n2); dez f = çekim(uzaklığı(n1, n2))
  dez (fx, fy) = (f * kosinüs(a), f * sinüs(a))
  (eğer (n1.x > n2.x) -fx yoksa fx, eğer (n1.y > n2.y) -fy yoksa fy)
}
gizle(); den adım = 1
canlandır {
  dez (n1, n2, n3) = (d1.konum, d2.konum, d3.konum)
  eğer (fırça > 0 && adım % örnekle == 1)
    için ((n, r) <- Diz((n1, r1), (n2, r2), (n3, r3))) çiz(Resim.daire(fırça).taşınmış(n.x, n.y).boyalı(r).kalemRenkli(r))
  adım += 1
  için (n <- Diz(n2, n3)) { dez (fx, fy) = dv(n1, n); dx1 += fx; dy1 += fy }
  için (n <- Diz(n3, n1)) { dez (fx, fy) = dv(n2, n); dx2 += fx; dy2 += fy }
  için (n <- Diz(n1, n2)) { dez (fx, fy) = dv(n3, n); dx3 += fx; dy3 += fy }
  d1.konumuKur(n1.x + dx1, n1.y + dy1); d2.konumuKur(n2.x + dx2, n2.y + dy2); d3.konumuKur(n3.x + dx3, n3.y + dy3)
  eğer (adım >= 150) { durdur(); satıryaz("TAMAM: üç yıldız, " + adım + " adım") }
}
