import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, rename, stat, unlink, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 8787);
let ADMIN_PASS = ''; // main() içinde çözülür
const DATA_DIR = join(__dirname, 'data');
const PUBLIC_DIR = join(__dirname, 'public');
const MAX_BODY = 25 * 1024 * 1024; // mutlak üst sınır
const MAX_JSON_BODY = {
  general: 1 * 1024 * 1024, // login, kullanıcı, mesaj
  requests: 20 * 1024 * 1024, // base64 fotoğraflı istekler
  config: 8 * 1024 * 1024, // panel yapılandırması
};
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;
const APK_DIR = join(__dirname, 'apk');
const APK_FILE = join(APK_DIR, 'neredekilacagim-latest.apk');
const MAX_APK_SIZE = 200 * 1024 * 1024;

// ---- güvenlik ----
// Yönetici şifresi: 1) ADMIN_PASS ortam değişkeni, 2) data/.admin-pass dosyası,
// 3) biri yoksa ilk açılışta rastgele üretilir ve data/.admin-pass dosyasına yazılır.
// Şifre zayıfsa sunucu yalnızca 127.0.0.1'de dinler (paneli internete açmaz).
const WEAK_PASSWORDS = new Set(['', '002011', 'admin', 'password', '123456', '12345678', '1234']);
const ALLOW_WEAK_ADMIN_PASS = process.env.ALLOW_WEAK_ADMIN_PASS === '1';
const TRUST_PROXY = process.env.TRUST_PROXY === '1'; // X-Forwarded-For'a güven (nginx/caddy arkasında)
const PASS_FILE = join(DATA_DIR, '.admin-pass');

// Uygulama belleğinin (in-memory) DoS'a karşı bant genişliği limitleri.
const RL = {
  static: { max: 240, window: 60_000 }, // panel + statik
  apk: { max: 30, window: 60_000 }, // 200 MB'lik dosyaların indirilmesi
  write: { max: 20, window: 60_000 }, // public POST (istek/mesaj/kullanıcı)
  writeDay: { max: 500, window: 86_400_000 }, // IP başına günlük yazma
  admin: { max: 200, window: 60_000 }, // yönetici uçları
  login: { max: 10, window: 60_000 }, // genel giriş
  loginFail: { max: 5, window: 900_000 }, // 5 başarısız → 15 dk kilit
};
const STORE_MAX = { requests: 200_000, messages: 50_000, users: 100_000 };
const MAX_PHOTO_CHARS = 8_000_000; // tek foto (base64)
const MAX_PHOTO_TOTAL_CHARS = 12_000_000; // istek başına toplam foto (base64)

