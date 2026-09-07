// Sahne ve tuval: artalan (düz/dikey/yatay), tuvalAlanı/tuvalSınırları, eksen ve ızgara,
// yaklaşma/kaydırma/döndürme, bakış açıları, tuval boyutu.
sil(); artalanıKurDik(mavi, beyaz); artalanıKurYatay(sarı, beyaz); artalanıKur(beyaz)
dez ta = tuvalAlanı
gerekli(ta.eni > 0 && ta.boyu > 0, "tuval alanı: " + ta)
dez ts = tuvalSınırları
gerekli(mutlakDeğer(ts.eni - ta.eni) < 1e-6, "tuvalSınırları ile tuvalAlanı aynı en")
eksenleriGöster(); ızgarayıGöster(); gridiGöster(); eksenleriGizle(); ızgarayıGizle(); gridiGizle(); eksenleriGöster()
çiz(Resim.daire(30).boyalı(kırmızı))
yaklaş(2); yaklaş(1.5, 50, 50); tuvaliKaydır(10, 20); tuvaliDöndür(15); yaklaşmayıSil(); görünümüSıfırla()
yakınlaştırmayıKapat(); yaklaşmayaİzinVerme()
başlangıçNoktasıAltSolKöşeOlsun()
çiz(götür(50, 50) -> Resim.kare(30).boyalı(yeşil))
kojoVarsayılanİkinciBakışaçısınıKur(); kojoÇalışmaSayfalıBakışaçısınıKur()
tuvalBoyutlarınıKur(600, 400)
dez ta2 = tuvalAlanı
gerekli(mutlakDeğer(ta2.eni - 600) < 1e-6 && mutlakDeğer(ta2.boyu - 400) < 1e-6, "tuval 600x400 olmalı: " + ta2)
çiz(götür(-100, -100) -> Resim.kare(30).boyalı(mor))
satıryaz("TAMAM: sahne/tuval")
