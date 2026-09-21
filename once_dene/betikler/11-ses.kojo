// Ses (howler): mp3 çalma/durdurma/döngü, ayrı çalar, nota çalgısı. Başsız tarayıcıda dosyalar
// /media'dan gelmez; amaç API'nin çağrılabilir olması ve çökmemesi.
sil(); artalanıKur(beyaz)
sesMp3üÇal(Ses.vuruş)
müzikMp3üÇal(Ses.arabaGidiyor)
satıryaz("müzik çalıyor mu: " + müzikMp3üÇalıyorMu)
müzikMp3üKapat()
müzikMp3üÇalDöngülü(Ses.yaşasın); müzikMp3DöngüsünüKapat()
dez çalar = yeniMp3Çalar
çalar.sesMp3üÇal(Ses.vuruş); çalar.durdur()
notaÇalgısınıKur(Çalgı.Piyano); notaÇal(60, 200); notaÇal(64, 200); notaÇal(67, 300)
çiz(Resim.yazı("♪ ses denemesi", 24))
satıryaz("TAMAM: ses")