const DEFAULT_CONFIG = {
  maintenance: { enabled: false, message: 'Bakım çalışması nedeniyle uygulama geçici olarak hizmet dışıdır. Lütfen kısa süre sonra tekrar deneyin.' },
  announcement: { enabled: false, text: '' },
  faq: [
    {
      q: 'Nerede Kılacağım? nedir?',
      a: 'Nerede Kılacağım?, bulunduğunuz konuma en yakın cami ve mescitleri gösteren, Diyanet namaz vakitlerini sunan, mescitleri puanlamanızı ve favorilere eklemenizi sağlayan bir uygulamadır.',
    },
    {
      q: 'Namaz vakitleri nasıl belirleniyor?',
      a: 'Vakitler ülke genelinde kullanılan ezan vakitleri veri kaynaklarından (imsakiyem ve emüşaf) çekilir ve konumunuza en yakın ilçenin vakitleri gösterilir.',
    },
    {
      q: 'Konumum nasıl kullanılıyor?',
      a: 'Konumunuz yalnızca yakınınızdaki mescitleri listelemek ve namaz vakti ilçenizi bulmak için kullanılır. Konum bilgisi sunucularımızda saklanmaz; yalnızca cihazınızda işlenir.',
    },
    {
      q: 'Mescit nasıl ekleyebilirim veya puanlayabilirim?',
      a: 'Alt menüdeki "Mescit Ekle" butonu ile yeni mescit ekleyebilir; bir mescide yaklaştığınızda çıkan puanlama ekranını kullanarak gerçek yerinde iken puanlayabilirsiniz.',
    },
    {
      q: 'Hesap oluşturmak zorunlu mu?',
      a: 'Evet, puanlamaların ve favorilerin hesabınıza bağlanması için giriş yapmanız gerekir. Kayıt e-posta ve şifre ile yapılır; şifreniz cihazınızda düz metin olarak değil, tuzlanmış özet (hash) olarak saklanır.',
    },
  ],
  about: {
    title: 'Hakkımızda',
    lede: 'Nerede Kılacağım? bir topluluk girişimidir.',
    blocks: [
      {
        title: 'Amacımız',
        text: 'Şehirde, yolda veya tatilde iken en yakın cami ve mescidi kolayca bulabilmek; namaz vakitlerini tek ekrandan öğrenebilmek ve mescitlerin temizlik, erişilebilirlik ve abdest imkânı gibi özelliklerini kullanıcı puanlarıyla paylaşabilmek.',
      },
      {
        title: 'Nasıl Çalışıyor?',
        text: 'Mescitler OpenStreetMap gibi açık veri kaynaklarından çekilir, namaz vakitleri kamuya açık ezan vakitleri servislerinden alınır. Tüm uygulama tek bir ekrandan çalışır ve verileriniz cihazınızda kalır.',
      },
      {
        title: 'Topluluk & Ekip',
        text: 'Nerede Kılacağım? gönüllülerden oluşan küçük bir ekiple geliştirilir. Yeni fikirleriniz, geri bildirimleriniz ve hata bildirimleriniz bizim için çok değerli. Bize iletişim sayfasından ulaşabilirsiniz.',
      },
    ],
  },
  privacy: {
    title: 'Gizlilik Politikası',
    lede: 'Verilerinizin nasıl işlendiğini şeffaf biçimde açıklıyoruz.',
    blocks: [
      {
        title: '1. Hangi veriler saklanıyor?',
        text: 'Hesap bilgileriniz (ad, e-posta, şifre), mescit puanlarınız, favorileriniz ve eklediğiniz kayıtlar yalnızca cihazınızın yerel depolama alanında saklanır. Sunucularımızda hesap verisi tutulmaz.',
      },
      {
        title: '2. Konum bilgisi',
        text: 'Konumunuz yalnızca yakınınızdaki mescitleri ve namaz vakitlerini bulmak için kullanılır; saklanmaz ve üçüncü kişilere aktarılmaz. İzin vermezseniz IP tabanlı yaklaşık konum ile devam edebilirsiniz.',
      },
      {
        title: '3. Üçüncü taraf hizmetleri',
        text: 'Harita (OpenStreetMap), mescit verisi (Overpass API), rota (OSRM), namaz vakitleri (imsakiyem / emüşaf) ve konum tahmini hizmetlerinden yararlanılır. Bu hizmetler kendi gizlilik politikalarına tabidir.',
      },
      {
        title: '4. Çerezler ve izleme',
        text: 'Uygulama üçüncü taraf reklam ya da izleme çerezi kullanmaz. Verilerinizi üçüncü kişilere satmayız.',
      },
      {
        title: '5. Haklarınız',
        text: 'Verilerinizi istediğiniz zaman "Hesabımı Sil" butonuyla veya uygulama verilerini temizleyerek kalıcı olarak silebilirsiniz.',
      },
      {
        title: '6. Kullanım Şartları',
        text: 'Uygulamanın kullanım koşulları ayrı bir sayfada toplanmıştır.',
      },
    ],
  },
  terms: {
    title: 'Kullanım Şartları',
    lede: 'Nerede Kılacağım? hizmetinin kullanım koşulları. Uygulamayı kullanarak bu şartları kabul etmiş sayılırsınız.',
    blocks: [
      {
        title: '1. Hizmet kapsamı',
        text: 'Nerede Kılacağım?, çevrenizdeki cami ve mescitleri gösteren, namaz vakitlerini sunan, mescit puanlama ve favorilere ekleme imkânı veren bir uygulamadır. Hizmet; harita (OpenStreetMap), açık mescit verileri (Overpass API) ve namaz vakti sağlayıcıları üzerine kuruludur.',
      },
      {
        title: '2. Veri kaynağı',
        text: 'Mescit bilgileri açık kaynaklardan (OpenStreetMap ve diğerleri) gelir; bu bilgiler hatalı veya güncel olmayabilir. Görünürlük için eklenen örnek kayıtlar "örnek" olarak işaretlenir ve kaldırılabilir. Haritayı kullanırken doğruluğu kendi sorumluluğunuzda teyit edin.',
      },
      {
        title: '3. Hesap ve içerik',
        text: 'Hesap verileriniz yalnızca cihazınızın yerel depolama alanında tutulur. Mescit puanlama ve ekleme özellikleri yalnızca doğru ve iyi niyetli kullanım içindir; yanlış bilgi, sahte puanlama ve kötüye kullanım yasaktır ve hesabın kapatılmasıyla sonuçlanabilir.',
      },
      {
        title: '4. Sorumluluk',
        text: 'Uygulama "olduğu gibi" sunulur. Namaz vakti, mescit konumu, adres veya yön bulma bilgilerindeki hatalardan, eksikliklerden ya da kullanımdan kaynaklanan zararlardan sorumluluk kabul edilmez.',
      },
      {
        title: '5. Fikri mülkiyet',
        text: 'Uygulama adı, arayüz ve marka öğeleri Nerede Kılacağım?e aittir. Harita ve mescit verileri açık lisanslarla korunur; kendi lisans koşullarına tabidir.',
      },
      {
        title: '6. Değişiklikler',
        text: 'Bu şartlar değiştirildiğinde bu sayfa güncellenir; kullanımı sürdürdüğünüzde güncel şartları kabul etmiş sayılırsınız. Şartların bir bölümünün geçersiz sayılması diğer bölümleri etkilemez.',
      },
      {
        title: '7. İletişim',
        text: 'Şartlarla ilgili sorularınız için iletişim sayfasını kullanabilirsiniz.',
      },
    ],
  },
  branding: {
    appName: 'Nerede K\u0131lcam?',
  },
  ui: {
    heroVakitTitle: 'Bug\u00FCn\u00FCn vakitleri',
    contactLede: 'Mescit ekleme, puanlama, hata bildirimi veya i\u015F birli\u011Fi i\u00E7in bize yaz\u0131n. Genellikle 1 i\u015F g\u00FCn\u00FC i\u00E7inde d\u00F6n\u00FC\u015F yap\u0131yoruz.',
  },
  features: {
    addMosque: true,
    reviews: true,
    photos: true,
    favorites: true,
    contact: true,
  },
  prayerSource: 'auto',
  links: [],
  minVersion: '',
  update: {
    latestVersion: '',
    minVersion: '',
    url: '',
    note: '',
    apkUrl: '',
    apkSha: '',
    apkSize: 0,
    modified: 0,
  },
  updatedAt: 0,
};

