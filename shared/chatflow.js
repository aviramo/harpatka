/* Harpatka scripted chat: a pre-written conversation, no AI, no server, no database.
   Five messages, three buttons under each, the same structure for every pain. Looks like a chat: the other side "types" (three dots), then the bubble appears,
   and the three buttons appear at once under it. There is no writing bar: buttons only.

   Usage (see README.md):
     HarpatkaChat.init({
       root: document.getElementById('chat'),          // an empty element; the engine builds everything inside it
       script: 'chat.script.json',                     // a URL or the parsed object
       pain: 'opening_up', gender: 'female',           // from the link: ?pain=...&gender=female|male
       whatsapp: '972552589829', whatsappText: '...', updatesLink: 'https://chat.whatsapp.com/...',
       onSite: function () { ... },                     // the visitor chose "to the site": run your own reveal (the chat page rises, the site shows)
       track: function (name, data) { ... }              // optional, e.g. fbq('trackCustom', name, data)
     });

   Texts in the script carry {f:text for a woman|m:text for a man}. An unknown gender falls back to the man's form. An unknown pain falls back to script.defaultPain. */
(function () {
  'use strict';
  var pick = function (t, g) { return String(t == null ? '' : t).replace(/\{f:([^|}]*)\|m:([^}]*)\}/g, function (_, f, m) { return g === 'female' ? f : m; }); };
  var el = function (tag, cls, txt) { var e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; };
  var wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };

  async function init(o) {
    var root = o.root, track = o.track || function () {};
    var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
    var g = o.gender === 'female' ? 'female' : 'male';
    var script = typeof o.script === 'string' ? await (await fetch(o.script, { cache: 'no-cache' })).json() : o.script;
    var pain = (script.pains && script.pains[o.pain]) || script.pains[script.defaultPain] || Object.values(script.pains)[0];
    var T = function (t) { return pick(t, g); };

    // the five messages: three of the pain, then the biodanza question (the pain's own sentence first), then the invitation
    var steps = [pain.s1, pain.s2, pain.s3,
      { say: T(pain.help) + '. ' + script.common.s4.say, options: script.common.s4.options },
      { say: script.common.s5.say, options: script.common.s5.options, final: true }];

    root.classList.add('hc-root');
    root.innerHTML = '';
    var log = el('div', 'hc-log'); log.setAttribute('role', 'log'); log.setAttribute('aria-live', 'polite');
    root.appendChild(log);

    var scroll = function () { log.scrollTo({ top: log.scrollHeight, behavior: reduce ? 'auto' : 'smooth' }); };
    var who = function () { log.appendChild(el('div', 'hc-who', o.botName || 'הבוט של יוצאים להרפתקה')); };
    var bubble = function (role, text) { var b = el('div', 'hc-msg ' + (role === 'user' ? 'hc-me' : 'hc-bot'), text); log.appendChild(b); return b; };
    var typing = function () { var t = el('div', 'hc-typing'); t.setAttribute('aria-label', 'הבוט כותב'); t.innerHTML = '<i></i><i></i><i></i>'; log.appendChild(t); scroll(); return t; };
    var delay = function (text) { return reduce ? 0 : Math.min(1800, 500 + String(text).length * 16); };
    var say = async function (role, text, instant) {
      if (role === 'bot' && !instant) { var t = typing(); await wait(delay(text)); t.remove(); }
      bubble(role, text); scroll();
    };

    var SKEY = (o.storageKey || 'harpatka_chat') + ':' + (o.pain || 'default') + ':' + g;
    var st = null;
    if (new URLSearchParams(location.search).get('fresh')) { try { sessionStorage.removeItem(SKEY); } catch (e) {} }
    try { st = JSON.parse(sessionStorage.getItem(SKEY) || 'null'); } catch (e) {}
    if (!st || !Array.isArray(st.log)) st = { i: 0, log: [] };
    var save = function () { try { sessionStorage.setItem(SKEY, JSON.stringify(st)); } catch (e) {} };

    var row = null;
    var clearRow = function () { if (row) { row.remove(); row = null; } };
    var waUrl = function (text) { return 'https://wa.me/' + o.whatsapp + '?text=' + encodeURIComponent(text || o.whatsappText || ''); };

    function showOptions(i) {
      clearRow();
      var step = steps[i];
      row = el('div', 'hc-chips');
      step.options.forEach(function (op, k) {
        if (step.final) {
          var a = el('a', 'hc-chip', T(op.label)); a.href = '#'; a.setAttribute('role', 'button');
          a.addEventListener('click', function (e) {
            e.preventDefault();
            track('ChatCTA', { kind: op.action, pain: o.pain || 'default' });
            if (op.action === 'site') { if (typeof o.onSite === 'function') o.onSite(); else if (o.siteUrl) location.href = o.siteUrl; }
            else if (op.action === 'updates') window.open(o.updatesLink, '_blank', 'noopener');
            else window.open(waUrl(), '_blank', 'noopener');
          });
          row.appendChild(a);
        } else {
          var b = el('button', 'hc-chip', T(op.label)); b.type = 'button';
          b.addEventListener('click', function () { choose(i, k); });
          row.appendChild(b);
        }
      });
      log.appendChild(row); scroll();
    }

    var busy = false;
    async function choose(i, k) {
      if (busy) return; busy = true; clearRow();
      var op = steps[i].options[k], label = T(op.label), ack = T(op.ack);
      st.log.push({ r: 'user', t: label }); st.i = i + 1; save();
      track('ChatStep', { pain: o.pain || 'default', step: i + 1, option: k + 1 });
      await say('user', label, true);
      await say('bot', ack);
      var text = T(steps[i + 1].say);
      st.log.push({ r: 'bot', t: ack }, { r: 'bot', t: text }); save();
      await say('bot', text);
      showOptions(i + 1); busy = false;
    }

    track('ChatOpen', { ad: o.pain || '', source: 'script' });
    if (st.log.length) {
      who();
      st.log.forEach(function (m) { bubble(m.r === 'user' ? 'user' : 'bot', m.t); });
      showOptions(Math.min(st.i, steps.length - 1)); scroll();
      return;
    }
    who();
    var hello = 'היי, אני הבוט של "יוצאים להרפתקה" 🙂';
    await say('bot', hello);
    var first = T(steps[0].say);
    st.log.push({ r: 'bot', t: hello }, { r: 'bot', t: first }); save();
    await say('bot', first);
    showOptions(0);
  }

  window.HarpatkaChat = { init: init };
})();
