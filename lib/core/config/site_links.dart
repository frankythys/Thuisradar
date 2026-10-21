/// Publieke webpagina's van CircleBeacon: een Cloudflare Worker (map `site/`,
/// zie `site/README.md`). Google Play eist het privacybeleid in de app en
/// in de Play Console; de verwijderpagina hoort in de Play Console.
abstract final class SiteLinks {
  static const _base = 'https://circlebeacon.frankythys.workers.dev';

  static final privacy = Uri.parse('$_base/privacy');
}
