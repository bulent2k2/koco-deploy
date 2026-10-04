// once_dene/tarayici/editor.js -- GERÇEK editör sayfasını, /resultframe'i ve /api kapısını sınar.
//
//   node editor.js <adres>        ör. http://127.0.0.1:7860  ya da  https://ikojo.fly.dev
//
// NEDEN: kapı (dene.sh -t) derlenmiş betiği KENDİ sahne.html'inde koşturur. Yani editör sayfasını,
// sonuç çerçevesinin sunucu başlıklarını ve /api kapısını hiç görmez; bu üç alandaki bir gerileme
// 22/22'yi bozmaz. Somut örnek kojojs-editor#51: #49 (v80) ve #52 (v81) "düzeltmeleri" kapıyı
// 22/22 ile geçip canlıya çıktı, belirti sürdü. Öbür ikisi aynı kör noktada:
//   - kojojs-editor#51  ilk "Çalıştır"da ses yok (çerçevede autoplay izni gelmiyordu)
//   - kojojs-editor#45  sonuç çerçevesi editörle aynı kökende koşuyordu (kum havuzu yoktu)
//   - kojojs-editor#47  /api'ye başka bir sitenin formu ulaşabiliyordu (CSRF)
//
// Çıktı (stdout): satır başına  ad<TAB>durum<TAB>ayrıntı
//   durum: geçti | kaldı | eksik
//   eksik = bir ÖNKOŞUL tutmadığı için ölçülemedi. dene.sh bunu da başarısızlık sayar: ölçülmeyen şey
//   geçmiş sayılmaz.
// Çıkış kodu: 0 (sınama tamamlandı, sonuç satırlarda), 2 (kullanım hatası). Hata sayısı çıkış koduna
// YANSIMAZ; kararı satırlara bakan dene.sh verir.
//
// Ortam: KOCO_CHROMIUM  Chromium yolu (yoksa Playwright'ın kendi tarayıcısı)
//        KOCO_ORNEK     açılacak örnek (öntanımlı /ornek/01-ilk-adimlar.kojo)
//
// Bilerek YOK: cizdir.js'teki --autoplay-policy bayrağı. Burada ölçülen şey çerçevenin İZİN POLİTİKASI
// (document.permissionsPolicy.allowsFeature("autoplay")), gerçek bir tarayıcının gördüğü değer.
const { chromium, request } = require('playwright');

const ADRES = (process.argv[2] || '').replace(/\/+$/, '');
if (!/^https?:\/\/[^/]+/.test(ADRES)) {
  console.error('kullanım: node editor.js <http(s)://adres>');
  process.exit(2);
}
const ORNEK = process.env.KOCO_ORNEK || '/ornek/01-ilk-adimlar.kojo';
const CALISTIR = 'div.ui.basic.button[title="Çalıştır"]';

const satirlar = [];
const yaz = (ad, durum, ayrinti) =>
  satirlar.push([ad, durum, String(ayrinti == null ? '' : ayrinti).replace(/[\t\r\n]+/g, ' ').slice(0, 300)]);
const eksik = (ad, neden) => yaz(ad, 'eksik', 'ölçülemedi: ' + neden);

// fn() -> [geçti mi, ayrıntı]. Fırlatırsa kaldı; bir sınamanın çökmesi ötekileri durdurmaz.
async function dene(ad, fn) {
  try {
    const [gecti, ayrinti] = await fn();
    yaz(ad, gecti ? 'geçti' : 'kaldı', ayrinti);
    return !!gecti;
  } catch (e) {
    yaz(ad, 'kaldı', 'hata: ' + String(e.message).split('\n')[0]);
    return false;
  }
}

async function bekle(kosul, saniye, ne) {
  const son = Date.now() + saniye * 1000;
  for (;;) {
    try { const v = await kosul(); if (v) return v; } catch (_) { /* bağlam yıkıldı: yeniden dene */ }
    if (Date.now() > son) throw new Error('zaman aşımı: ' + ne);
    await new Promise(r => setTimeout(r, 250));
  }
}

const altCerceve = s => s.frames().find(f => /\/resultframe/.test(f.url()));
const cerceveYuklendi = s =>
  bekle(async () => { const f = altCerceve(s); return f && (await f.evaluate(() => document.readyState)) === 'complete'; },
        60, 'sonuç çerçevesi yüklenmedi');
