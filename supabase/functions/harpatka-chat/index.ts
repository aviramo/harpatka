// Supabase Edge Function: harpatka-chat. הבוט של יוצאים להרפתקה.
// פריסה: supabase functions deploy harpatka-chat --no-verify-jwt   (המפתח הציבורי נשלח ממילא מהדפדפן)
// סודות: supabase secrets set ANTHROPIC_API_KEY=...   (אופציונלי: CHAT_MODEL, למשל claude-haiku-5-5)
// ההנחיות נמצאות ב-prompt.ts. שיחות נשמרות ב-harpatka.chat_logs (admin/chat.sql), בפרויקט ה-Supabase של floa שבו הפונקציה נפרסת.
// פריסה: supabase functions deploy harpatka-chat --no-verify-jwt --project-ref aexmnaxvahblveejsbup
import { dynamicPrompt, MeetingInfo, STATIC_PROMPT } from './prompt.ts';

const AGE_MIN = 35, AGE_MAX = 55; // אותו טווח כמו shared/age.js
const ORIGINS = ['https://harpatka.co.il', 'https://www.harpatka.co.il', 'https://test.harpatka.co.il'];
const MAX_MSG = 600, MAX_USER_TURNS = 30, KEEP = 24;

const SB_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SB_SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const MODEL = Deno.env.get('CHAT_MODEL') || 'claude-sonnet-5-5';

const allowed = (o: string | null) => !!o && (ORIGINS.includes(o) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(o));

const cors = (o: string | null) => ({
  'Access-Control-Allow-Origin': allowed(o) ? o! : ORIGINS[0],
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
});
const json = (o: string | null, body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors(o), 'Content-Type': 'application/json; charset=utf-8' } });

// הגבלת קצב בזיכרון (מקרבת בלבד: כל מופע של הפונקציה סופר לעצמו): 40 בקשות ל-10 דקות לכל כתובת
const hits = new Map<string, number[]>();
const limited = (ip: string) => {
  const now = Date.now(), arr = (hits.get(ip) ?? []).filter((t) => now - t < 600_000);
  arr.push(now); hits.set(ip, arr);
  if (hits.size > 5000) for (const [k, v] of hits) if (!v.some((t) => now - t < 600_000)) hits.delete(k);
  return arr.length > 40;
};

const israelToday = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
const dayN = (s: string) => { const [y, m, d] = s.split('-').map(Number); return Date.UTC(y, m - 1, d) / 864e5; };
const tx = (v: unknown) => String(v ?? '').trim();

type Tiers = { base: number; steps: { days: number; price: number }[] };
const normT = (t: any): Tiers | null =>
  t && !Array.isArray(t) && Number.isFinite(Number(t.base))
    ? { base: Number(t.base), steps: (Array.isArray(t.steps) ? t.steps : []).map((x: any) => ({ days: Number(x.days), price: Number(x.price) })).filter((x: any) => x.days >= 1 && Number.isFinite(x.price)) }
    : null;
// אותה לוגיקה כמו priceFor ב-shared/register.js: המדרגה שמתחילה הכי קרוב למפגש מבין אלה שכבר התחילו, אחרת המחיר הרגיל
const priceFor = (left: number, T: Tiers | null) => {
  if (T) { const s = T.steps.filter((x) => left <= x.days).sort((a, b) => a.days - b.days)[0]; return s ? s.price : T.base; }
  return left <= 3 ? 100 : 80;
};

const ROSTER_URL = 'https://api.floa.co.il/roster/v1';
const ROSTER_KEY = Deno.env.get('ROSTER_PUBLIC_KEY') || 'rk_pub_IXQvipmkAZevJPbdQanj6KW9M9hrQTBf'; // המפתח הציבורי של האתר (מוגבל לפי Origin)

// המפגש הקרוב מהרוסטר: אותו API ציבורי שהאתר קורא. המפתח מוגבל לפי Origin, ולכן נשלח Origin של האתר
async function loadMeeting(): Promise<MeetingInfo | null> {
  try {
    const today = israelToday();
    const r = await fetch(ROSTER_URL + '/meetings?limit=10', { headers: { Authorization: 'Bearer ' + ROSTER_KEY, Origin: ORIGINS[0] } });
    if (!r.ok) return null;
    const rows: any[] = (await r.json()).meetings ?? [];
    const m = rows.filter((x) => tx(x.date) >= today).sort((a, b) => (tx(a.date) + tx(a.time)).localeCompare(tx(b.date) + tx(b.time)))[0];
    if (!m) return null;
    const T = normT(m.price_tiers);
    const left = dayN(m.date) - dayN(today);
    const fmt = (d: string) => { const [, mo, da] = d.split('-').map(Number); return `${da}.${mo}`; };
    let note = '';
    if (T) {
      const parts = [`המחיר הרגיל ${T.base} ש"ח`];
      for (const s of [...T.steps].sort((a, b) => b.days - a.days)) {
        const from = new Date((dayN(m.date) - s.days) * 864e5).toISOString().slice(0, 10);
        parts.push(`מ-${fmt(from)} ${s.price} ש"ח`);
      }
      note = parts.join(', ');
    }
    return {
      date: m.date, time: tx(m.time).slice(0, 5),
      name: tx(m.name), city: tx(m.city), place: tx(m.place),
      max: Number(m.capacity) || 0,
      priceNow: Number.isFinite(Number(m.price)) && !T ? Number(m.price) : priceFor(left, T), priceNote: note,
    };
  } catch (_) { return null; }
}

