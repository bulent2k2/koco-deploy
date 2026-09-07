// once_dene/tarayici/cizdir.js -- derlenmiş bir betiği başsız Chromium'da (Playwright) çalıştırır.
//
//   node cizdir.js <derlenmiş.js> <saniye> <ekran-görüntüsü.png>
//
// Çıktı: tek satır JSON -- durum (geçti/kaldı/eksik), süre (s), hatalar, sayfa çıktısı (#output),
// PIXI sürümü, çizim/kare/çocuk sayıları, doku önbelleği. dene.sh bunu TSV'ye işler.
//
// "kaldı" ölçütü: sayfa hatası (pageerror -- gerekli(...) tutmayınca fırlayan hata da budur),
// betiğin ölçüm kancasına düşen hata, başlatma hatası, ya da çıktıda "HATA:" ile başlayan satır
// (söz/Future içindeki denetimler sayfa hatası üretemez; betik onları böyle bildirir). Ağ/medya yüklenememesi (dosya://
// koşusunda /media yok) UYARI sayılır, kaldı değil.
//
// --allow-file-access-from-files: sahne.html ile derlenmiş JS ayrı dizinlerde; bu bayrak olmadan
// Chromium dosya:// betiğini yabancı kaynak sayar ve hata iletilerini "Script error." diye maskeler.
//
// Ortam: KOCO_CHROMIUM (isteğe bağlı Chromium yolu; yoksa Playwright'ın kendi tarayıcısı).
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [betikJs, saniyeStr, gorsel] = process.argv.slice(2);
  if (!betikJs) { console.error('kullanım: node cizdir.js <derlenmiş.js> [saniye] [görüntü.png]'); process.exit(2); }
  const saniye = parseFloat(saniyeStr || '4');
  const secenekler = { args: ['--allow-file-access-from-files', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] };
  if (process.env.KOCO_CHROMIUM) secenekler.executablePath = process.env.KOCO_CHROMIUM;
  const tarayici = await chromium.launch(secenekler);
  const sayfa = await tarayici.newPage({ viewport: { width: 1000, height: 700 } });
  const sayfaHatalari = [], uyarilar = [];
  sayfa.on('pageerror', e => sayfaHatalari.push(e.message.split('\n')[0].slice(0, 300)));
  sayfa.on('console', m => {
    const t = m.text().split('\n')[0]; // yığın izleri değil, ilk satır (PIXI'nin kullanımdan kalkma uyarıları çok satırlı)
    if (!t.trim() || /^\s*at /.test(t) || /willReadFrequently/.test(t)) return; // yığın izi; Chromium'un Canvas2D ipucu (PIXI yazı ölçümü)
    if (m.type() === 'error' || m.type() === 'warning') {
      if (/Failed to load resource|CORS|ERR_FAILED|ERR_FILE_NOT_FOUND|net::/.test(t)) uyarilar.push('kaynak yüklenemedi: ' + t.replace(/^.*?(\/[^' ]+).*$/, '$1').slice(0, 120));
      else uyarilar.push(t.slice(0, 200));
    }
  });
  sayfa.on('requestfailed', r => uyarilar.push('istek başarısız: ' + r.url().replace(/^file:\/\/.*?\/tarayici\//, '').slice(0, 120)));
  const sahne = 'file://' + path.resolve(__dirname, 'sahne.html') + '?betik=' + encodeURIComponent(path.resolve(betikJs));
  const sonuc = { betik: path.basename(betikJs), durum: 'geçti', hatalar: [], uyarilar: [], cikti: '' };
  try {
    await sayfa.goto(sahne);
    await sayfa.waitForFunction('window.OLCUM && window.OLCUM.basladi === true', { timeout: 30000 });
    // Sabit bekleme yerine: çıktıda TAMAM ya da HATA: görünene, ya da bir sayfa hatası düşene dek
    // bekle; `saniye` yalnız ÜST SINIR (inceleme bulgusu: kare sayısına bağlı betikler makine
    // hızına bağımlı kalmasın). Süre TSV'ye yazılır; "eksik" = bu sürede bitmedi demek.
    const t0 = Date.now();
    let ilkHata; const hataSozu = new Promise(r => { ilkHata = r; });
    sayfa.on('pageerror', () => ilkHata());
    if (sayfaHatalari.length) ilkHata();
    await Promise.race([
      sayfa.waitForFunction(() => {
        const o = document.getElementById('output'); const t = o ? o.innerText : '';
        return /TAMAM|HATA:/.test(t) || (window.OLCUM && window.OLCUM.hatalar.length > 0);
      }, { timeout: saniye * 1000, polling: 100 }).catch(() => null),
      hataSozu,
    ]);
    sonuc.sure = +((Date.now() - t0) / 1000).toFixed(1);
    await sayfa.waitForTimeout(300); // son çizim ve çıktı yerleşsin
    const o = await sayfa.evaluate(() => {
      const O = window.OLCUM;
      const cocuk = O.sahne && O.sahne.children ? O.sahne.children.length : -1;
      const cikti = (document.getElementById('output') || {}).innerText || '';
      return { pixi: PIXI.VERSION, cizim: O.cizimSayisi, kare: O.kareler, cocuk, hatalar: O.hatalar,
               dokuOnbellegi: Object.keys(PIXI.utils.TextureCache).length, cikti: cikti.trim().slice(0, 2000) };
    });
    Object.assign(sonuc, { pixi: o.pixi, cizim: o.cizim, kare: o.kare, cocuk: o.cocuk, dokuOnbellegi: o.dokuOnbellegi, cikti: o.cikti });
    sonuc.hatalar = [...new Set([...sayfaHatalari, ...o.hatalar])];
    if (gorsel) {
      // #canvas fiddle'ın 2B tuvali (300x150); PIXI kendi tuvalini canvas-holder'a sonradan ekler
      const tuval = sayfa.locator('#canvas-holder canvas:not(#canvas)').first();
      if (await tuval.count()) await tuval.screenshot({ path: gorsel }); else await sayfa.screenshot({ path: gorsel });
    }
  } catch (e) {
    sonuc.hatalar.push('koşu: ' + String(e.message || e).split('\n')[0].slice(0, 300));
  }
  sonuc.uyarilar = [...new Set(uyarilar)].slice(0, 12);
  if (/(^|\n)HATA:/.test(sonuc.cikti)) sonuc.hatalar.push('çıktıda HATA: ' + (sonuc.cikti.match(/HATA:[^\n]*/) || [''])[0].slice(0, 200));
  if (sonuc.hatalar.length) sonuc.durum = 'kaldı';
  else if (!/TAMAM/.test(sonuc.cikti)) sonuc.durum = 'eksik'; // betik "TAMAM" yazmadı: erken bitti ya da takıldı
  console.log(JSON.stringify(sonuc));
  await tarayici.close();
  process.exit(0);
})().catch(e => { console.log(JSON.stringify({ durum: 'kaldı', hatalar: ['cizdir: ' + String(e.message || e)] })); process.exit(0); });
