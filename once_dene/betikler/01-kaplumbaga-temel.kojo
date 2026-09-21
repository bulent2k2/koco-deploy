// Kaplumbağa temelleri: ileri/sağ/sol/zıpla, kalem ve boya, daire/yay/kare/üçgen, nokta, yazı.
// Sonda konumuOku ile ev()'in başlangıca döndüğü DENETLENİR (gerekli tutmazsa betik "kaldı").
sil(); artalanıKur(beyaz); hızıKur(çokHızlı)
kalemRenginiKur(mavi); kalemKalınlığınıKur(3); boyamaRenginiKur(Renk.kyms(255, 200, 0, 120))
yinele(4) { ileri(100); sağ() }
zıpla(120); kare(60); üçgen(60)
kalemiKaldır(); ileri(50); kalemiİndir()
sol(90); daire(30); yay(40, 90)
konumuKur(-150, -100); açıyaDön(45); ileri(80)
nokta(20); nokta()
kalemRenginiKur(siyah); yazı("Merhaba Koco")
konumVeYönüBelleğeYaz(); ileri(40); konumVeYönüGeriYükle()
biçimleriBelleğeYaz(); kalemRenginiKur(kırmızı); biçimleriGeriYükle()
yineleDizinli(3) { i => sağ(30); ileri(10 * i) }
yineleİlktenSona(1, 3) { i => sol(15 * i) }
gerekli(kalemİnikMi, "kalem inik olmalı")
ev()
konumuOku { n =>
  gerekli(mutlakDeğer(n.x) < 1e-6 && mutlakDeğer(n.y) < 1e-6, "ev() başlangıca dönmeli: " + n)
  satıryaz("TAMAM: kaplumbağa temel")
}
