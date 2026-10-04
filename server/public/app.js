'use strict';

const $ = (sel) => document.querySelector(sel);
const STATE = {
  token: localStorage.getItem('nk_token') || '',
  requests: [],
  messages: [],
  users: [],
  config: null,
  apk: null,
  tab: 'beklemede',
  query: '',
};

const TAB_DEFS = [
  { key: 'beklemede', label: 'Bekleyen' },
  { key: 'onaylı', label: 'Onaylı' },
  { key: 'reddedildi', label: 'Reddedilen' },
  { key: 'hepsi', label: 'Tümü' },
  { key: 'kullanicilar', label: 'Kullanıcılar' },
  { key: 'mesajlar', label: 'Mesajlar' },
  { key: 'uygulama', label: 'Uygulama' },
];

const STATUS_CLASS = { beklemede: 'pending', onaylı: 'ok', reddedildi: 'no' };
const STATUS_LABEL = { beklemede: 'Beklemede', onaylı: 'Onaylı', reddedildi: 'Reddedildi' };
const PHOTO_MIME = (b64) => {
  const head = b64.slice(0, 24);
  if (head.startsWith('/9j/')) return 'image/jpeg';
  if (head.startsWith('iVBOR')) return 'image/png';
  return 'image/jpeg';
};

async function api(path, opts = {}) {
  const headers = { ...(opts.body ? { 'Content-Type': 'application/json' } : {}) };
  if (STATE.token) headers['Authorization'] = `Bearer ${STATE.token}`;
  const res = await fetch(path, { ...opts, headers });
  if (res.status === 401) {
    STATE.token = '';
    localStorage.removeItem('nk_token');
    renderLogin();
    throw new Error('unauthorized');
  }
  if (!res.ok) {
    let msg = res.statusText;
    try {
      const j = await res.json();
      if (j.error) msg = j.error;
    } catch {}
    throw new Error(msg);
  }
  return res.json();
}

