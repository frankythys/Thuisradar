/**
 * Publieke website van CircleBeacon (Cloudflare Worker), zie README.md.
 *
 *   GET  /                 korte uitleg + links
 *   GET  /privacy          privacybeleid (Google Play: in de app en in de Console)
 *   GET  /bevestigd        landingspagina na de bevestigingsmail van een nieuw account
 *                          (Supabase bevestigt zelf; hier enkel "open de app")
 *   GET  /account/delete   formulier om het account te verwijderen (Google Play)
 *   POST /account/delete   aanmelden bij Supabase met e-mail + wachtwoord en
 *                          dan hetzelfde doen als de app: eigen bijlagen wissen,
 *                          daarna delete_my_account (migratie 025)
 *
 * De Worker bewaart niets en logt geen wachtwoorden. Hij gebruikt enkel de
 * publieke Supabase-sleutel (dezelfde als in de app) en het token van de
 * gebruiker zelf; de RLS-regels en delete_my_account doen de controles.
 * Taal: ?lang=nl|en, anders de taal van de browser.
 */

import { TEXT } from './content.js';

const BUCKET = 'family-media';
const PAGE = 100;
const STYLE = `body{font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#1d2a36;background:#f3f8fc;margin:0}
main{max-width:720px;margin:0 auto;padding:32px 20px 48px}h1{font-size:28px;margin:0 0 4px}h2{font-size:19px;margin:28px 0 6px}
a{color:#1769aa}.muted{color:#5b6b7a;font-size:14px}.card{background:#fff;border-radius:16px;padding:20px;margin-top:20px;box-shadow:0 1px 3px #0001}
label{display:block;font-weight:600;margin-top:12px}input{width:100%;box-sizing:border-box;font:inherit;padding:10px 12px;border:1px solid #c9d6e2;border-radius:10px}
button{margin-top:18px;font:inherit;font-weight:700;color:#fff;background:#c62828;border:0;border-radius:10px;padding:12px 16px;cursor:pointer}
.note{padding:12px 14px;border-radius:10px;margin-top:16px}.ok{background:#e6f4ea}.err{background:#fdecea}nav{margin-top:28px}`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const t = TEXT[pickLang(request, url)];
    const path = url.pathname.replace(/\/$/, '') || '/';

    if (request.method === 'GET' && path === '/') return page(t, t.home.title, homeBody(t));
    if (request.method === 'GET' && path === '/privacy') return page(t, t.privacy.title, privacyBody(t, env));
    if (request.method === 'GET' && path === '/bevestigd') {
      // Supabase zet error/error_code in de query als de link verlopen of al gebruikt is.
      const failed = url.searchParams.has('error') || url.searchParams.has('error_code');
      return failed
        ? page(t, t.confirmed.errorTitle, `<p class="note err" role="alert">${t.confirmed.error}</p>`)
        : page(t, t.confirmed.title, `<p class="note ok">${t.confirmed.body}</p>`);
    }
    if (path === '/account/delete') {
      if (request.method === 'GET') return page(t, t.del.title, deleteBody(t, env));
      if (request.method === 'POST') return handleDelete(request, env, t);
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, POST' } });
    }
    return new Response('Not found', { status: 404, headers: securityHeaders('text/plain; charset=utf-8') });
  },
};

export function pickLang(request, url) {
  const asked = url.searchParams.get('lang');
  if (asked === 'nl' || asked === 'en') return asked;
  return /^nl\b/i.test(request.headers.get('Accept-Language') ?? '') ? 'nl' : 'en';
}

// ─── Account verwijderen ────────────────────────────────────────────────────

async function handleDelete(request, env, t) {
  let form;
  try {
    form = await request.formData();
  } catch {
    return page(t, t.del.title, deleteBody(t, env, { error: t.del.missing }), 400);
  }
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  if (!email || !password) return page(t, t.del.title, deleteBody(t, env, { error: t.del.missing }), 400);

  const result = await deleteAccount(env, email, password);
  if (result === 'deleted') return page(t, t.del.title, deleteBody(t, env, { done: true }));
  const message = { bad_login: t.del.badLogin, owner: t.del.owner }[result] ?? t.del.failed;
  return page(t, t.del.title, deleteBody(t, env, { error: message }), result === 'bad_login' ? 401 : 400);
}

/** Zelfde volgorde als AccountDeletionRepository in de app. Geeft
 *  'deleted', 'bad_login', 'owner' of 'failed' terug. */
