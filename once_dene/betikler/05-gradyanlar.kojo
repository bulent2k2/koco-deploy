// Gradyanlar ve DokumaBoya (kojojs-dev #33): doğrusal, çoklu doğrusal, merkezden, döngülü;
// dönüştürücü zinciri ortasında ve resim dizisinde boyaRengi(boya); dokuma (veri adresli imge).
// PIXI 4'te düz renge düşer (çökmez); PIXI 5'te gerçek gradyan.
sil(); artalanıKur(beyaz); yakınlaştırmayıKapat()
dez g1 = Renk.doğrusalDeğişim(-100, 0, kırmızı, 100, 0, mavi)
çiz(götür(-350, 200) * boyaRengi(g1) -> Resim.dikdörtgen(200, 60))                       // bitişik
çiz(götür(50, 200) * boyaRengi(g1) * kalemRengi(siyah) -> Resim.dikdörtgen(200, 60))     // zincir ortasında
çiz(götür(-350, 60) * boyaRengi(g1) -> Resim.dizi(Resim.kare(60), götür(80, 0) -> Resim.daire(30)))  // resim dizisi
çiz(götür(150, 90) * boyaRengi(Renk.merkezdenDışarıDoğruDeğişim(0, 0, sarı, 40, kırmızı, doğru)) -> Resim.daire(80))
çiz(götür(-350, -80) * boyaRengi(RenkDD(0, 0, siyah, 200, 0, yeşil)) -> Resim.dikdörtgen(200, 40))
çiz(götür(-350, -140) * boyaRengi(Renk.doğrusalÇokluDeğişim(0, 0, 200, 0, Dizi(0, 0.5, 1.0), Dizi(kırmızı, sarı, mavi), yanlış)) -> Resim.dikdörtgen(200, 40))
çiz(götür(-350, -200) * boyaRengi(Renk.merkezdenDışarıDoğruÇokluDeğişim(100, 20, 60, Dizi(0, 0.7, 1), Dizi(Renk.kyms(255, 0, 0, 245), Renk.kyms(215, 0, 0, 245), Renk.kyms(185, 0, 0, 245)), doğru)) -> Resim.dikdörtgen(200, 40))
// 12x24 tuğla (kojojs-dev/medya/collidium/bwall.png), veri adresi olarak gömülü: ağ gerekmez
dez tuğla = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAYCAYAAADOMhxqAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAADRElEQVQ4ywXBi27bVACA4f8cH8fxJbFzcRIr2ZZ2dGNIgIR4BZ6L9+CpQIKNlW60bGnaprGdOLbjO98nfvvl1+44mZGlBZ+ikq0a0ZxKRl962L5B8P1PeE8O/thkmRooa+RwzHuEFMSmYG4mPAUJ2XmEPdPZv22QZs1kapEoBxUV3xCd77kuBMeLLd3cwN+25Fcxh8V36BLmFzaho9NpAnXj5xj/2GhDAaZEEwmf8guyosK1V6i6ILEGGFXBR9tEDiODerDlQd8TY/Pezul+/gO+PXE47NCHFTEPRKuWbgHqML6l9Qq8+pbSgLtzTNKMMGY39DqH7NHgft2S5xVlkCEreeCakFhaxJrPC8fj4N6j3ZecPJ1aS7GeM85vY0QvRfrPgl45phUmgzQh/XLPPF/Q9BSyvcXyQo6jCc3nBcVZQ63DDY+HnNLRue7+Qwv66PuapBOsTA/DG1CKJ+KRxjRcIjkeOPoFafkv081r8spBsaGZ2hjBlE1mINKAYb3E6EnUV7+j3urM3ROJ9xeykeymErcIuS9zpOdz7j9St3Du2Uh/f8lVfMYr3yFeGOhhias0onc28TxBXtwRqoTArdCtEukOQ4xLnbzOyCP4+43Lk+bSypJ1aiNNyWo04bCTyKhFBnsHdV1gDhS+tcaTHn1DY91VLF51XDwu6YSLWRY4YQ85mTwRFAo7dHC1CS+tH9DqNfXpkuzDa2a7EPn1K21m4rUPqK53Qr08YkUBye0bdL3Gd/vsi4hpdkLYCm+nkT7mJLMSZW6fyDyT236JGHwmGS9xw4yF1CDLCEcL9GeLsdqwSw3U75eCKLNAGERKx/1TY3Q1oLYNknyGfztgypHKvUQYe6TIFWncwXrPJOrQhSL62KDrEavEQslHhkODOGow9wFqJhu8qUC3C76sKsbFjrHuwvMrfOeAdgrotSMsTNo9qO3Q5CZssKoes23KyAhYOj7cnZiYfZoMzE3DYFBTCQP1fnsmnIxZ1D6FphGMJzg3n7nEI2sFbfMCFew47DR6uobqLwqWCdS5QenNuctCloWBlYzol0taOryHK35cpRD7KGG1CK0i2ie01ZBB7iJsjWAjEF7F8FNHYRmoDx2+JfgfyOaFLSYxTGsAAAAASUVORK5CYII="
çiz(götür(50, -80) * boyaRengi(DokumaBoya(tuğla, 0, 0)) * kalemRengi(renksiz) -> Resim.dikdörtgen(200, 100))
// Renk yapıcıları
dez r = Renk.kym(10, 20, 30); dez r2 = Renk.ada(120, 1, 0.5); dez r3 = Renk.adas(120, 1, 0.5, 0.4)
gerekli(mutlakDeğer(r3.alpha.get - 0.4) < 1e-6, "adas saydamlık")
çiz(götür(300, -150) -> Resim.kare(40).boyalı(r2))
satıryaz("TAMAM: gradyanlar")