const autoplay = s => altCerceve(s).evaluate(() => {
  const p = document.permissionsPolicy || document.featurePolicy;
  return p ? String(p.allowsFeature('autoplay')) : 'politika-API-yok';
});

async function main() {
  const secenekler = {};
  if (process.env.KOCO_CHROMIUM) secenekler.executablePath = process.env.KOCO_CHROMIUM;
  const tarayici = await chromium.launch(secenekler);
  const api = await request.newContext();
  try {
    const koken = new URL(ADRES).origin;

    // ---- 1. Önkoşul: sayfa, kendi derleyicisini sınanan adreste arıyor mu
    // Yerel konteynerde start.sh adresi PUBLIC_URL'den (yoksa http://localhost:7860) gömer. Başka bir
    // adresten açılırsa "Çalıştır" derleme isteğini boş yere gider ve "Sunucuya ulaşılamadı" der.
    let compilerUrl = null;
    const sayfaTamam = await dene('editör-sayfası-açılıyor', async () => {
      const r = await api.get(ADRES + '/', { timeout: 30000 });
      const m = (await r.text()).match(/compilerURL\s*=\s*"([^"]*)"/);
      compilerUrl = m ? m[1] : null;
      return [r.status() === 200 && !!m, `HTTP ${r.status()}, compilerURL=${compilerUrl}`];
    });
    const adresTamam = await dene('derleyici-adresi-aynı-köken', async () => {
      if (!compilerUrl) return [false, 'sayfada compilerURL yok'];
      const o = new URL(compilerUrl).origin;
      return [o === koken, o === koken ? o
        : `sayfa derleyiciyi ${o} adresinde arıyor, sınanan adres ${koken}: yerel konteyneri PUBLIC_URL=${koken} ile başlatın (yoksa "Çalıştır" "Sunucuya ulaşılamadı" der)`];
    });

    // ---- 2. /resultframe: sunucu başlıkları ve opak köken (kojojs-editor#45)
    // Çerçeve kullanıcı kodunu çalıştırıyor; editörle aynı kökende olsaydı o kod oturumu açık
    // kullanıcının yetkisiyle editöre uzanırdı.
    const rfBaglam = await tarayici.newContext();
    const rf = await rfBaglam.newPage();
    let rfYanit = null;
    const rfAcildi = await dene('resultframe-açılıyor', async () => {
      rfYanit = await rf.goto(ADRES + '/resultframe', { waitUntil: 'load', timeout: 60000 });
      return [rfYanit.status() === 200, 'HTTP ' + rfYanit.status()];
    });
    if (rfAcildi) {
      await dene('resultframe-sandbox-başlığı', async () => {
        const csp = (await rfYanit.headersArray()).filter(h => h.name.toLowerCase() === 'content-security-policy').map(h => h.value);
        const sandbox = csp.some(v => /(^|;)\s*sandbox(\s|;|$)/.test(v));
        const ayniKoken = csp.some(v => /allow-same-origin/.test(v));
        return [sandbox && !ayniKoken, `${csp.length} CSP başlığı: ${csp.join(' | ') || '(yok)'}`];
      });
      await dene('resultframe-opak-köken', async () => {
        const o = await rf.evaluate(() => String(window.origin));
        return [o === 'null', 'window.origin=' + o];
      });
      await dene('resultframe-betik-koşuyor', async () => {
        // Satır içi <script> kum havuzunun allow-scripts'ine tabi; CDP evaluate değil (o kısıtı aşar)
        const v = await rf.evaluate(() => {
          const s = document.createElement('script');
          s.textContent = 'window.__sinama = 42';
          document.head.appendChild(s);
          return window.__sinama;
        });
        return [v === 42, 'betik etiketi ' + (v === 42 ? 'çalıştı' : 'çalışmadı')];
      });
      await dene('resultframe-varlıklar-opak-kökenden', async () => {
        // Opak kökenden istek CORS ister (nginx /assets/ ve /media/ için Access-Control-Allow-Origin: *)
        const yollar = ['/assets/javascript/pixi.min.js', '/media/collidium/hit.mp3'];
        const sonuc = await rf.evaluate(async ([adres, liste]) => {
          const cikti = [];
          for (const y of liste) {
            try { const r = await fetch(adres + y); cikti.push([y, r.ok, r.type]); }
            catch (e) { cikti.push([y, false, 'HATA']); }
          }
          return cikti;
        }, [ADRES, yollar]);
        return [sonuc.every(x => x[1]), sonuc.map(x => `${x[0]} ${x[1] ? 'ok' : 'YOK'}/${x[2]}`).join(', ')];
      });
      await dene('resultframe-pixi-yükleniyor', async () => {
        const s = await rf.evaluate(adres => new Promise(res => {
          const e = document.createElement('script');
          e.src = adres + '/assets/javascript/pixi.min.js';
          e.onload = () => res(window.PIXI ? 'PIXI ' + PIXI.VERSION : 'PIXI tanımsız');
          e.onerror = () => res('yüklenemedi');
          document.head.appendChild(e);
          setTimeout(() => res('zaman aşımı'), 30000);
        }), ADRES);
        return [/^PIXI \d/.test(s), s];
      });
    } else {
      ['resultframe-sandbox-başlığı', 'resultframe-opak-köken', 'resultframe-betik-koşuyor',
       'resultframe-varlıklar-opak-kökenden', 'resultframe-pixi-yükleniyor']
        .forEach(a => eksik(a, 'resultframe açılmadı'));
    }

    // ---- 3. Editör: taze sayfada İLK ve ikinci "Çalıştır" (kojojs-editor#51)
    // Çocuğun programı sonuç çerçevesinde koşar; ses için çerçevenin autoplay izni olmalı. İzin
    // `allow` özniteliğiyle verilir ve yalnız GEZİNMEDEN ÖNCE yazılmışsa geçerli olur. Ölçüt: ilk
    // koşuda allowsFeature("autoplay") == true ve /resultframe'e TEK belge isteği (#52 iki gönderiyordu).
    const KOSU = ['ilk-koşu-kod-dalı', 'ilk-koşu-allow-özniteliği', 'ilk-koşu-sandbox-özniteliği',
                  'ilk-koşu-autoplay-izni', 'ilk-koşu-tek-belge-isteği', 'ikinci-koşu-autoplay-izni',
                  'ikinci-koşu-tek-ek-istek', 'editör-sayfa-hatası-yok'];
    if (!sayfaTamam || !adresTamam) {
      KOSU.forEach(a => eksik(a, 'önkoşul tutmadı (editör-sayfası-açılıyor / derleyici-adresi-aynı-köken)'));
    } else {
      const sayfa = await (await tarayici.newContext()).newPage();   // taze bağlam: önbellek/çerez yok
      const sayfaHatalari = [];
      let belgeIstegi = 0;
      sayfa.on('pageerror', e => sayfaHatalari.push(String(e.message).split('\n')[0].slice(0, 120)));
      sayfa.on('request', r => { if (r.resourceType() === 'document' && /\/resultframe(\?|$)/.test(r.url())) belgeIstegi++; });
      const oznitelik = a => sayfa.evaluate(x => document.getElementById('resultframe').getAttribute(x), a);

      let kodDali = false;
      try {
        await sayfa.goto(ADRES + ORNEK, { waitUntil: 'load', timeout: 60000 });
        await sayfa.waitForSelector('#resultframe', { timeout: 30000 });
        await sayfa.click(CALISTIR, { timeout: 20000 });
        kodDali = await dene('ilk-koşu-kod-dalı', async () => {
          await bekle(() => sayfa.evaluate(() => {
            const f = document.getElementById('resultframe');
            return f && f.getAttribute('data-frameid') === 'frame-code';
          }), 120, 'frame-code gelmedi (derleme sonuç vermedi mi?)');
          await cerceveYuklendi(sayfa);
          // Gezinme yeniden başlatan bir "düzeltme" (#52) ikinci isteği burada gönderir; gelmesini bekle
          await sayfa.waitForTimeout(3000);
          return [true, 'frame-code'];
        });
      } catch (e) {
        yaz('ilk-koşu-kod-dalı', 'kaldı', 'hata: ' + String(e.message).split('\n')[0]);
      }

      if (!kodDali) {
        KOSU.slice(1, 7).forEach(a => eksik(a, 'ilk-koşu-kod-dalı tutmadı'));
      } else {
        await dene('ilk-koşu-allow-özniteliği', async () => {
          const a = await oznitelik('allow');
          return [/\bautoplay\b/.test(a || ''), 'allow=' + JSON.stringify(a)];
        });
        await dene('ilk-koşu-sandbox-özniteliği', async () => {
          const sb = (await oznitelik('sandbox')) || '';
          const kotu = sb.split(/\s+/).filter(t => /^allow-(same-origin|popups-to-escape-sandbox|top-navigation)/.test(t));
          return [/\ballow-scripts\b/.test(sb) && kotu.length === 0,
                  'sandbox=' + JSON.stringify(sb) + (kotu.length ? ' -- istenmeyen: ' + kotu.join(',') : '')];
        });
        await dene('ilk-koşu-autoplay-izni', async () => {
          const v = await autoplay(sayfa);
          return [v === 'true', 'allowsFeature("autoplay")=' + v];
        });
        await dene('ilk-koşu-tek-belge-isteği', async () => [belgeIstegi === 1, '/resultframe belge isteği=' + belgeIstegi]);

        let ek = null;
        await dene('ikinci-koşu-autoplay-izni', async () => {
          const onceki = belgeIstegi;
          await sayfa.click(CALISTIR, { timeout: 20000 });
          await bekle(() => belgeIstegi > onceki, 30, 'ikinci koşuda çerçeve yeniden yüklenmedi');
          await cerceveYuklendi(sayfa);
          await sayfa.waitForTimeout(3000);
          ek = belgeIstegi - onceki;
          const v = await autoplay(sayfa);
          return [v === 'true', 'allowsFeature("autoplay")=' + v];
        });
        if (ek === null) eksik('ikinci-koşu-tek-ek-istek', 'ikinci koşu ölçülemedi');
        else await dene('ikinci-koşu-tek-ek-istek', async () => [ek === 1, 'ek belge isteği=' + ek]);
        // Taze kurulumda kod çerçevesi mount edilirken fırlayan bir hata ilk koşuyu sessizce bozabilir
        await dene('editör-sayfa-hatası-yok', async () =>
          [sayfaHatalari.length === 0, sayfaHatalari.slice(0, 3).join(' | ') || 'yok']);
      }
    }

    // ---- 4. /api kapısı (kojojs-editor#47): başka bir sitenin formu ve opak çerçeve geçemesin
    // Kural (ApiGuard.izinli): "X-Requested-With: koco" şart, Origin "null" olamaz. /api CORS'a açık
    // değil: özel başlık yalnız ön-uçuşla eklenebilir ve ön-uçuş reddedilir. Yol uydurma: kapı yola
    // bakmadan karar verir, gerçek bir uca dokunmuyoruz.
    const apiUrl = ADRES + '/api/once_dene';
    const istek = (yontem, basliklar) => api.fetch(apiUrl, {
      method: yontem, headers: basliklar, data: yontem === 'POST' ? '{}' : undefined,
      failOnStatusCode: false, maxRedirects: 0, timeout: 30000,
    });
    const J = { 'Content-Type': 'application/json' };
    await dene('api-başlıksız-reddediliyor', async () => {
      const r = await istek('POST', J); return [r.status() === 403, 'HTTP ' + r.status()];
    });
    await dene('api-yanlış-değer-reddediliyor', async () => {
      const r = await istek('POST', { ...J, 'X-Requested-With': 'XMLHttpRequest' });
      return [r.status() === 403, 'HTTP ' + r.status() + ' (X-Requested-With: XMLHttpRequest)'];
    });
    await dene('api-doğru-başlık-kapıdan-geçiyor', async () => {
      const r = await istek('POST', { ...J, 'X-Requested-With': 'koco' });
      // 403 olmaması yeter: yol uydurma, gövde boş; kapıdan geçince 4xx/5xx başka sebeple dönebilir
      return [r.status() !== 403, 'HTTP ' + r.status() + ' (kapı geçildi; yanıtın kendisi ölçülmüyor)'];
    });
    await dene('api-opak-köken-reddediliyor', async () => {
      const r = await istek('POST', { ...J, 'X-Requested-With': 'koco', Origin: 'null' });
      return [r.status() === 403, 'HTTP ' + r.status() + ' (Origin: null)'];
    });
    await dene('api-cors-ön-uçuşu-yok', async () => {
      const r = await istek('OPTIONS', {
        Origin: 'https://baska-site.example', 'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'x-requested-with',
      });
      const acao = r.headers()['access-control-allow-origin'];
      return [!acao && !r.ok(), `HTTP ${r.status()}, Access-Control-Allow-Origin=${acao || '(yok)'}`];
    });
  } finally {
    await api.dispose().catch(() => {});
    await tarayici.close().catch(() => {});
  }
}

main()
  .catch(e => yaz('editor.js', 'kaldı', 'sınama çöktü: ' + String(e.message).split('\n')[0]))
  .then(() => { process.stdout.write(satirlar.map(s => s.join('\t')).join('\n') + '\n'); });