// פירוק הסימונים <chips> ו-<cta> מהתשובה
function parse(raw: string) {
  let text = raw, chips: string[] = [], cta: string | null = null;
  text = text.replace(/<chips>([\s\S]*?)<\/chips>/g, (_, c) => {
    chips = String(c).split('|').map((s) => s.trim()).filter(Boolean).slice(0, 4);
    return '';
  });
  text = text.replace(/<cta>\s*([a-z]+)\s*<\/cta>/g, (_, c) => {
    if (!cta && ['register', 'whatsapp', 'updates'].includes(c)) cta = c;
    return '';
  });
  text = text.replace(/<\/?(chips|cta)>/g, '').trim();
  return { reply: text, chips, cta };
}

// שמירת שיחות בפרויקט ה-Supabase של floa (שבו הפונקציה רצה): פונקציית RPC שרק service_role מריץ (admin/chat.sql)
async function saveLog(session: string, src: string, ad: string, messages: unknown[], cta: string | null) {
  if (!SB_SERVICE || !SB_URL || !/^[0-9a-f-]{36}$/i.test(session)) return;
  try {
    await fetch(SB_URL + '/rest/v1/rpc/harpatka_chat_log', {
      method: 'POST',
      headers: { apikey: SB_SERVICE, Authorization: 'Bearer ' + SB_SERVICE, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_id: session, p_source: src || null, p_ad: ad || null, p_messages: messages, p_cta: cta }),
    });
  } catch (_) { /* כשל בשמירה לא מפיל את התשובה */ }
}

Deno.serve(async (req) => {
  const origin = req.headers.get('origin');
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(origin) });
  if (req.method !== 'POST') return json(origin, { error: 'method' }, 405);
  if (!allowed(origin)) return json(origin, { error: 'origin' }, 403);

  const ip = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() || 'unknown';
  if (limited(ip)) return json(origin, { error: 'rate' }, 429);

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) return json(origin, { error: 'config' }, 500);

  let body: any;
  try { body = await req.json(); } catch (_) { return json(origin, { error: 'body' }, 400); }

  // רק הודעות משתמש ובוט, בסדר מתחלף, מתחילות במשתמש; אורך מוגבל
  const incoming: { role: string; content: string }[] = Array.isArray(body.messages) ? body.messages : [];
  const clean = incoming
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string' && m.content.trim())
    .map((m) => ({ role: m.role, content: m.content.slice(0, m.role === 'user' ? MAX_MSG : 1500) }));
  const turns = clean.filter((m) => m.role === 'user').length;
  if (!turns || clean[clean.length - 1].role !== 'user') return json(origin, { error: 'messages' }, 400);
  if (turns > MAX_USER_TURNS) return json(origin, { error: 'limit', reply: 'זו כבר שיחה ארוכה. כדי להמשיך, הכי נוח לכתוב להדר ולאופיר בוואטסאפ', chips: [], cta: 'whatsapp' });

  // ההיסטוריה שנשלחת למודל: הקצה האחרון, ומתחילה בהודעת משתמש
  let hist = clean.slice(-KEEP);
  while (hist.length && hist[0].role !== 'user') hist = hist.slice(1);
  // הודעות רצופות של אותו תפקיד מאוחדות (דרישת ה-API)
  const merged: { role: string; content: string }[] = [];
  for (const m of hist) {
    const last = merged[merged.length - 1];
    if (last && last.role === m.role) last.content += '\n' + m.content; else merged.push({ ...m });
  }

    const adText = tx(body.adText).slice(0, 300), opening = tx(body.opening).slice(0, 600);
  const meeting = await loadMeeting();
  const ageRange = `${AGE_MIN}–${AGE_MAX}`;

  const system = [
    { type: 'text', text: STATIC_PROMPT.replace('{AGE}', ageRange), cache_control: { type: 'ephemeral' } },
    { type: 'text', text: dynamicPrompt(meeting, adText, ageRange, opening) },
  ];

  let reply = '', chips: string[] = [], cta: string | null = null;
  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model: MODEL, max_tokens: 400, system, messages: merged }),
    });
    if (!r.ok) { console.error('anthropic', r.status, (await r.text()).slice(0, 300)); return json(origin, { error: 'upstream' }, 502); }
    const data = await r.json();
    const raw = (data.content ?? []).filter((b: any) => b.type === 'text').map((b: any) => b.text).join('\n');
    ({ reply, chips, cta } = parse(raw));
  } catch (e) { console.error('chat', e); return json(origin, { error: 'upstream' }, 502); }
  if (!reply) return json(origin, { error: 'empty' }, 502);
  if (cta === 'register' && !meeting) cta = 'updates'; // אין מפגש להירשם אליו

  // שמירה ברקע: לא מעכבת את התשובה
  const logMsgs = [...clean, { role: 'assistant', content: reply }];
  saveLog(tx(body.session), tx(body.src).slice(0, 20), tx(body.ad).slice(0, 40), logMsgs, cta);

  return json(origin, { reply, chips, cta });
});