// ---------- depo ----------
const stores = {};

let mutex = Promise.resolve();
function withLock(fn) {
  const run = mutex.then(fn, fn);
  mutex = run.catch(() => {});
  return run;
}

async function loadStore(name) {
  if (stores[name]) return stores[name].data;
  const file = join(DATA_DIR, `${name}.json`);
  let raw = null;
  try {
    raw = await readFile(file, 'utf8');
  } catch {
    raw = null;
  }
  let parsed;
  try {
    parsed = raw ? JSON.parse(raw) : { nextId: 1, items: [] };
  } catch {
    parsed = { nextId: 1, items: [] };
  }
  if (!Array.isArray(parsed.items)) parsed.items = [];
  if (typeof parsed.nextId !== 'number') parsed.nextId = 1;
  stores[name] = { data: parsed, file };
  return parsed;
}

async function saveStore(name) {
  const entry = stores[name];
  if (!entry) return;
  await mkdir(DATA_DIR, { recursive: true });
  const tmp = `${entry.file}.${process.pid}.tmp`;
  await writeFile(tmp, JSON.stringify(entry.data, null, 2), 'utf8');
  await rename(tmp, entry.file);
}

function nextId(store) {
  const id = store.nextId;
  store.nextId += 1;
  return id;
}

// ---------- uygulama yapılandırması ----------
const CONFIG_FILE = join(DATA_DIR, 'config.json');
let configStore = null; // { config }

async function loadConfig() {
  if (configStore) return configStore.config;
  let config = null;
  try {
    const raw = await readFile(CONFIG_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) config = parsed;
  } catch {
    config = null;
  }
  if (!config) config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
  configStore = { config };
  return config;
}

async function saveConfig(config) {
  await mkdir(DATA_DIR, { recursive: true });
  const tmp = `${CONFIG_FILE}.${process.pid}.tmp`;
  await writeFile(tmp, JSON.stringify(config, null, 2), 'utf8');
  await rename(tmp, CONFIG_FILE);
  configStore = { config };
}

function cleanSection(v, fallback) {
  if (!v || typeof v !== 'object') return JSON.parse(JSON.stringify(fallback));
  const blocks = Array.isArray(v.blocks)
    ? v.blocks
        .map((b) => ({
          title: String((b && b.title) || '').trim().slice(0, 250),
          text: String((b && b.text) || '').trim().slice(0, 6000),
        }))
        .filter((b) => b.title || b.text)
        .slice(0, 100)
    : [];
  return {
    title: String(v.title || fallback.title || '').trim().slice(0, 200) || fallback.title,
    lede: String(v.lede || fallback.lede || '').trim().slice(0, 800) || fallback.lede,
    blocks,
  };
}

// ---------- oturum ----------
const sessions = new Map(); // token -> expiresAt

function authenticate(req) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!token) return false;
  const exp = sessions.get(token);
  if (!exp) return false;
  if (Date.now() > exp) {
    sessions.delete(token);
    return false;
  }
  return true;
}

// ---------- güvenlik: IP, throttle, başlıklar ----------
function clientIp(req) {
  if (TRUST_PROXY) {
    const xff = req.headers['x-forwarded-for'];
    if (typeof xff === 'string' && xff) {
      const first = xff.split(',')[0].trim();
      if (first) return first;
    }
    const ri = req.headers['x-real-ip'];
    if (typeof ri === 'string' && ri) return ri.trim();
  }
  return (req.socket.remoteAddress || '').replace(/^::ffff:/, '');
}

// IP + anahtar bazlı sabit pencere throttle'ı.
const rateBuckets = new Map(); // "key|ip" -> { count, resetAt }
function takeRate(key, ip, max, windowMs) {
  const now = Date.now();
  const k = `${key}|${ip}`;
  let b = rateBuckets.get(k);
  if (!b || now >= b.resetAt) {
    b = { count: 1, resetAt: now + windowMs };
    rateBuckets.set(k, b);
    return { ok: true, retryAfter: 0 };
  }
  b.count += 1;
  if (b.count <= max) return { ok: true, retryAfter: 0 };
  return { ok: false, retryAfter: Math.ceil((b.resetAt - now) / 1000) };
}

// Limite takılınca 429 döner; sender tarafı tek satırla istekten çıkar.
function sentRate(res, key, ip, max, windowMs) {
  const r = takeRate(key, ip, max, windowMs);
  if (r.ok) return false;
  res.setHeader('Retry-After', String(r.retryAfter));
  res.setHeader('Connection', 'close');
  sendJson(res, 429, { error: 'rate limited' });
  return true;
}

