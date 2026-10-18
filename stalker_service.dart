import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Stalker / Ministra (MAG) portal client. Uses the portal URL + MAC address
/// supplied by the user's own provider.
class StalkerService {
  final String portal;
  final String mac;
  String? _api;
  String? _token;

  StalkerService(String portal, this.mac) : portal = portal.trim().replaceAll(RegExp(r'/+$'), '');

  List<String> get _candidates {
    var b = portal.replaceAll(RegExp(r'/c$'), '');
    if (b.endsWith('load.php') || b.endsWith('portal.php')) return [b];
    final c = <String>[
      if (b.contains('stalker_portal')) '$b/server/load.php',
      '$b/stalker_portal/server/load.php',
      '$b/portal.php',
      '$b/server/load.php',
    ];
    return c.toSet().toList();
  }

  Map<String, String> get _headers => {
        'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
        'X-User-Agent': 'Model: MAG250; Link: WiFi',
        'Cookie': 'mac=$mac; stb_lang=en; timezone=GMT',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _call(Map<String, String> q, {String? api}) async {
    final uri = Uri.parse(api ?? _api!).replace(queryParameters: {...q, 'JsHttpRequest': '1-xml'});
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    final body = json.decode(utf8.decode(res.bodyBytes));
    return body['js'];
  }

  Future<void> authenticate() async {
    Object? lastErr;
    for (final api in _candidates) {
      try {
        _token = null;
        final js = await _call({'type': 'stb', 'action': 'handshake', 'token': ''}, api: api);
        final t = js is Map ? js['token']?.toString() : null;
        if (t == null || t.isEmpty) continue;
        _token = t;
        _api = api;
        await _call({'type': 'stb', 'action': 'get_profile', 'hd': '1', 'stb_type': 'MAG250', 'ver': 'ImageDescription: 0.2.18-r14-pub-250; ImageDate: Fri Jan 15 15:20:44 EET 2016'});
        return;
      } catch (e) {
        lastErr = e;
      }
    }
    throw Exception('Portal authentication failed${lastErr != null ? ': $lastErr' : ''}');
  }

  List _list(dynamic js) => js is List ? js : (js is Map && js['data'] is List ? js['data'] : []);

  Future<Map<String, String>> _genres(String type, String action) async {
    try {
      return {for (final g in _list(await _call({'type': type, 'action': action}))) '${g['id']}': '${g['title'] ?? g['name']}'};
    } catch (_) {
      return {};
    }
  }

  Future<List<MediaItem>> liveStreams() async {
    final genres = await _genres('itv', 'get_genres');
    final js = await _call({'type': 'itv', 'action': 'get_all_channels'});
    return _list(js).map<MediaItem>((c) => MediaItem(
          id: '${c['id']}',
          name: '${c['name']}',
          url: '${c['cmd']}',
          type: ContentType.live,
          group: genres['${c['tv_genre_id']}'] ?? 'Other',
          logo: (c['logo'] ?? '').toString().isEmpty ? null : c['logo'].toString(),
          resolve: true,
        )).toList();
  }

  Future<List<MediaItem>> movies({int maxPages = 15}) async {
    final cats = await _genres('vod', 'get_categories');
    final out = <MediaItem>[];
    for (var p = 1; p <= maxPages; p++) {
      final js = await _call({'type': 'vod', 'action': 'get_ordered_list', 'p': '$p', 'sortby': 'added'});
      final data = _list(js);
      if (data.isEmpty) break;
      for (final m in data) {
        out.add(MediaItem(
          id: '${m['id']}',
          name: '${m['name']}',
          url: '${m['cmd']}',
          type: ContentType.movie,
          group: cats['${m['category_id']}'] ?? 'Movies',
          logo: (m['screenshot_uri'] ?? '').toString().isEmpty ? null : m['screenshot_uri'].toString(),
          rating: m['rating_imdb']?.toString(),
          year: m['year']?.toString(),
          resolve: true,
        ));
      }
      final total = int.tryParse('${js is Map ? js['total_items'] : 0}') ?? 0;
      if (total > 0 && out.length >= total) break;
    }
    return out;
  }

  /// Stalker links are temporary: resolve right before playback.
  Future<String> resolve(MediaItem item) async {
    final js = await _call({
      'type': item.type == ContentType.movie ? 'vod' : 'itv',
      'action': 'create_link',
      'cmd': item.url,
      'series': '',
      'forced_storage': '',
      'disable_ad': '0',
    });
    var cmd = (js is Map ? js['cmd'] : '').toString().trim();
    if (cmd.isEmpty) throw Exception('Could not resolve stream');
    if (cmd.contains(' ')) cmd = cmd.split(' ').last; // strip "ffmpeg " prefix
    return cmd;
  }
}
