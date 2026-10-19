import 'dart:convert';
import 'dart:io';
import '../models/models.dart';

class StorageService {
  static File get _f => File('${Directory.systemTemp.path}/iptv_store.json');

  static Future<Map<String, dynamic>> _read() async {
    try {
      if (await _f.exists()) {
        return json.decode(await _f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _write(Map<String, dynamic> m) async {
    try {
      await _f.writeAsString(json.encode(m));
    } catch (_) {}
  }

  static Future<void> saveCredentials(Credentials c) async {
    final m = await _read();
    m['creds'] = {
      'kind': c.kind.index, 'server': c.server, 'user': c.username,
      'pass': c.password, 'm3u': c.m3uSource, 'mac': c.mac,
    };
    await _write(m);
  }

  static Future<Credentials?> loadCredentials() async {
    final c = (await _read())['creds'];
    if (c == null) return null;
    return Credentials(
      kind: LoginKind.values[c['kind']],
      server: c['server'], username: c['user'], password: c['pass'],
      m3uSource: c['m3u'], mac: c['mac'] ?? '',
    );
  }

  static Future<void> clear() async {
    final m = await _read();
    m.remove('creds');
    await _write(m);
  }

  static Future<Set<String>> loadFavorites() async =>
      List<String>.from((await _read())['favs'] ?? []).toSet();

  static Future<void> saveFavorites(Set<String> f) async {
    final m = await _read();
    m['favs'] = f.toList();
    await _write(m);
  }
}