const loginLocks = new Map(); // ip -> { fails, until }
function loginLocked(ip) {
  const l = loginLocks.get(ip);
  return l && l.until && Date.now() < l.until;
}
function loginFail(ip) {
  const l = loginLocks.get(ip) || { fails: 0, until: 0 };
  l.fails += 1;
  if (l.fails >= RL.loginFail.max) {
    l.until = Date.now() + RL.loginFail.window;
    l.fails = 0;
  }
  loginLocks.set(ip, l);
}
function loginOk(ip) {
  loginLocks.delete(ip);
}

function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return timingSafeEqual(ba, bb);
}

function setCommonHeaders(res) {
  if (!res.headersSent) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Permissions-Policy', 'geolocation=(self), camera=(), microphone=(), payment=()');
    res.setHeader('Cache-Control', 'no-store');
  }
}

// Yüklenen verinin gerçekten Android APK'sı olduğuna dair öz imzalar.
function looksLikeApk(buf) {
  if (!buf || buf.length < 8192) return false;
  if (buf[0] !== 0x50 || buf[1] !== 0x4b) return false; // ZIP: "PK"
  if (!buf.includes(Buffer.from('AndroidManifest.xml'))) return false;
  return buf.includes(Buffer.from('classes.dex'));
}

// Depo büyüklüğünü sınırla (en eski kayıtlar düşer) → disk/DoS koruması.
function capStore(store, name) {
  const max = STORE_MAX[name];
  if (max && store.items.length > max) store.items = store.items.slice(-max);
}

// Dönemsel temizlik: süresi dolan oturumlar, throttle kovaları, giriş kilitleri.
setInterval(() => {
  const now = Date.now();
  for (const [t, exp] of sessions) if (now > exp) sessions.delete(t);
  for (const [k, b] of rateBuckets) if (now >= b.resetAt) rateBuckets.delete(k);
  for (const [ip, l] of loginLocks) if (l.until && now >= l.until) loginLocks.delete(ip);
  if (rateBuckets.size > 100_000) rateBuckets.clear();
}, 60_000).unref();

function sendJson(res, status, body) {
  const out = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(out);
}

function readBody(req, maxBytes = MAX_BODY) {
  const limit = maxBytes || MAX_BODY;
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        reject(new Error('BODY_TOO_LARGE'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (chunks.length === 0) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new Error('BAD_JSON'));
      }
    });
    req.on('error', reject);
  });
}

