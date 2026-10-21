# Website (Cloudflare Worker)

Publieke pagina's die Google Play vraagt, op dezelfde manier als bij Cooklet:

| Pagina | Waarvoor |
|---|---|
| `/privacy` | Privacybeleid: link in de app (Profiel → Privacy) en in de Play Console |
| `/account/delete` | Account verwijderen zonder de app: Play Console → *Data safety* → *Delete account URL* |

Taal: `?lang=nl` of `?lang=en`, anders de taal van de browser.

## Eerste keer online zetten

Vanuit deze map (`site/`):

```bash
npx wrangler login
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_PUBLISHABLE_KEY
npx wrangler deploy
```

Gebruik dezelfde waarden als in `env.json` (enkel de **publishable** key, nooit
`service_role`). Het adres wordt `https://circlebeacon.frankythys.workers.dev`;
dat staat ook in `lib/core/config/site_links.dart`. Een ander adres? Pas het
daar aan.

`/account/delete` werkt pas nadat migratie 025 in Supabase draait.

## Testen

```bash
node --test site/worker.test.mjs
```