export async function deleteAccount(env, email, password) {
  const base = String(env.SUPABASE_URL ?? '').replace(/\/$/, '');
  const key = String(env.SUPABASE_PUBLISHABLE_KEY ?? '');
  if (!base.startsWith('https://') || !key) return 'failed';

  const login = await fetch(`${base}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: key, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (login.status === 400 || login.status === 401) return 'bad_login';
  if (!login.ok) return 'failed';
  const session = await login.json();
  const userId = session?.user?.id;
  if (!session?.access_token || !userId) return 'failed';
  const auth = { apikey: key, Authorization: `Bearer ${session.access_token}`, 'Content-Type': 'application/json' };

  // De beheerder van een gezin met nog andere leden moet eerst overdragen;
  // dat vooraf nagaan, zodat er dan ook geen bijlagen verdwijnen.
  const mine = await getJson(`${base}/rest/v1/family_members?select=family_id,role&user_id=eq.${userId}`, auth);
  if (!mine) return 'failed';
  for (const { family_id: familyId, role } of mine) {
    if (role !== 'owner') continue;
    const others = await getJson(
      `${base}/rest/v1/family_members?select=user_id&family_id=eq.${familyId}&user_id=neq.${userId}&limit=1`,
      auth,
    );
    if (!others) return 'failed';
    if (others.length > 0) return 'owner';
  }

  const paths = [];
  for (const { family_id: familyId } of mine) {
    const folder = `${familyId}/${userId}`;
    for (let offset = 0; ; offset += PAGE) {
      const res = await fetch(`${base}/storage/v1/object/list/${BUCKET}`, {
        method: 'POST',
        headers: auth,
        body: JSON.stringify({ prefix: folder, limit: PAGE, offset }),
      });
      if (!res.ok) return 'failed';
      const files = await res.json();
      paths.push(...files.map((file) => `${folder}/${file.name}`));
      if (files.length < PAGE) break;
    }
  }
  if (paths.length > 0) {
    const removed = await fetch(`${base}/storage/v1/object/${BUCKET}`, {
      method: 'DELETE',
      headers: auth,
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!removed.ok) return 'failed';
  }

  const rpc = await fetch(`${base}/rest/v1/rpc/delete_my_account`, { method: 'POST', headers: auth, body: '{}' });
  if (rpc.ok) return 'deleted';
  const error = await rpc.json().catch(() => null);
  return String(error?.message ?? '').includes('beheer over') ? 'owner' : 'failed';
}

async function getJson(url, headers) {
  const res = await fetch(url, { headers });
  return res.ok ? res.json() : null;
}

// ─── Pagina's ───────────────────────────────────────────────────────────────

function fill(html, env) {
  return html
    .replaceAll('{EMAIL}', escapeHtml(env.CONTACT_EMAIL ?? ''))
    .replaceAll('{OWNER}', escapeHtml(env.OWNER_NAME ?? ''));
}

function homeBody(t) {
  const links = t.home.links.map(([label, href]) => `<li><a href="${href}?lang=${t.lang}">${label}</a></li>`).join('');
  return `<p>${t.home.intro}</p><ul>${links}</ul>`;
}

function privacyBody(t, env) {
  const sections = t.privacy.sections.map(([heading, body]) => `<h2>${heading}</h2>${fill(body, env)}`).join('');
  return `<p class="muted">${t.privacy.updated}</p>${sections}`;
}

function deleteBody(t, env, { error, done } = {}) {
  const note = done
    ? `<p class="note ok">${t.del.done}</p>`
    : error
      ? `<p class="note err" role="alert">${escapeHtml(error)}</p>`
      : '';
  const form = done
    ? ''
    : `<form method="POST" action="/account/delete?lang=${t.lang}" class="card">
<label for="email">${t.del.email}</label><input id="email" name="email" type="email" autocomplete="email" required>
<label for="password">${t.del.password}</label><input id="password" name="password" type="password" autocomplete="current-password" required>
<button type="submit">${t.del.submit}</button></form>`;
  return `<p>${t.del.intro}</p><p>${t.del.inApp}</p>${note}${form}<p class="muted">${fill(t.del.google, env)}</p>`;
}

function page(t, title, body, status = 200) {
  const html = `<!doctype html><html lang="${t.lang}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} — CircleBeacon</title>
<style>${STYLE}</style></head><body><main><h1>${title}</h1>${body}
<nav class="muted"><a href="/?lang=${t.lang}">${t.footer}</a> · <a href="/privacy?lang=${t.lang}">${t.home.links[0][0]}</a> ·
<a href="/account/delete?lang=${t.lang}">${t.home.links[1][0]}</a> · <a href="?lang=${t.other.lang}">${t.other.label}</a></nav>
</main></body></html>`;
  return new Response(html, { status, headers: securityHeaders('text/html; charset=utf-8') });
}

function securityHeaders(contentType) {
  return {
    'Content-Type': contentType,
    'Content-Security-Policy':
      "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'Strict-Transport-Security': 'max-age=31536000',
    'Cache-Control': 'no-store',
  };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}
