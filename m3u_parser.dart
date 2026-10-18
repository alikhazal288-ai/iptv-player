import '../models/models.dart';

class M3uParser {
  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  static List<MediaItem> parse(String content) {
    final items = <MediaItem>[];
    final lines = content.replaceAll('\r', '').split('\n');
    Map<String, String> attrs = {};
    String name = '';
    String? groupOverride;
    var i = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        attrs = {for (final m in _attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!};
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : (attrs['tvg-name'] ?? '');
        if (name.isEmpty) name = attrs['tvg-name'] ?? 'Channel ${items.length + 1}';
      } else if (line.startsWith('#EXTGRP:')) {
        groupOverride = line.substring(8).trim();
      } else if (!line.startsWith('#')) {
        if (name.isEmpty) continue;
        items.add(MediaItem(
          id: '${i++}',
          name: name,
          url: line,
          type: _guessType(line, attrs['group-title'] ?? groupOverride ?? ''),
          group: attrs['group-title'] ?? groupOverride ?? 'Uncategorized',
          logo: _nullIfEmpty(attrs['tvg-logo']),
          epgId: _nullIfEmpty(attrs['tvg-id']),
        ));
        attrs = {};
        name = '';
        groupOverride = null;
      }
    }
    return items;
  }

  static String? _nullIfEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  static ContentType _guessType(String url, String group) {
    final u = url.toLowerCase();
    final g = group.toLowerCase();
    if (u.contains('/series/') || g.contains('series')) return ContentType.series;
    if (u.contains('/movie/') || u.endsWith('.mp4') || u.endsWith('.mkv') || g.contains('movie') || g.contains('vod')) {
      return ContentType.movie;
    }
    return ContentType.live;
  }
}
