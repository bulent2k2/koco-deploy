// Birden çok kaplumbağa: yeniKaplumbağa, çevir, noktayaDön, geri, gizle/göster, konumuOku kuyruğu.
sil(); artalanıKur(beyaz)
dez k1 = yeniKaplumbağa(-150, 0)
dez k2 = yeniKaplumbağa(150, 0)
dez k3 = yeniKaplumbağa(0, 120)
için (k <- Dizi(k1, k2, k3)) { k.hızıKur(çokHızlı); k.kalemKalınlığınıKur(2) }
k1.kalemRenginiKur(kırmızı)
yinele(6) { k1.ileri(50); k1.sağ(60) }
k2.kalemRenginiKur(yeşil); k2.çevir(k1); k2.ileri(100)
k3.kalemRenginiKur(mavi); k3.noktayaDön(0, 0); k3.ileri(60); k3.geri(30)
k3.noktayaDön(Nokta(100, 100)); k3.noktayaGit(50, 50)
k1.gizle(); k1.göster()
k3.konumVeYönüBelleğeYaz(); k3.zıpla(20); k3.konumVeYönüGeriYükle()
gizle()
k2.konumuOku { n =>
  gerekli(n.x < 150, "k2 k1'e doğru ilerlemeli, x = " + n.x)
  satıryaz("TAMAM: çoklu kaplumbağa")
}