// JSON uçları için içerik türü zorunluluğu (form/çok parçalı gövde kabul edilmez).
function jsonOnly(req) {
  const h = (req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
  return h === 'application/json';
}

function readBinaryBody(req, maxSize) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > maxSize) {
        reject(new Error('APK_TOO_LARGE'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function validateRequest(b) {
  const name = typeof b.name === 'string' ? b.name.trim().slice(0, 150) : '';
  const lat = Number(b.lat);
  const lng = Number(b.lng);
  if (!name) throw new Error('name required');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new Error('lat/lng required');
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) throw new Error('lat/lng out of range');
  const tags = Array.isArray(b.tags)
    ? b.tags.map((t) => String(t).slice(0, 60)).filter((t) => t.trim()).slice(0, 10)
    : [];
  let photoTotal = 0;
  const photos = Array.isArray(b.photos)
    ? b.photos
        .map((p) => {
          const s = String(p);
          const limited = s.length > MAX_PHOTO_CHARS ? s.slice(0, MAX_PHOTO_CHARS) : s;
          photoTotal += limited.length;
          return limited;
        })
        .slice(0, 3)
    : [];
  if (photoTotal > MAX_PHOTO_TOTAL_CHARS) throw new Error('photos too large');
  const ts = Number.isFinite(Number(b.ts)) && Number(b.ts) > 0 ? Math.min(Number(b.ts), Date.now() + 10 * 365 * 24 * 3600 * 1000) : Date.now();
  return {
    email: typeof b.email === 'string' ? b.email.trim().slice(0, 200) : '',
    name,
    type: typeof b.type === 'string' && b.type.trim() ? b.type.trim().slice(0, 60) : 'Mescit',
    tags,
    lat,
    lng,
    photos,
    ts,
  };
}

function validateMessage(b) {
  const msg = typeof b.msg === 'string' ? b.msg.trim() : '';
  if (!msg) throw new Error('msg required');
  return {
    name: typeof b.name === 'string' ? b.name.trim().slice(0, 120) : '',
    email: typeof b.email === 'string' ? b.email.trim().slice(0, 200) : '',
    msg: msg.slice(0, 4000),
    ts: Number.isFinite(Number(b.ts)) && Number(b.ts) > 0 ? Number(b.ts) : Date.now(),
  };
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
};

async function serveStatic(res, urlPath, method = 'GET') {
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const file = resolve(join(PUBLIC_DIR, rel));
  if (!file.startsWith(resolve(PUBLIC_DIR))) {
    res.writeHead(403);
    return res.end('forbidden');
  }
  try {
    const body = await readFile(file);
    const type = MIME[extname(file).toLowerCase()] || 'application/octet-stream';
    const headers = { 'Content-Type': type, 'Cache-Control': 'no-store' };
    if (type.includes('text/html')) {
      headers['Content-Security-Policy'] =
        "default-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; " +
        "script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'";
    }
    res.writeHead(200, headers);
    if (method === 'HEAD') return res.end();
    res.end(body);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('not found');
  }
}

const server = createServer(async (req, res) => {
  const method = req.method || 'GET';
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname;
  const t0 = Date.now();
  const ip = clientIp(req);
  setCommonHeaders(res);
  const logIp = ip.replace(/[\r\n]/g, '');
  const logPath = path.replace(/[\r\n]/g, '');
  res.on('finish', () => {
    console.log(`${new Date().toISOString()} ${method} ${logPath} -> ${res.statusCode} ${Date.now() - t0}ms from ${logIp}`);
  });

  try {
    // Desteklenmeyen HTTP yöntemlerini (TRACE, OPTIONS, PATCH, CONNECT...) erken reddet.
    if (!['GET', 'HEAD', 'POST', 'PUT', 'DELETE'].includes(method)) {
      res.setHeader('Allow', 'GET, HEAD, POST, PUT, DELETE');
      return sendJson(res, 405, { error: 'method not allowed' });
    }

    // ---- güncelleme APK'sı (halka açık; uygulama panelden indirir) ----
    if ((method === 'GET' || method === 'HEAD') && path === '/apk/latest.apk') {
      if (sentRate(res, 'apk', ip, RL.apk.max, RL.apk.window)) return;
      try {
        const body = await readFile(APK_FILE);
        res.writeHead(200, {
          'Content-Type': 'application/vnd.android.package-archive',
          'Content-Length': body.length,
          'Content-Disposition': 'attachment; filename="neredekilacagim-latest.apk"',
          'Cache-Control': 'no-store',
        });
        if (method === 'HEAD') return res.end();
        return res.end(body);
      } catch {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        return res.end('apk not found');
      }
    }

    // ---- statik (özellikle panel) ----
    if (!path.startsWith('/api/')) {
      if (method !== 'GET' && method !== 'HEAD') {
        res.writeHead(405);
        return res.end('method not allowed');
      }
      if (sentRate(res, 'static', ip, RL.static.max, RL.static.window)) return;
      return await serveStatic(res, path, method);
    }

    // ---- giriş ----
    if (method === 'POST' && path === '/api/login') {
      if (sentRate(res, 'login', ip, RL.login.max, RL.login.window)) return;
      if (loginLocked(ip)) {
        res.setHeader('Retry-After', String(Math.ceil((loginLocks.get(ip).until - Date.now()) / 1000)));
        res.setHeader('Connection', 'close');
        return sendJson(res, 429, { error: 'rate limited' });
      }
      if (!jsonOnly(req)) return sendJson(res, 415, { error: 'content type must be application/json' });
      const b = await readBody(req, MAX_JSON_BODY.general);
      if (b.password && safeEqual(b.password, ADMIN_PASS)) {
        loginOk(ip);
        const token = randomBytes(24).toString('hex');
        if (sessions.size >= 2000) {
          const oldest = sessions.keys().next().value;
          if (oldest) sessions.delete(oldest);
        }
        sessions.set(token, Date.now() + SESSION_TTL_MS);
        return sendJson(res, 200, { token });
      }
      loginFail(ip);
      return sendJson(res, 401, { error: 'wrong password' });
    }

    // ---- istekler (uygulamadan, halka açık) ----
    if (method === 'POST' && path === '/api/requests') {
      if (sentRate(res, 'write', ip, RL.write.max, RL.write.window)) return;
      if (sentRate(res, 'write_day', ip, RL.writeDay.max, RL.writeDay.window)) return;
      if (!jsonOnly(req)) return sendJson(res, 415, { error: 'content type must be application/json' });
      const b = await readBody(req, MAX_JSON_BODY.requests);
      const rec = validateRequest(b);
      await withLock(async () => {
        const store = await loadStore('requests');
        store.items.push({ id: nextId(store), status: 'beklemede', ...rec });
        capStore(store, 'requests');
        await saveStore('requests');
      });
      return sendJson(res, 201, { ok: true });
    }

    // ---- kullanıcılar (uygulamadan, halka açık: kayıt/giriş senkronu) ----
    if (method === 'POST' && path === '/api/users') {
      if (sentRate(res, 'write', ip, RL.write.max, RL.write.window)) return;
      if (sentRate(res, 'write_day', ip, RL.writeDay.max, RL.writeDay.window)) return;
      if (!jsonOnly(req)) return sendJson(res, 415, { error: 'content type must be application/json' });
      const b = await readBody(req, MAX_JSON_BODY.general);
      const email = typeof b.email === 'string' ? b.email.trim().toLowerCase().slice(0, 200) : '';
      if (!email) return sendJson(res, 400, { error: 'email required' });
      const user = {
        email,
        name: typeof b.name === 'string' ? b.name.trim().slice(0, 120) : '',
        salt: typeof b.salt === 'string' ? b.salt.slice(0, 200) : '',
        passHash: typeof b.passHash === 'string' ? b.passHash.slice(0, 200) : '',
        createdAt: Number.isFinite(Number(b.createdAt)) && Number(b.createdAt) > 0 ? Number(b.createdAt) : Date.now(),
        lastSeen: Date.now(),
      };
      await withLock(async () => {
        const store = await loadStore('users');
        const idx = store.items.findIndex((u) => u.email === email);
        if (idx >= 0) {
          if (user.name) store.items[idx].name = user.name;
          if (user.salt) store.items[idx].salt = user.salt;
          if (user.passHash) store.items[idx].passHash = user.passHash;
          store.items[idx].lastSeen = Date.now();
        } else {
          store.items.push(user);
        }
        capStore(store, 'users');
        await saveStore('users');
      });
      return sendJson(res, 201, { ok: true });
    }

    // ---- mesajlar (uygulamadan, halka açık) ----
    if (method === 'POST' && path === '/api/messages') {
      if (sentRate(res, 'write', ip, RL.write.max, RL.write.window)) return;
      if (sentRate(res, 'write_day', ip, RL.writeDay.max, RL.writeDay.window)) return;
      if (!jsonOnly(req)) return sendJson(res, 415, { error: 'content type must be application/json' });
      const b = await readBody(req, MAX_JSON_BODY.general);
      const rec = validateMessage(b);
      await withLock(async () => {
        const store = await loadStore('messages');
        store.items.push({ id: nextId(store), ...rec });
        capStore(store, 'messages');
        await saveStore('messages');
      });
      return sendJson(res, 201, { ok: true });
    }

    // ---- uygulama yapılandırması (uygulamadan, halka açık) ----
    if (method === 'GET' && path === '/api/config') {
      const config = await loadConfig();
      config.update = config.update || JSON.parse(JSON.stringify(DEFAULT_CONFIG.update));
      // APK dosyası sunucuda varsa ve adres tanımlı değilse otomatik doldur.
      if (!config.update.apkUrl) {
        try {
          await stat(APK_FILE);
          config.update.apkUrl = '/apk/latest.apk';
        } catch {}
      }
      return sendJson(res, 200, config);
    }

    // ---- onaylı mescit önerileri (uygulamadan, halka açık; e-posta/foto hariç) ----
    if (method === 'GET' && path === '/api/approved') {
      const store = await loadStore('requests');
      const items = store.items
        .filter((r) => r.status === 'onaylı')
        .map((r) => ({
          id: r.id,
          name: r.name,
          type: r.type,
          tags: r.tags,
          lat: r.lat,
          lng: r.lng,
          ts: r.ts,
        }));
      return sendJson(res, 200, { items });
    }

    // ---- aşağısı yönetici ----
    if (sentRate(res, 'admin', ip, RL.admin.max, RL.admin.window)) return;
    if (!authenticate(req)) {
      return sendJson(res, 401, { error: 'unauthorized' });
    }

    // ---- uygulama yapılandırması (yöneticiden) ----
    if (method === 'PUT' && path === '/api/config') {
      if (!jsonOnly(req)) return sendJson(res, 415, { error: 'content type must be application/json' });
      const b = await readBody(req, MAX_JSON_BODY.config);
      if (!b || typeof b !== 'object' || Array.isArray(b)) {
        return sendJson(res, 400, { error: 'bad config' });
      }
      const clean = {
        maintenance: {
          enabled: !!(b.maintenance && b.maintenance.enabled),
          message: String((b.maintenance && b.maintenance.message) || DEFAULT_CONFIG.maintenance.message).slice(0, 2000),
        },
        announcement: {
          enabled: !!(b.announcement && b.announcement.enabled),
          text: String((b.announcement && b.announcement.text) || '').slice(0, 2000),
        },
        faq: Array.isArray(b.faq)
          ? b.faq
              .map((f) => ({
                q: String((f && f.q) || '').trim().slice(0, 500),
                a: String((f && f.a) || '').trim().slice(0, 6000),
              }))
              .filter((f) => f.q || f.a)
              .slice(0, 100)
          : [],
        about: cleanSection(b.about, DEFAULT_CONFIG.about),
        privacy: cleanSection(b.privacy, DEFAULT_CONFIG.privacy),
        terms: cleanSection(b.terms, DEFAULT_CONFIG.terms),
        branding: {
          appName: String((b.branding && b.branding.appName) || '').trim().slice(0, 120) || DEFAULT_CONFIG.branding.appName,
        },
        ui: {
          heroVakitTitle:
            String((b.ui && b.ui.heroVakitTitle) || '').trim().slice(0, 120) || DEFAULT_CONFIG.ui.heroVakitTitle,
          contactLede:
            String((b.ui && b.ui.contactLede) || '').trim().slice(0, 400) || DEFAULT_CONFIG.ui.contactLede,
        },
        features: {
          addMosque: !(b.features && b.features.addMosque === false),
          reviews: !(b.features && b.features.reviews === false),
          photos: !(b.features && b.features.photos === false),
          favorites: !(b.features && b.features.favorites === false),
          contact: !(b.features && b.features.contact === false),
        },
        prayerSource: ['auto', 'imsakiyem', 'emushaf'].includes(b.prayerSource) ? b.prayerSource : 'auto',
        links: Array.isArray(b.links)
          ? b.links
              .map((l) => ({
                label: String((l && l.label) || '').trim().slice(0, 60),
                url: String((l && l.url) || '').trim().slice(0, 500),
              }))
              .filter((l) => l.url)
              .slice(0, 20)
          : [],
        minVersion: String(b.minVersion || '').trim().slice(0, 20),
        update: {
          latestVersion: String((b.update && b.update.latestVersion) || '').trim().slice(0, 20),
          minVersion: String((b.update && b.update.minVersion) || '').trim().slice(0, 20),
          url: String((b.update && b.update.url) || '').trim().slice(0, 500),
          note: String((b.update && b.update.note) || '').slice(0, 2000),
          apkUrl: String((b.update && b.update.apkUrl) || '').trim().slice(0, 500),
          apkSha: String((b.update && b.update.apkSha) || '').slice(0, 64),
          apkSize: Number.isInteger(b.update && b.update.apkSize) ? b.update.apkSize : 0,
          modified: Number.isFinite(b.update && b.update.modified) ? b.update.modified : 0,
        },
        updatedAt: Date.now(),
      };
      // Geriye dönük uyum: hem düz `minVersion` hem `update.minVersion` aynı değeri taşır.
      if (!clean.update.minVersion) clean.update.minVersion = clean.minVersion;
      if (!clean.minVersion) clean.minVersion = clean.update.minVersion;
      await saveConfig(clean);
      return sendJson(res, 200, clean);
    }

    if (method === 'GET' && path === '/api/requests') {
      const store = await loadStore('requests');
      const status = url.searchParams.get('status');
      let items = store.items;
      if (status) items = items.filter((r) => r.status === status);
      items = [...items].sort((a, b) => b.ts - a.ts);
      return sendJson(res, 200, { items });
    }

    if (method === 'GET' && path === '/api/messages') {
      const store = await loadStore('messages');
      const items = [...store.items].sort((a, b) => b.ts - a.ts);
      return sendJson(res, 200, { items });
    }

    // ---- kullanıcılar (uygulamadan)
    if (method === 'GET' && path === '/api/users') {
      const usersStore = await loadStore('users');
      const reqStore = await loadStore('requests');
      const byEmail = new Map();
      for (const r of reqStore.items) {
        const k = (r.email || '').trim().toLowerCase();
        if (!k) continue;
        const c = byEmail.get(k) || { total: 0, approved: 0, pending: 0 };
        c.total++;
        if (r.status === 'onaylı') c.approved++;
        else if (r.status === 'beklemede') c.pending++;
        byEmail.set(k, c);
      }
      const items = [...usersStore.items]
        .map((u) => ({
          email: u.email,
          name: u.name,
          createdAt: u.createdAt,
          lastSeen: u.lastSeen,
          requests: byEmail.get(u.email) || { total: 0, approved: 0, pending: 0 },
        }))
        .sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0));
      return sendJson(res, 200, { items });
    }

    const ud = path.match(/^\/api\/users\/([^/]+)$/);
    if (method === 'DELETE' && ud) {
      const email = decodeURIComponent(ud[1]).trim().toLowerCase();
      return await withLock(async () => {
        const store = await loadStore('users');
        const before = store.items.length;
        store.items = store.items.filter((u) => u.email !== email);
        if (store.items.length === before) return sendJson(res, 404, { error: 'not found' });
        await saveStore('users');
        return sendJson(res, 200, { ok: true });
      });
    }

    // ---- güncelleme APK'sı (yöneticiden) ----
    if (method === 'POST' && path === '/api/apk') {
      const buf = await readBinaryBody(req, MAX_APK_SIZE);
      if (buf.length < 4000) return sendJson(res, 400, { error: 'apk too small' });
      if (!looksLikeApk(buf)) return sendJson(res, 400, { error: 'invalid apk' });
      await mkdir(APK_DIR, { recursive: true });
      const tmp = `${APK_FILE}.${process.pid}.tmp`;
      await writeFile(tmp, buf);
      await rename(tmp, APK_FILE);
      const sha256 = createHash('sha256').update(buf).digest('hex');
      const config = await loadConfig();
      config.update = config.update || {};
      config.update.apkUrl = '/apk/latest.apk';
      config.update.apkSha = sha256;
      config.update.apkSize = buf.length;
      config.update.modified = Date.now();
      await saveConfig(config);
      return sendJson(res, 200, {
        ok: true,
        size: buf.length,
        sha256,
        apkUrl: '/apk/latest.apk',
      });
    }

    if (method === 'GET' && path === '/api/apk/info') {
      try {
        const st = await stat(APK_FILE);
        const config = await loadConfig();
        const u = config.update || {};
        return sendJson(res, 200, {
          ok: true,
          size: st.size,
          modified: u.modified || st.mtimeMs,
          sha256: u.apkSha || '',
        });
      } catch {
        return sendJson(res, 200, { ok: false });
      }
    }

    if (method === 'DELETE' && path === '/api/apk') {
      try {
        await unlink(APK_FILE);
      } catch {}
      const config = await loadConfig();
      config.update = config.update || {};
      config.update.apkUrl = '';
      config.update.apkSha = '';
      config.update.apkSize = 0;
      config.update.modified = 0;
      await saveConfig(config);
      return sendJson(res, 200, { ok: true });
    }

    const m = path.match(/^\/api\/requests\/(\d+)\/(approve|reject)$/);
    if (method === 'POST' && m) {
      const id = Number(m[1]);
      const newStatus = m[2] === 'approve' ? 'onaylı' : 'reddedildi';
      return await withLock(async () => {
        const store = await loadStore('requests');
        const item = store.items.find((r) => r.id === id);
        if (!item) return sendJson(res, 404, { error: 'not found' });
        item.status = newStatus;
        await saveStore('requests');
        return sendJson(res, 200, { ok: true, status: newStatus });
      });
    }

    const md = path.match(/^\/api\/requests\/(\d+)$/);
    if (method === 'DELETE' && md) {
      const id = Number(md[1]);
      return await withLock(async () => {
        const store = await loadStore('requests');
        const before = store.items.length;
        store.items = store.items.filter((r) => r.id !== id);
        if (store.items.length === before) return sendJson(res, 404, { error: 'not found' });
        await saveStore('requests');
        return sendJson(res, 200, { ok: true });
      });
    }

    const mm = path.match(/^\/api\/messages\/(\d+)$/);
    if (method === 'DELETE' && mm) {
      const id = Number(mm[1]);
      return await withLock(async () => {
        const store = await loadStore('messages');
        const before = store.items.length;
        store.items = store.items.filter((r) => r.id !== id);
        if (store.items.length === before) return sendJson(res, 404, { error: 'not found' });
        await saveStore('messages');
        return sendJson(res, 200, { ok: true });
      });
    }

    sendJson(res, 404, { error: 'not found' });
  } catch (e) {
    const msg = e && e.message ? e.message : 'internal error';
    if (msg === 'BAD_JSON') return sendJson(res, 400, { error: 'bad json' });
    if (msg === 'BODY_TOO_LARGE') return sendJson(res, 413, { error: 'body too large' });
    if (msg === 'APK_TOO_LARGE') return sendJson(res, 413, { error: 'apk too large' });
    if (msg === 'apk too small') return sendJson(res, 400, { error: 'apk too small' });
    if (msg === 'invalid apk') return sendJson(res, 400, { error: 'invalid apk' });
    if (msg === 'photos too large') return sendJson(res, 400, { error: 'photos too large' });
    if (msg === 'lat/lng out of range') return sendJson(res, 400, { error: 'lat/lng out of range' });
    if (msg === 'name required' || msg === 'lat/lng required' || msg === 'msg required') {
      return sendJson(res, 400, { error: msg });
    }
    console.error(e);
    return sendJson(res, 500, { error: 'internal error' });
  }
});