function fmtTs(ts) {
  try {
    return new Date(ts).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch {
    return '';
  }
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

async function loadAll() {
  const [r, m, c, u] = await Promise.all([
    api('/api/requests'),
    api('/api/messages'),
    api('/api/config'),
    api('/api/users'),
  ]);
  STATE.requests = r.items || [];
  STATE.messages = m.items || [];
  STATE.users = u.items || [];
  STATE.config = c || null;
  try {
    const a = await api('/api/apk/info');
    STATE.apk = a.ok ? a : null;
  } catch {
    STATE.apk = null;
  }
  render();
}

function renderLogin() {
  $('#loginView').classList.remove('hidden');
  $('#panelView').classList.add('hidden');
  $('#loginErr').textContent = '';
  $('#stats').innerHTML = '';
}

function renderPanel() {
  $('#loginView').classList.add('hidden');
  $('#panelView').classList.remove('hidden');
  $('#searchWrap').classList.toggle('hidden', STATE.tab === 'uygulama');
  renderStats();
  renderTabs();
  renderList();
  renderMaintButton();
}

// Tek tuşluk bakım anahtarı: mevcut yapılandıryı korur, sadece maintenance.enabled'ı çevirir.
function renderMaintButton() {
  const btn = $('#maintBtn');
  if (!STATE.config) {
    btn.hidden = true;
    return;
  }
  btn.hidden = false;
  const on = !!(STATE.config.maintenance && STATE.config.maintenance.enabled);
  btn.textContent = on ? 'Bakımı Kaldır' : 'Bakıma Al';
  btn.classList.toggle('ok', on);
  btn.classList.toggle('danger', !on);
}

async function toggleMaintenance() {
  if (!STATE.config) return;
  const next = JSON.parse(JSON.stringify(STATE.config));
  next.maintenance = next.maintenance || {};
  next.maintenance.enabled = !next.maintenance.enabled;
  const btn = $('#maintBtn');
  btn.disabled = true;
  try {
    STATE.config = await api('/api/config', { method: 'PUT', body: JSON.stringify(next) });
    toast(next.maintenance.enabled ? 'Uygulama bakıma alındı.' : 'Bakım kaldırıldı.');
  } catch (err) {
    toast('Yapılamadı: ' + err.message);
  } finally {
    btn.disabled = false;
    renderMaintButton();
  }
}

function render() {
  if (!STATE.token) return renderLogin();
  renderPanel();
}

function renderStats() {
  const counts = { beklemede: 0, onaylı: 0, reddedildi: 0 };
  for (const r of STATE.requests) if (counts[r.status] !== undefined) counts[r.status]++;
  const s = [
    ['pending', 'Bekleyen', counts.beklemede],
    ['ok', 'Onaylı', counts.onaylı],
    ['no', 'Reddedilen', counts.reddedildi],
    ['users', 'Kullanıcı', STATE.users.length],
  ];
  $('#stats').innerHTML = s
    .map(([cls, label, n]) => `<div class="stat ${cls}"><b>${n}</b> ${label}</div>`)
    .join('');
}

function renderTabs() {
  $('#tabs').innerHTML = TAB_DEFS.map(
    (t) => `<button type="button" class="${STATE.tab === t.key ? 'active' : ''}" data-tab="${t.key}">${t.label}</button>`
  ).join('');
  $('#tabs').querySelectorAll('button').forEach((b) => {
    b.addEventListener('click', () => {
      STATE.tab = b.dataset.tab;
      $('#searchWrap').classList.toggle('hidden', STATE.tab === 'uygulama');
      renderTabs();
      renderList();
    });
  });
}

function renderList() {
  const box = $('#list');
  const q = STATE.query.trim().toLowerCase();

  if (STATE.tab === 'uygulama') return renderAppTab(box);

  if (STATE.tab === 'kullanicilar') {
    let users = STATE.users.slice();
    if (q) users = users.filter((u) => (u.name || u.email || '').toLowerCase().includes(q));
    if (users.length === 0) {
      box.innerHTML = '<div class="empty">Kullanıcı kaydı yok.</div>';
      return;
    }
    box.innerHTML = users.map((u) => {
      const reqs = u.requests || { total: 0, approved: 0, pending: 0 };
      const init = (u.name || u.email || '?').trim().charAt(0).toUpperCase();
      return `
      <div class="card user-card">
        <div class="card head">
          <div class="req-head-left">
            <div class="avatar alt">${esc(init)}</div>
            <div>
              <h3>${esc(u.name || '(İsimsiz kullanıcı)')}</h3>
              <p class="sub">${esc(u.email)}</p>
            </div>
          </div>
          <span class="sub">Kayıt: ${fmtTs(u.createdAt)}</span>
        </div>
        <div class="user-stats">
          <span class="user-stat total">Toplam istek <b>${reqs.total}</b></span>
          <span class="user-stat approved">Onaylı <b>${reqs.approved}</b></span>
          <span class="user-stat pending">Bekleyen <b>${reqs.pending}</b></span>
        </div>
        <div class="meta">
          <span>Son görülme: ${u.lastSeen ? fmtTs(u.lastSeen) : '—'}</span>
        </div>
        <div class="actions">
          <button type="button" class="ghost danger" data-del-user="${esc(u.email)}">Sil</button>
        </div>
      </div>`;
    }).join('');
    box.querySelectorAll('[data-del-user]').forEach((b) => {
      b.addEventListener('click', async () => {
        if (!confirm('Bu kullanıcıyı silinsin mi?')) return;
        await api(`/api/users/${encodeURIComponent(b.dataset.delUser)}`, { method: 'DELETE' });
        loadAll();
      });
    });
    return;
  }

  if (STATE.tab === 'mesajlar') {
    let msgs = STATE.messages.slice();
    if (q) msgs = msgs.filter((m) => (m.name || '').toLowerCase().includes(q) || (m.email || '').toLowerCase().includes(q));
    if (msgs.length === 0) {
      box.innerHTML = '<div class="empty">Gelen iletişim mesajı yok.</div>';
      return;
    }
    box.innerHTML = msgs.map((m) => `
      <div class="card">
        <div class="card head">
          <div>
            <h3>${esc(m.name || 'İsimsiz')}</h3>
            <p class="sub">${esc(m.email)}</p>
          </div>
          <span class="sub">${fmtTs(m.ts)}</span>
        </div>
        <div class="msg-body">${esc(m.msg)}</div>
        <div class="actions">
          <button type="button" class="ghost danger" data-del-msg="${m.id}">Sil</button>
        </div>
      </div>`).join('');
    box.querySelectorAll('[data-del-msg]').forEach((b) => {
      b.addEventListener('click', async () => {
        await api(`/api/messages/${b.dataset.delMsg}`, { method: 'DELETE' });
        loadAll();
      });
    });
    return;
  }

  let items = STATE.requests.slice();
  if (STATE.tab !== 'hepsi') items = items.filter((r) => r.status === STATE.tab);
  if (q) items = items.filter((r) => `${r.name} ${r.type} ${r.email || ''}`.toLowerCase().includes(q));
  if (items.length === 0) {
    box.innerHTML = '<div class="empty">Bu kategoride kayıt yok.</div>';
    return;
  }
  box.innerHTML = items.map((r) => {
    const photos = (r.photos || [])
      .map((p, i) => `<img src="data:${PHOTO_MIME(p)};base64,${p}" data-src="${i}" alt="foto ${i + 1}">`)
      .join('');
    const tags = (r.tags || []).map((t) => `<span class="chip">${esc(t)}</span>`).join('');
    return `
    <div class="card">
      <div class="card head">
        <div>
          <h3>${esc(r.name)}</h3>
          <p class="sub">${esc(r.type)}<span class="status ${STATUS_CLASS[r.status] || 'pending'}">${STATUS_LABEL[r.status] || esc(r.status)}</span></p>
        </div>
        <span class="sub">#${r.id} · ${fmtTs(r.ts)}</span>
      </div>
      <div class="meta">
        <span>👤 ${esc(r.email || 'Anonim')}</span>
        <span class="coords">${Number(r.lat).toFixed(6)}, ${Number(r.lng).toFixed(6)}</span>
        <a target="_blank" rel="noopener" href="https://www.google.com/maps/search/?api=1&query=${Number(r.lat)},${Number(r.lng)}">Google Haritalar</a>
        <a target="_blank" rel="noopener" href="https://www.openstreetmap.org/?mlat=${Number(r.lat)}&mlon=${Number(r.lng)}#map=17/${Number(r.lat)}/${Number(r.lng)}">OSM</a>
      </div>
      ${tags ? `<div style="margin-top:8px">${tags}</div>` : ''}
      ${photos ? `<div class="photos">${photos}</div>` : ''}
      <div class="actions">
        ${r.status !== 'onaylı' ? `<button type="button" class="ok" data-act="approve" data-id="${r.id}">Onayla</button>` : ''}
        ${r.status !== 'reddedildi' ? `<button type="button" class="no" data-act="reject" data-id="${r.id}">Reddet</button>` : ''}
        <button type="button" class="ghost danger" data-act="delete" data-id="${r.id}">Sil</button>
      </div>
    </div>`;
  }).join('');

  box.querySelectorAll('img[data-src]').forEach((img) => {
    img.addEventListener('click', () => openLightbox(img.src));
  });
  box.querySelectorAll('[data-act]').forEach((b) => {
    b.addEventListener('click', async () => {
      const { act, id } = b.dataset;
      if (act === 'approve') await api(`/api/requests/${id}/approve`, { method: 'POST' });
      else if (act === 'reject') await api(`/api/requests/${id}/reject`, { method: 'POST' });
      else if (act === 'delete') {
        if (!confirm('Bu kaydı kalıcı olarak silinsin mi?')) return;
        await api(`/api/requests/${id}`, { method: 'DELETE' });
      }
      loadAll();
    });
  });
}

// ---------- Uygulama ayarları editörü ----------
const SECTIONS = [
  { key: 'about', label: 'Hakkımızda' },
  { key: 'privacy', label: 'Gizlilik Politikası' },
  { key: 'terms', label: 'Kullanım Şartları' },
];

function renderAppTab(box) {
  if (!STATE.config) {
    box.innerHTML = '<div class="empty">Yapılandırma yükleniyor…</div>';
    return;
  }
  const cfg = STATE.config;
  const upd = cfg.update || {};
  box.innerHTML = `
    <form id="cfgForm">
      <section class="card">
        <h3>Bakım Modu</h3>
        <p class="sub">Açıldığında uygulama "bakımdayız" ekranında kalır.</p>
        <label class="toggle-row">
          <input type="checkbox" id="cfgMaintOn" ${cfg.maintenance && cfg.maintenance.enabled ? 'checked' : ''}>
          <span><b>Bakım modu açık</b></span>
        </label>
        <textarea id="cfgMaintMsg" rows="2" placeholder="Bakımda gösterilecek mesaj">${esc((cfg.maintenance && cfg.maintenance.message) || '')}</textarea>
      </section>

      <section class="card">
        <h3>Duyuru</h3>
        <p class="sub">Ana ekranın üstünde küçük bilgilendirme bandı.</p>
        <label class="toggle-row">
          <input type="checkbox" id="cfgAnnOn" ${cfg.announcement && cfg.announcement.enabled ? 'checked' : ''}>
          <span><b>Duyuruyu göster</b></span>
        </label>
        <textarea id="cfgAnnText" rows="2" placeholder="Duyuru metni">${esc((cfg.announcement && cfg.announcement.text) || '')}</textarea>
      </section>

      <section class="card">
        <h3>Marka &amp; Metinler</h3>
        <p class="sub">Uygulama genelinde görünen adlar ve sabit metinler.</p>
        <input id="cfgAppName" placeholder="Uygulama adı" value="${esc((cfg.branding && cfg.branding.appName) || '')}">
        <input id="cfgHeroTitle" placeholder="Ana ekran vakitler başlığı" value="${esc((cfg.ui && cfg.ui.heroVakitTitle) || '')}" style="margin-top:8px">
        <textarea id="cfgContactLede" rows="2" placeholder="İletişim sayfası giriş metni" style="margin-top:8px">${esc((cfg.ui && cfg.ui.contactLede) || '')}</textarea>
      </section>

      <section class="card">
        <h3>Özellik Anahtarları</h3>
        <p class="sub">Kapatılan özellik uygulamada anında kaybolur.</p>
        <label class="toggle-row"><input type="checkbox" id="cfgFeatAddMosque" ${!(cfg.features && cfg.features.addMosque === false) ? 'checked' : ''}><span><b>Mescit ekleme</b></span></label>
        <label class="toggle-row"><input type="checkbox" id="cfgFeatReviews" ${!(cfg.features && cfg.features.reviews === false) ? 'checked' : ''}><span><b>Varış puanlaması</b></span></label>
        <label class="toggle-row"><input type="checkbox" id="cfgFeatPhotos" ${!(cfg.features && cfg.features.photos === false) ? 'checked' : ''}><span><b>Fotoğraflar</b></span></label>
        <label class="toggle-row"><input type="checkbox" id="cfgFeatFavorites" ${!(cfg.features && cfg.features.favorites === false) ? 'checked' : ''}><span><b>Favoriler</b></span></label>
        <label class="toggle-row"><input type="checkbox" id="cfgFeatContact" ${!(cfg.features && cfg.features.contact === false) ? 'checked' : ''}><span><b>İletişim formu</b></span></label>
      </section>

      <section class="card">
        <h3>Namaz Vakti Kaynağı</h3>
        <p class="sub">Vakitlerin hangi servisten çekileceği. &quot;Otomatik&quot; önce imsakiyem, olmazsa emüşafı dener.</p>
        <select id="cfgPrayerSource">
          <option value="auto" ${(cfg.prayerSource || 'auto') === 'auto' ? 'selected' : ''}>Otomatik</option>
          <option value="imsakiyem" ${cfg.prayerSource === 'imsakiyem' ? 'selected' : ''}>İmsakiyem</option>
          <option value="emushaf" ${cfg.prayerSource === 'emushaf' ? 'selected' : ''}>Emüşaf</option>
        </select>
      </section>

      <section class="card">
        <h3>Güncellemeler</h3>
        <p class="sub">Son sürümü ve bağlantıyı girin. Uygulama açılışta sürüm karşılaştırıp kullanıcıyı güncellemeye yönlendirir. Min sürümden eski sürümler zorunlu ekranda kalır.</p>
        <div class="grid2">
          <input id="cfgUpLatest" placeholder="Son sürüm (örn. 1.2.0)" value="${esc((upd.latestVersion) || '')}">
          <input id="cfgUpMin" placeholder="Zorunlu min sürüm (boş = kapalı)" value="${esc(upd.minVersion || '')}">
        </div>
        <input id="cfgUpUrl" placeholder="Mağaza bağlantısı (Play Store / App Store)" value="${esc(upd.url || '')}" style="margin-top:8px">
        <textarea id="cfgUpNote" rows="2" placeholder="Sürüm notu (opsiyonel)" style="margin-top:8px">${esc(upd.note || '')}</textarea>
        <div class="apk-box">
          <b>APK (Android doğrudan kurulum)</b>
          <div id="apkState" class="sub">${apkStateHtml()}</div>
          <div id="apkProgress" class="apk-progress hidden"><div id="apkProgressBar"></div></div>
          <div class="actions" style="margin-top:8px">
            <button type="button" class="ghost" id="apkUploadBtn">APK Yükle</button>
            <button type="button" class="ghost danger hidden" id="apkDeleteBtn">APK'yı Kaldır</button>
          </div>
          <input type="file" id="apkFile" accept=".apk" class="hidden">
        </div>
      </section>

      <section class="card">
        <h3>Bağlantılar</h3>
        <p class="sub">Uygulamanın Ayarlar sekmesinde listelenir (mağaza, site, sosyal medya…).</p>
        <div class="ed-list" id="linkList"></div>
        <button type="button" class="ghost add-btn" data-add-link>+ Bağlantı ekle</button>
      </section>

      <section class="card">
        <h3>Sıkça Sorulan Sorular</h3>
        <p class="sub">Uygulamanın SSS sayfasında görünür.</p>
        <div class="ed-list" id="faqList"></div>
        <button type="button" class="ghost add-btn" data-add-faq>+ SSS ekle</button>
      </section>

      ${SECTIONS.map((s) => blocksSectionHtml(cfg[s] || {}, s)).join('')}

      <div class="save-row">
        <span class="sub">Son güncelleme: ${cfg.updatedAt ? fmtTs(cfg.updatedAt) : 'henüz yok'}</span>
        <button type="submit" class="ok wide">Tümünü Kaydet</button>
      </div>
    </form>`;

  const faqList = box.querySelector('#faqList');
  const faq = cfg.faq || [];
  faq.forEach((f) => faqList.appendChild(faqRow(f.q, f.a, false)));
  box.querySelector('[data-add-faq]').addEventListener('click', () => faqList.appendChild(faqRow('', '', true)));

  const linkList = box.querySelector('#linkList');
  (cfg.links || []).forEach((l) => linkList.appendChild(linkRow(l.label || '', l.url || '')));
  box.querySelector('[data-add-link]').addEventListener('click', () => linkList.appendChild(linkRow('', '')));

  SECTIONS.forEach((s) => {
    const holder = box.querySelector(`.edt-section[data-section="${s.key}"]`);
    const blocks = holder.querySelector('[data-blocks]');
    (cfg[s.key] && cfg[s.key].blocks || []).forEach((b) => blocks.appendChild(blockRow(b.title, b.text)));
    holder.querySelector('[data-add-bt]').addEventListener('click', () => blocks.appendChild(blockRow('', '', true)));
  });

  box.querySelector('#cfgForm').addEventListener('submit', saveConfig);

  const apkFile = box.querySelector('#apkFile');
  box.querySelector('#apkUploadBtn').addEventListener('click', () => apkFile.click());
  apkFile.addEventListener('change', () => {
    if (!apkFile.files.length) return;
    uploadApk(apkFile.files[0], box);
    apkFile.value = '';
  });
  const delBtn = box.querySelector('#apkDeleteBtn');
  delBtn.addEventListener('click', async () => {
    if (!confirm('Yüklü APK kaldırılsın mı? Uygulamalar artık bu dosyayı indiremez.')) return;
    try {
      await api('/api/apk', { method: 'DELETE' });
      STATE.apk = null;
      toast('APK kaldırıldı.');
      renderList();
    } catch (err) {
      toast('Kaldırılamadı: ' + err.message);
    }
  });
}

function apkStateHtml() {
  const a = STATE.apk;
  if (!a) return 'Yüklü APK yok.';
  return 'Mevcut: ' + fmtBytes(a.size) + (a.modified ? ` · ${fmtTs(a.modified)}` : '');
}

function fmtBytes(n) {
  if (!Number.isFinite(n)) return '—';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
  return (n / (1024 * 1024)).toFixed(1) + ' MB';
}

// XHR ile çubuklu APK yüklemesi (fetch'te ilerleme yok).
function uploadApk(file, box) {
  const bar = box.querySelector('#apkProgressBar');
  const wrap = box.querySelector('#apkProgress');
  const state = box.querySelector('#apkState');
  wrap.classList.remove('hidden');
  bar.style.width = '0%';
  const xhr = new XMLHttpRequest();
  xhr.open('POST', '/api/apk');
  xhr.setRequestHeader('Authorization', 'Bearer ' + STATE.token);
  xhr.upload.onprogress = (e) => {
    if (e.lengthComputable) bar.style.width = Math.round((e.loaded / e.total) * 100) + '%';
  };
  xhr.onload = () => {
    wrap.classList.add('hidden');
    if (xhr.status >= 200 && xhr.status < 300) {
      try {
        const j = JSON.parse(xhr.responseText);
        STATE.apk = { ok: true, size: j.size, sha256: j.sha256, modified: Date.now() };
      } catch {}
      state.textContent = apkStateHtml();
      state.dataset.fresh = '1';
      toast('APK yüklendi.');
      renderList();
    } else {
      let msg = 'Yükleme başarısız';
      try {
        const j = JSON.parse(xhr.responseText);
        if (j.error) msg = j.error;
      } catch {}
      state.textContent = msg;
      toast(msg);
    }
  };
  xhr.onerror = () => {
    wrap.classList.add('hidden');
    state.textContent = 'Ağ hatası.';
    toast('APK yüklenemedi.');
  };
  xhr.send(file);
}

function faqRow(q, a, fresh) {
  const d = document.createElement('div');
  d.className = `ed-row ${fresh ? 'fresh' : ''}`;
  d.innerHTML = `
    <input class="faq-q" placeholder="Soru" value="${esc(q)}">
    <textarea class="faq-a" rows="2" placeholder="Cevap">${esc(a)}</textarea>
    <button type="button" class="ghost danger row-del" aria-label="Sil">&times;</button>`;
  d.querySelector('.row-del').addEventListener('click', () => d.remove());
  return d;
}

function linkRow(label, url) {
  const d = document.createElement('div');
  d.className = 'ed-row';
  d.innerHTML = `
    <input class="lnk-label" placeholder="Etiket (örn. Play Store)" value="${esc(label)}">
    <input class="lnk-url" placeholder="https://…" value="${esc(url)}">
    <button type="button" class="ghost danger row-del" aria-label="Sil">&times;</button>`;
  d.querySelector('.row-del').addEventListener('click', () => d.remove());
  return d;
}

function blockRow(title, text) {
  const d = document.createElement('div');
  d.className = 'ed-row';
  d.innerHTML = `
    <input class="blk-title" placeholder="Blok başlığı" value="${esc(title)}">
    <textarea class="blk-text" rows="2" placeholder="Metin">${esc(text)}</textarea>
    <button type="button" class="ghost danger row-del" aria-label="Sil">&times;</button>`;
  d.querySelector('.row-del').addEventListener('click', () => d.remove());
  return d;
}

function blocksSectionHtml(sec, s) {
  return `<section class="card edt-section" data-section="${s.key}">
    <h3>${s.label}</h3>
    <input class="edt-title" placeholder="Sayfa başlığı" value="${esc(sec.title || '')}">
    <textarea class="edt-lede" rows="2" placeholder="Giriş metni">${esc(sec.lede || '')}</textarea>
    <div class="ed-list" data-blocks></div>
    <button type="button" class="ghost add-btn" data-add-bt>+ Blok ekle</button>
  </section>`;
}

async function saveConfig(e) {
  e.preventDefault();
  const form = $('#cfgForm');
  const faq = [...form.querySelectorAll('#faqList .ed-row')].map((r) => ({
    q: r.querySelector('.faq-q').value.trim(),
    a: r.querySelector('.faq-a').value.trim(),
  })).filter((f) => f.q || f.a);

  const buildSection = (key) => {
    const holder = form.querySelector(`.edt-section[data-section="${key}"]`);
    const blocks = [...holder.querySelectorAll('[data-blocks] .ed-row')].map((r) => ({
      title: r.querySelector('.blk-title').value.trim(),
      text: r.querySelector('.blk-text').value.trim(),
    })).filter((b) => b.title || b.text);
    return {
      title: holder.querySelector('.edt-title').value.trim(),
      lede: holder.querySelector('.edt-lede').value.trim(),
      blocks,
    };
  };

  const links = [...form.querySelectorAll('#linkList .ed-row')].map((r) => ({
    label: r.querySelector('.lnk-label').value.trim(),
    url: r.querySelector('.lnk-url').value.trim(),
  })).filter((l) => l.url);

  const body = {
    maintenance: {
      enabled: form.querySelector('#cfgMaintOn').checked,
      message: form.querySelector('#cfgMaintMsg').value.trim(),
    },
    announcement: {
      enabled: form.querySelector('#cfgAnnOn').checked,
      text: form.querySelector('#cfgAnnText').value.trim(),
    },
    faq,
    about: buildSection('about'),
    privacy: buildSection('privacy'),
    terms: buildSection('terms'),
    branding: { appName: form.querySelector('#cfgAppName').value.trim() },
    ui: {
      heroVakitTitle: form.querySelector('#cfgHeroTitle').value.trim(),
      contactLede: form.querySelector('#cfgContactLede').value.trim(),
    },
    features: {
      addMosque: form.querySelector('#cfgFeatAddMosque').checked,
      reviews: form.querySelector('#cfgFeatReviews').checked,
      photos: form.querySelector('#cfgFeatPhotos').checked,
      favorites: form.querySelector('#cfgFeatFavorites').checked,
      contact: form.querySelector('#cfgFeatContact').checked,
    },
    prayerSource: form.querySelector('#cfgPrayerSource').value,
    links,
    minVersion: form.querySelector('#cfgUpMin').value.trim(),
    update: {
      latestVersion: form.querySelector('#cfgUpLatest').value.trim(),
      minVersion: form.querySelector('#cfgUpMin').value.trim(),
      url: form.querySelector('#cfgUpUrl').value.trim(),
      note: form.querySelector('#cfgUpNote').value.trim(),
      apkUrl: STATE.apk ? '/apk/latest.apk' : '',
      apkSha: (STATE.apk && STATE.apk.sha256) || '',
      apkSize: (STATE.apk && STATE.apk.size) || 0,
      modified: (STATE.apk && STATE.apk.modified) || 0,
    },
  };

  try {
    STATE.config = await api('/api/config', { method: 'PUT', body: JSON.stringify(body) });
    toast('Kaydedildi.');
  } catch (err) {
    toast('Kaydedilemedi: ' + err.message);
  }
}

function toast(msg) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.classList.add('show'), 10);
  setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => el.remove(), 300);
  }, 2200);
}

