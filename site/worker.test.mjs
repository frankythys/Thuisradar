// Tests voor de website-Worker, met een nagebootste Supabase (fetch).
// Draaien: node --test site/worker.test.mjs

import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';

import worker, { deleteAccount, pickLang } from './worker.js';

const env = {
  SUPABASE_URL: 'https://demo.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test',
  CONTACT_EMAIL: 'hulp@example.com',
  OWNER_NAME: 'Test & Co',
};
const realFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = realFetch;
});

/** Nagebootste Supabase: [methode, pad-begin] → antwoord. Houdt de oproepen bij. */
function fakeSupabase(routes) {
  const calls = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(input);
    const method = init.method ?? 'GET';
    calls.push({ method, path: url.pathname + url.search, body: init.body, headers: init.headers });
    for (const [key, reply] of routes) {
      const [m, prefix] = key.split(' ');
      if (m === method && (url.pathname + url.search).startsWith(prefix)) {
        const { status = 200, json = {} } = typeof reply === 'function' ? reply(url, init) : reply;
        return new Response(status === 204 ? null : JSON.stringify(json), { status });
      }
    }
    throw new Error(`onverwachte oproep ${method} ${url.pathname}`);
  };
  return calls;
}

const loginOk = ['POST /auth/v1/token', { json: { access_token: 'tok', user: { id: 'u1' } } }];

test('taal: ?lang wint, anders de browser, anders Engels', () => {
  const req = (lang) => new Request('https://x/', { headers: lang ? { 'Accept-Language': lang } : {} });
  assert.equal(pickLang(req('nl-BE,nl;q=0.9'), new URL('https://x/')), 'nl');
  assert.equal(pickLang(req('nl-BE'), new URL('https://x/?lang=en')), 'en');
  assert.equal(pickLang(req('de-DE'), new URL('https://x/')), 'en');
});

test('privacybeleid: in het Nederlands, met contact en zonder scripts', async () => {
  const res = await worker.fetch(new Request('https://x/privacy?lang=nl'), env);
  assert.equal(res.status, 200);
  const html = await res.text();
  assert.match(html, /Privacybeleid/);
  assert.match(html, /hulp@example\.com/);
  assert.match(html, /Test &amp; Co/, 'eigenaar wordt ge-escaped');
  assert.match(html, /31 dagen/);
  assert.doesNotMatch(html, /<script/i);
  assert.match(res.headers.get('Content-Security-Policy'), /default-src 'none'/);
});

test('onbekende pagina: 404', async () => {
  const res = await worker.fetch(new Request('https://x/admin'), env);
  assert.equal(res.status, 404);
});

test('verwijderen: bijlagen weg, daarna het account', async () => {
  const calls = fakeSupabase([
    loginOk,
    ['GET /rest/v1/family_members?select=family_id,role', { json: [{ family_id: 'f1', role: 'member' }] }],
    ['POST /storage/v1/object/list/family-media', { json: [{ name: 'a.jpg' }, { name: 'b.m4a' }] }],
    ['DELETE /storage/v1/object/family-media', { json: [] }],
    ['POST /rest/v1/rpc/delete_my_account', { status: 204, json: null }],
  ]);
  assert.equal(await deleteAccount(env, 'oma@example.com', 'geheim'), 'deleted');
  const removed = calls.find((c) => c.method === 'DELETE');
  assert.deepEqual(JSON.parse(removed.body).prefixes, ['f1/u1/a.jpg', 'f1/u1/b.m4a']);
  const rpc = calls.find((c) => c.path.includes('delete_my_account'));
  assert.equal(rpc.headers.Authorization, 'Bearer tok');
  assert.ok(calls.indexOf(removed) < calls.indexOf(rpc), 'eerst de bijlagen');
});

test('verkeerd wachtwoord: niets gewist', async () => {
  const calls = fakeSupabase([['POST /auth/v1/token', { status: 400, json: { error: 'invalid_grant' } }]]);
  assert.equal(await deleteAccount(env, 'oma@example.com', 'fout'), 'bad_login');
  assert.equal(calls.length, 1);
});

test('beheerder met andere leden: eerst overdragen, niets gewist', async () => {
  const calls = fakeSupabase([
    loginOk,
    ['GET /rest/v1/family_members?select=family_id,role', { json: [{ family_id: 'f1', role: 'owner' }] }],
    ['GET /rest/v1/family_members?select=user_id', { json: [{ user_id: 'u2' }] }],
  ]);
  assert.equal(await deleteAccount(env, 'papa@example.com', 'geheim'), 'owner');
  assert.ok(!calls.some((c) => c.method === 'DELETE' || c.path.includes('delete_my_account')));
});

test('beheerder die alleen is: mag weg', async () => {
  fakeSupabase([
    loginOk,
    ['GET /rest/v1/family_members?select=family_id,role', { json: [{ family_id: 'f1', role: 'owner' }] }],
    ['GET /rest/v1/family_members?select=user_id', { json: [] }],
    ['POST /storage/v1/object/list/family-media', { json: [] }],
    ['POST /rest/v1/rpc/delete_my_account', { status: 204, json: null }],
  ]);
  assert.equal(await deleteAccount(env, 'papa@example.com', 'geheim'), 'deleted');
});

test('formulier zonder gegevens: uitleg, geen oproep naar Supabase', async () => {
  const calls = fakeSupabase([]);
  const res = await worker.fetch(
    new Request('https://x/account/delete?lang=nl', { method: 'POST', body: new URLSearchParams({ email: '' }) }),
    env,
  );
  assert.equal(res.status, 400);
  assert.match(await res.text(), /Vul je e-mailadres en wachtwoord in/);
  assert.equal(calls.length, 0);
});

test('zonder Supabase-instellingen: veilig falen', async () => {
  assert.equal(await deleteAccount({}, 'a@b.c', 'x'), 'failed');
});
