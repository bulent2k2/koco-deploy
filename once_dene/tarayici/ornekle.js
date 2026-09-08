// once_dene/tarayici/ornekle.js -- bir betiği koşarken PIXI'nin İÇ durumunu ZAMAN İÇİNDE örnekler.
//
//   node ornekle.js <derlenmiş.js> [saniye]
//
// cizdir.js "betik geçti mi" sorusuna bakar; bu araç "o sırada ekranda ne vardı"
// sorusuna bakar. Asıl işi, bir şeyin GEÇİCİ olarak görünmez olduğu kusurları
// yakalamak -- betik sonunda TAMAM yazdığı için cizdir.js'in göremediği türden.
//
// Her örnekte, sahnedeki en çok parçası olan Graphics (kaplumbağa yolu) için:
//   b = geometry.batches.length    PIXI'nin o kareyi kaç batch'te çizdiği.
//                                  b=0 iken p>0 ise şekiller VAR ama HİÇBİRİ çizilmiyor.
//   p = graphicsData.length        çizilmiş şekil (parça) sayısı
//   dokular                        parça başına fillStyle dokusunun durumu:
//                                  geçerli/geçersiz : dosya adı : dolgu rengi
//
// Neden batch sayısı, neden piksel değil: PIXI 5'in validateBatching'i GEÇERSİZ
// dokulu tek bir parça görünce Graphics'in TAMAMI için batch kurmuyor; o kare
// bomboş çiziliyor. Kaplumbağanın bütün çizimi tek bir Graphics olduğundan
// (turtlePath), uzaktan yüklenen bir DokumaBoya beklenirken daha önce çizilmiş
// her şey de kayboluyordu (kojojs-dev#40). Tuvalden piksel okumak bu ölçüm için
// güvenilir değil: başsız swiftshader'da Playwright'ın öğe ekran görüntüsü canlı
// durumu yansıtmıyor (ölçüldü: farklı sürümler aynı görüntüyü verdi) ve
// renderer.plugins.extract tamamen saydam dönüyor. batches.length ise doğrudan
// PIXI'nin kendi kararı.
//
// Ortam: KOCO_CHROMIUM (isteğe bağlı Chromium yolu; kapta /opt/pw-browsers/chromium).
//
// Örnek -- dokuyu geciktiren bir sunucuya karşı:
//   KOCO_CHROMIUM=/opt/pw-browsers/chromium node ornekle.js /yol/betik.js 26
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [betikJs, saniyeStr] = process.argv.slice(2);
  if (!betikJs) { console.error('kullanım: node ornekle.js <derlenmiş.js> [saniye]'); process.exit(2); }
  const saniye = parseFloat(saniyeStr || '12');
  const secenekler = { args: ['--allow-file-access-from-files', '--use-gl=angle',
    '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] };
  if (process.env.KOCO_CHROMIUM) secenekler.executablePath = process.env.KOCO_CHROMIUM;
  const tarayici = await chromium.launch(secenekler);
  const sayfa = await tarayici.newPage({ viewport: { width: 1000, height: 700 } });
  const hatalar = [], konsol = [];
  sayfa.on('pageerror', e => hatalar.push(e.message.split('\n')[0].slice(0, 200)));
  sayfa.on('console', m => {
    const t = m.text().split('\n')[0];
    if (t.trim() && !/^\s*at /.test(t) && !/willReadFrequently/.test(t)) konsol.push(m.type()[0] + '| ' + t.slice(0, 180));
  });

  // domcontentloaded: 'load' sayfadaki gecikmeli bir imgeyi de beklerdi ve
  // örnekleme tam da ölçmek istediğimiz pencereden SONRA başlardı.
  const sahne = 'file://' + path.resolve(__dirname, 'sahne.html') + '?betik=' + encodeURIComponent(path.resolve(betikJs));
  await sayfa.goto(sahne, { waitUntil: 'domcontentloaded' });
  await sayfa.waitForFunction('window.OLCUM && window.OLCUM.basladi === true', { timeout: 30000 });

  await sayfa.evaluate(() => {
    window.GRAF = () => {
      const bulunan = [];
      (function gez(n) {
        if (!n) return;
        if (n.geometry && n.geometry.graphicsData) bulunan.push(n);
        (n.children || []).forEach(gez);
      })(window.OLCUM.sahne);
      return bulunan;
    };
  });

  const ornekler = [];
  const t0 = Date.now();
  while ((Date.now() - t0) / 1000 < saniye) {
    const o = await sayfa.evaluate(() => {
      const gs = window.GRAF();
      const en = gs.slice().sort((a, b) => b.geometry.graphicsData.length - a.geometry.graphicsData.length)[0];
      if (!en) return { adet: gs.length, yok: true };
      const dokular = en.geometry.graphicsData.map(gd => {
        const t = gd.fillStyle && gd.fillStyle.texture;
        const bt = t && t.baseTexture;
        return (bt ? (bt.valid ? 'geçerli' : 'geçersiz') : 'yok')
          + ':' + (bt && bt.resource && bt.resource.url ? String(bt.resource.url).split('/').pop() : 'iç')
          + ':' + (gd.fillStyle ? '#' + (gd.fillStyle.color >>> 0).toString(16) : '-');
      });
      return { adet: gs.length, b: en.geometry.batches.length, p: en.geometry.graphicsData.length,
               kare: window.OLCUM.kareler, dokular };
    }).catch(e => ({ hata: String(e).slice(0, 120) }));
    o.ms = Date.now() - t0;
    ornekler.push(o);
    await sayfa.waitForTimeout(700);
  }

  const cikti = await sayfa.evaluate(() => (document.getElementById('output') || {}).innerText || '');
  // parça varken hiç batch kurulmayan örnekler: "o an ekranda hiçbir şey yoktu"
  const korOrnek = ornekler.filter(o => o.b === 0 && o.p > 0).length;
  console.log(JSON.stringify({ ornekler, korOrnek, hatalar,
    konsol: [...new Set(konsol)].slice(0, 15), cikti: cikti.trim().slice(0, 500) }, null, 1));
  await tarayici.close();
})();
