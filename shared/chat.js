/* צ'אט הבוט של יוצאים להרפתקה (דף chat/). רכיב אחד: window.HarpatkaChat.init({ root }).
   הפתיחה נבנית בדפדפן (מיידית) מ-chat/openers.json לפי ?c=. כל תשובה מגיעה מפונקציית השרת harpatka-chat (supabase/functions/harpatka-chat),
   שמחזירה { reply, chips, cta }. מתאים למשתמש מחובר ולא מחובר: אין כאן שום הזדהות. */
(function () {
  const KEY = 'harpatka_chat_v1';
  const q = new URLSearchParams(location.search);
  const cid = (q.get('c') || '').slice(0, 40);
  const src = (q.get('s') || '').slice(0, 20);
  // הפונקציה רצה בפרויקט ה-Supabase של floa (אותו אחד של הרוסטר), לא בפרויקט הישן של הרפתקה
  const CHAT_SB = (CONFIG.rosterApi && CONFIG.rosterApi.authUrl) ? { url: CONFIG.rosterApi.authUrl, key: CONFIG.rosterApi.authKey } : { url: CONFIG.supabaseUrl, key: CONFIG.supabaseKey };
  const ENDPOINT = (window.CHAT_ENDPOINT || (CHAT_SB.url + '/functions/v1/harpatka-chat'));
  const el = (tag, cls, txt) => { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; };
  const track = (name, data) => { try { if (window.fbq) fbq('trackCustom', name, data || {}); } catch (e) {} };
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); }));

  async function loadOpener() {
    let d = { default: { ad: '', opening: ['היי 🙂 כאן הבוט של יוצאים להרפתקה.', 'מה הביא אתכם לכאן?'], chips: [] }, items: {} };
    try { const r = await fetch('openers.json', { cache: 'no-cache' }); if (r.ok) d = await r.json(); } catch (e) {}
    const o = (cid && d.items && d.items[cid]) || d.default;
    const ad = String(o.ad || '');
    return { ad, opening: (o.opening || []).map((t) => String(t).replace('{ad}', ad)), chips: o.chips || [] };
  }

  // הודעת הפתיחה מהשרת (הבוט כותב אותה). כשל או איחור של יותר מ-8 שניות: null, והדף ממשיך עם הפתיחה הקבועה
  async function fetchOpening(session) {
    const ctl = new AbortController(), timer = setTimeout(() => ctl.abort(), 8000);
    try {
      const r = await fetch(ENDPOINT, {
        method: 'POST', signal: ctl.signal,
        headers: { 'Content-Type': 'application/json', apikey: CHAT_SB.key, Authorization: 'Bearer ' + CHAT_SB.key },
        body: JSON.stringify({ mode: 'opening', session, ad: cid, src }),
      });
      const d = await r.json().catch(() => ({}));
      return r.ok && Array.isArray(d.messages) ? { messages: d.messages.map(String).filter(Boolean).slice(0, 3), chips: Array.isArray(d.chips) ? d.chips.map(String) : [] } : null;
    } catch (e) { return null; } finally { clearTimeout(timer); }
  }

  function init(opts) {
    const root = opts.root;
    root.innerHTML = '<div class="ch-log" id="chLog" role="log" aria-live="polite" aria-label="השיחה"></div>' +
      '<div class="ch-bar"><form class="ch-form" id="chForm" autocomplete="off"><label class="sr-only" for="chIn" style="position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)">הודעה</label>' +
      '<textarea class="ch-in" id="chIn" rows="1" maxlength="600" placeholder="כתיבת הודעה"></textarea>' +
      '<button class="ch-send" id="chSend" type="submit" aria-label="שליחה" disabled><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4 20-7z"/></svg></button></form>' +
      '<p class="ch-note">שיחה עם בוט, והיא נשמרת כדי לשפר את השירות. <a href="../privacy/">מדיניות פרטיות</a></p></div>';
    const log = root.querySelector('#chLog'), form = root.querySelector('#chForm'), inp = root.querySelector('#chIn'), send = root.querySelector('#chSend');
    let st = null, busy = false, openerInfo = null;

    const save = () => { try { sessionStorage.setItem(KEY, JSON.stringify(st)); } catch (e) {} };
    const scroll = () => { log.scrollTo({ top: log.scrollHeight, behavior: reduce ? 'auto' : 'smooth' }); };
    const clearExtras = () => log.querySelectorAll('.ch-chips, .ch-ctas, .ch-retry').forEach((n) => n.remove());

    function bubble(role, text) { const b = el('div', 'ch-msg ' + (role === 'user' ? 'me' : 'bot'), text); log.appendChild(b); return b; }
    function who() { log.appendChild(el('div', 'ch-who', 'הבוט של יוצאים להרפתקה')); }

    function ctaNode(kind) {
      const wa = 'https://wa.me/' + CONFIG.whatsapp + '?text=' + encodeURIComponent(CONFIG.whatsappMessage || '');
      if (kind === 'register') { const u = new URL('../', location.href); if (src) u.searchParams.set('s', src); const a = el('a', 'ch-cta', 'לפרטים נוספים באתר'); a.href = u.href; a.target = '_blank'; a.rel = 'noopener'; a.addEventListener('click', () => track('ChatCTA', { kind })); return a; }
      if (kind === 'whatsapp') { const a = el('a', 'ch-cta alt', 'שיחה עם הדר ואופיר בוואטסאפ'); a.href = wa; a.target = '_blank'; a.rel = 'noopener'; a.addEventListener('click', () => track('ChatCTA', { kind })); return a; }
      if (kind === 'updates') { const a = el('a', 'ch-cta plain', 'קבוצת העדכונים בוואטסאפ'); a.href = CONFIG.updatesGroupLink; a.target = '_blank'; a.rel = 'noopener'; a.addEventListener('click', () => track('ChatCTA', { kind })); return a; }
      return null;
    }

    const userTurns = () => st.msgs.filter((m) => m.role === 'user').length;
    function extras(chips, cta) {
      clearExtras();
      const kinds = cta ? [cta] : [];
      if (kinds.length) { const w = el('div', 'ch-ctas'); kinds.forEach((k) => { const n = ctaNode(k); if (n) w.appendChild(n); }); if (w.childNodes.length) log.appendChild(w); }
      if (chips && chips.length) {
        const w = el('div', 'ch-chips');
        chips.forEach((t) => { const b = el('button', 'ch-chip', t); b.type = 'button'; b.addEventListener('click', () => submit(t)); w.appendChild(b); });
        log.appendChild(w);
      }
      scroll();
    }

    function typing() { const t = el('div', 'ch-typing'); t.setAttribute('aria-label', 'הבוט כותב'); t.innerHTML = '<i></i><i></i><i></i>'; log.appendChild(t); scroll(); return t; }
    const wait = (ms) => new Promise((r) => setTimeout(r, ms));

    function setBusy(v) { busy = v; send.disabled = v || !inp.value.trim(); }

    async function submit(text) {
      text = String(text || '').trim().slice(0, 600);
      if (!text || busy) return;
      clearExtras();
      if (!st.msgs.some((m) => m.role === 'user')) track('ChatStart', { c: cid || 'default' });
      st.msgs.push({ role: 'user', content: text }); save();
      bubble('user', text); inp.value = ''; grow(); setBusy(true); scroll();
      await ask();
    }

    async function ask() {
      const t = typing(), t0 = Date.now();
      try {
        const r = await fetch(ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', apikey: CHAT_SB.key, Authorization: 'Bearer ' + CHAT_SB.key },
          body: JSON.stringify({ session: st.session, messages: st.msgs.map((m) => ({ role: m.role, content: m.content })), ad: cid, adText: openerInfo.ad, opening: openerInfo.opening.join('\n'), src }),
        });
        const d = await r.json().catch(() => ({}));
        if (!r.ok && !d.reply) throw new Error(String(r.status));
        await wait(Math.max(0, 600 - (Date.now() - t0)));
        t.remove();
        if (typeof d.hasMeeting === 'boolean') st.hasMeeting = d.hasMeeting;
        who(); bubble('bot', d.reply);
        st.msgs.push({ role: 'assistant', content: d.reply, chips: d.chips || [], cta: d.cta || null }); save();
        extras(d.chips, d.cta);
      } catch (e) {
        t.remove();
        bubble('bot', 'משהו השתבש אצלנו. אפשר לנסות שוב, או לכתוב ישר להדר ולאופיר');
        const row = el('div', 'ch-chips ch-retry'); const b = el('button', 'ch-chip', 'ניסיון נוסף'); b.type = 'button';
        b.addEventListener('click', async () => { row.remove(); setBusy(true); await ask(); });
        row.appendChild(b); const w = ctaNode('whatsapp'); if (w) row.appendChild(w); log.appendChild(row); scroll();
      }
      setBusy(false);
    }

    function grow() { inp.style.height = 'auto'; inp.style.height = Math.min(inp.scrollHeight, 144) + 'px'; send.disabled = busy || !inp.value.trim(); }
    inp.addEventListener('input', grow);
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey && matchMedia('(pointer: fine)').matches) { e.preventDefault(); submit(inp.value); } });
    form.addEventListener('submit', (e) => { e.preventDefault(); submit(inp.value); inp.focus(); });
    // לחיצה על כפתור השליחה לא לוקחת פוקוס מהשדה, כדי שהמקלדת לא תיסגר
    send.addEventListener('pointerdown', (e) => e.preventDefault());
    // כשהמקלדת עולה: הדף מתאים לגובה הנראה והשיחה נגללת לסוף, כך שההודעה האחרונה נשארת גלויה
    const vv = window.visualViewport;
    if (vv) {
      const fit = () => { document.documentElement.style.height = vv.height + 'px'; window.scrollTo(0, 0); log.scrollTop = log.scrollHeight; };
      vv.addEventListener('resize', fit); vv.addEventListener('scroll', () => window.scrollTo(0, 0));
    }
    inp.addEventListener('focus', () => setTimeout(() => { log.scrollTop = log.scrollHeight; }, 300));

    (async () => {
      openerInfo = await loadOpener();
      let saved = null; try { saved = JSON.parse(sessionStorage.getItem(KEY) || 'null'); } catch (e) {}
      st = saved && saved.c === cid && Array.isArray(saved.msgs) ? saved : { c: cid, session: uuid(), msgs: [] };
      if (!st.msgs.length) {
        // הפתיחה נכתבת על ידי הבוט (ולומדת מפתיחות קודמות). בזמן ההמתנה מחוון הקלדה; אם השרת לא עונה בזמן, פתיחה קבועה מ-openers.json
        who(); const t = typing(); const t0 = Date.now();
        const op = await fetchOpening(st.session);
        await wait(Math.max(0, 800 - (Date.now() - t0)));
        log.innerHTML = '';
        const msgs = op && op.messages.length ? op.messages : openerInfo.opening;
        const chips = op && op.messages.length ? op.chips : openerInfo.chips;
        msgs.forEach((m, i) => { st.msgs.push({ role: 'assistant', content: m, opener: true, chips: i === msgs.length - 1 ? chips : [] }); });
        track('ChatOpen', { ad: cid, source: op ? 'agent' : 'fallback' });
      }
      save();
      who();
      st.msgs.forEach((m, i) => {
        if (m.role === 'assistant' && i > 0 && st.msgs[i - 1].role === 'user') who();
        bubble(m.role, m.content);
      });
      const last = st.msgs[st.msgs.length - 1];
      if (last.role === 'assistant') extras(last.chips, last.cta);
      else { setBusy(true); await ask(); }
      log.scrollTop = log.scrollHeight;
    })();
  }
  window.HarpatkaChat = { init };
})();
