// Çarpışma (JTS): çarpışıyorMu/çarptıMı/çarpışma/çarpışmalar, sınırları, içeriyorMu, uzaklık,
// sahne kenarları ve sekme (sahnedenSek / resimdenSek), dokunuyorMu.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
çizSahne(açıkGri)
dez a = götür(-20, 0) -> Resim.daire(30).boyalı(kırmızı)
dez b = götür(20, 0) -> Resim.daire(30).boyalı(mavi)
dez c = götür(300, 200) -> Resim.kare(20).boyalı(yeşil)
çiz(a, b, c)
gerekli(a.çarpışıyorMu(b), "a ile b kesişmeli")
gerekli(!a.çarpışıyorMu(c), "a ile c kesişmemeli")
gerekli(a.çarptıMı(b), "çarptıMı takma adı")
gerekli(a.çarpışma(Dizi(c, b)) == Biri(b), "çarpışma ilk çarpanı vermeli")
gerekli(a.çarpışmalar(Küme(b, c)) == Küme(b), "çarpışmalar kümesi")
gerekli(a.uzaklık(c) > 200, "uzaklık: " + a.uzaklık(c))
dez s = a.sınırları
gerekli(s.eni > 55 && s.eni < 65, "daire sınırı ~60: " + s.eni)
gerekli(s.içeriyorMu(Nokta(-20, 0)), "merkez sınırın içinde")
dez ta = tuvalAlanı
dez kenar = götür(0, ta.y + ta.boyu - 20) -> Resim.kare(40).boyalı(mor); çiz(kenar)
konumuKur(-20, 0)
dokunuyorMu(a) { değdi => satıryaz("üst düzeyde: kaplumbağa a'ya değiyor mu: " + değdi) }
// Sahne kenarları kaplumbağa resmidir; kaplumbağa kuyruğu bitmeden geometrisi yoktur.
// Bu yüzden sahneye bağlı denetimler birkaç kare sonra, canlandırma içinde yapılır.
den kare = 0
canlandır {
  kare += 1
  eğer (kare == 30) {
    gerekli(kenar.çarpışıyorMu(sahneÜstü), "kare üst kenara değmeli")
    dez yeniHız = sahnedenSek(kenar, Yöney2B(0, 5))
    gerekli(yeniHız.y < 0, "üst kenardan sekince y ters dönmeli: " + yeniHız)
    dez v2 = resimdenSek(a, Yöney2B(5, 0), b)
    gerekli(v2.x < 0, "b'den sekince x ters dönmeli: " + v2)
    gerekli(sahneKenarı.sınırları.eni >= ta.eni - 2, "sahne kenarı tuvali sarmalı: " + sahneKenarı.sınırları.eni)
    gerekli(kenar.çarpışıyorMu(sahneKenarı) && !c.çarpışıyorMu(sahneAltı), "sahneKenarı / sahneAltı")
    // kaplumbağa kuyruğundan okuma (geri çağrım kuyruk sırası gelince çalışır)
    dokunuyorMu(a) { değdi => satıryaz("kaplumbağa a'ya değiyor mu: " + değdi) }
    durdur()
    satıryaz("TAMAM: çarpışma")
  }
}