function openLightbox(src) {
  $('#lightboxImg').src = src;
  $('#lightbox').classList.remove('hidden');
}

function closeLightbox() {
  $('#lightbox').classList.add('hidden');
}

function init() {
  $('#loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    $('#loginErr').textContent = '';
    try {
      const pw = $('#pass').value;
      const j = await api('/api/login', { method: 'POST', body: JSON.stringify({ password: pw }) });
      STATE.token = j.token;
      localStorage.setItem('nk_token', j.token);
      $('#pass').value = '';
      loadAll();
    } catch (err) {
      $('#loginErr').textContent = err.message === 'wrong password' ? 'Şifre hatalı.' : 'Giriş başarısız.';
    }
  });

  $('#maintBtn').addEventListener('click', toggleMaintenance);
  $('#refreshBtn').addEventListener('click', loadAll);
  $('#logoutBtn').addEventListener('click', () => {
    STATE.token = '';
    localStorage.removeItem('nk_token');
    renderLogin();
  });
  $('#searchInput').addEventListener('input', (e) => {
    STATE.query = e.target.value;
    renderList();
  });
  $('#lbClose').addEventListener('click', closeLightbox);
  $('#lightbox').addEventListener('click', (e) => {
    if (e.target === $('#lightbox')) closeLightbox();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeLightbox();
  });

  // Uygulamadan gelen yeni istekler 10 sn'de bir sessizce tazelenir.
  // ("Uygulama" düzenleme sekmesi açıkken formu bozmamak için atlanır.)
  setInterval(async () => {
    if (!STATE.token || STATE.tab === 'uygulama') return;
    try {
      const [r, m] = await Promise.all([api('/api/requests'), api('/api/messages')]);
      STATE.requests = r.items || [];
      STATE.messages = m.items || [];
      renderStats();
      renderList();
    } catch {}
  }, 10000);

  if (STATE.token) loadAll().catch(() => renderLogin());
  else renderLogin();
}

init();