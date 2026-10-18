enum ContentType { live, movie, series }

class MediaItem {
  final String id, name, url, group;
  final String? logo, epgId, rating, year;
  final ContentType type;
  final bool resolve; // Stalker: link must be resolved before playing
  const MediaItem({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.group = 'Uncategorized',
    this.logo,
    this.epgId,
    this.rating,
    this.year,
    this.resolve = false,
  });
}

class Episode {
  final String id, title, url;
  final int season, number;
  const Episode(this.id, this.title, this.url, this.season, this.number);
}

class EpgEntry {
  final String title;
  final DateTime start, end;
  const EpgEntry(this.title, this.start, this.end);
}

enum LoginKind { xtream, m3uUrl, m3uFile, stalker }

class Credentials {
  final LoginKind kind;
  final String server, username, password, m3uSource, mac;
  const Credentials({
    required this.kind,
    this.server = '',
    this.username = '',
    this.password = '',
    this.m3uSource = '',
    this.mac = '',
  });
}
