import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class XtreamApiService {
  final String server, username, password;
  XtreamApiService(String server, this.username, this.password)
      : server = server.trim().replaceAll(RegExp(r'/+$'), '');

  String get _api => '$server/player_api.php?username=$username&password=$password';

  Future<dynamic> _get(String action, [String extra = '']) async {
    final res = await http.get(Uri.parse('$_api&action=$action$extra')).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Future<void> authenticate() async {
    final res = await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 20));
    final data = json.decode(res.body);
    if (data is! Map || data['user_info']?['auth'].toString() != '1') {
      throw Exception('Invalid credentials');
    }
  }

  Future<Map<String, String>> _categories(String action) async {
    final list = await _get(action) as List;
    return {for (final c in list) '${c['category_id']}': '${c['category_name']}'};
  }

  Future<List<MediaItem>> liveStreams() async {
    final cats = await _categories('get_live_categories');
    final list = await _get('get_live_streams') as List;
    return list.map((s) => MediaItem(
          id: '${s['stream_id']}',
          name: '${s['name']}',
          url: '$server/live/$username/$password/${s['stream_id']}.m3u8',
          type: ContentType.live,
          group: cats['${s['category_id']}'] ?? 'Other',
          logo: s['stream_icon']?.toString(),
          epgId: s['epg_channel_id']?.toString(),
        )).toList();
  }

  Future<List<MediaItem>> movies() async {
    final cats = await _categories('get_vod_categories');
    final list = await _get('get_vod_streams') as List;
    return list.map((s) => MediaItem(
          id: '${s['stream_id']}',
          name: '${s['name']}',
          url: '$server/movie/$username/$password/${s['stream_id']}.${s['container_extension'] ?? 'mp4'}',
          type: ContentType.movie,
          group: cats['${s['category_id']}'] ?? 'Other',
          logo: s['stream_icon']?.toString(),
          rating: s['rating']?.toString(),
          year: (s['year'] ?? s['added'])?.toString(),
        )).toList();
  }

  Future<List<MediaItem>> series() async {
    final cats = await _categories('get_series_categories');
    final list = await _get('get_series') as List;
    return list.map((s) => MediaItem(
          id: '${s['series_id']}',
          name: '${s['name']}',
          url: '',
          type: ContentType.series,
          group: cats['${s['category_id']}'] ?? 'Other',
          logo: s['cover']?.toString(),
          rating: s['rating']?.toString(),
          year: s['releaseDate']?.toString(),
        )).toList();
  }

  Future<Map<int, List<Episode>>> seriesEpisodes(String seriesId) async {
    final data = await _get('get_series_info', '&series_id=$seriesId');
    final out = <int, List<Episode>>{};
    final eps = data['episodes'];
    if (eps is Map) {
      eps.forEach((season, list) {
        final sn = int.tryParse('$season') ?? 1;
        out[sn] = (list as List).map((e) => Episode(
              '${e['id']}',
              '${e['title']}',
              '$server/series/$username/$password/${e['id']}.${e['container_extension'] ?? 'mp4'}',
              sn,
              int.tryParse('${e['episode_num']}') ?? 0,
            )).toList();
      });
    }
    return out;
  }

  Future<List<EpgEntry>> shortEpg(String streamId) async {
    final data = await _get('get_short_epg', '&stream_id=$streamId&limit=6');
    final list = (data['epg_listings'] as List?) ?? [];
    String dec(String s) { try { return utf8.decode(base64.decode(s)); } catch (_) { return s; } }
    return list.map((e) => EpgEntry(
          dec('${e['title']}'),
          DateTime.fromMillisecondsSinceEpoch(int.parse('${e['start_timestamp']}') * 1000),
          DateTime.fromMillisecondsSinceEpoch(int.parse('${e['stop_timestamp']}') * 1000),
        )).toList();
  }
}