// ---------- güvenlik sertleştirme ----------
server.maxHeadersCount = 40;
server.timeout = 30_000; // boş soketleri kapat
server.keepAliveTimeout = 5_000;
try {
  server.requestTimeout = 15_000;
  server.headersTimeout = 6_000;
  server.maxRequestsPerSocket = 300;
} catch {}
server.on('clientError', (_err, socket) => {
  try {
    if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');
  } catch {}
});

// ---------- başlatma ----------
async function main() {
  await mkdir(APK_DIR, { recursive: true });
  await mkdir(DATA_DIR, { recursive: true });

  // Yönetici şifresini çöz: env > data/.admin-pass > rastgele üret.
  let pass = (process.env.ADMIN_PASS || '').trim();
  const fromFile = !pass;
  if (!pass) {
    try {
      pass = (await readFile(PASS_FILE, 'utf8')).trim();
    } catch {
      pass = '';
    }
  }
  if (!pass) {
    pass = randomBytes(16).toString('hex');
    try {
      await writeFile(PASS_FILE, pass + '\n', { mode: 0o600 });
    } catch {}
  }
  ADMIN_PASS = pass;

  const strong = pass.length >= 12 && !WEAK_PASSWORDS.has(pass);
  const listenHost = strong || ALLOW_WEAK_ADMIN_PASS ? '0.0.0.0' : '127.0.0.1';

  if (!strong) {
    console.warn('==========================================================');
    console.warn('UYARI: Yönetici şifresi zayıf/güvenli değil.');
    console.warn('Panel, internete açılmamak için YALNIZCA 127.0.0.1 üzerinde dinler.');
    console.warn('Güçlü bir şifre için: ADMIN_PASS=... node server.js');
    console.warn('==========================================================');
  } else if (fromFile) {
    console.warn('NOT: Yönetici şifresi', PASS_FILE, 'dosyasından okundu.');
  }
  if (process.env.ADMIN_PASS && !strong) {
    console.warn('DİKKAT: ADMIN_PASS ortam değişkeninde zayıf şifre kullanılıyor; ALLOW_WEAK_ADMIN_PASS=1 ile bilerek açılabilir.');
  }

  server.listen(PORT, listenHost, () => {
    console.log(`Nerede Kılacağım? panel http://${listenHost}:${PORT}`);
    if (listenHost === '127.0.0.1') {
      console.log('Panel yalnızca yerel erişimdir. Uygulama API/APK uçları yine herkese açıktır.');
    }
  });
}

main().catch((e) => {
  console.error('Sunucu başlatılamadı:', e);
  process.exit(1);
});