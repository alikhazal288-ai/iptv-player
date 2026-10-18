import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static Future<void> saveCredentials(Credentials c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('creds', json.encode({
      'kind': c.kind.index, 'server': c.server, 'user': c.username,
      'pass': c.password, 'm3u': c.m3uSource, 'mac': c.mac,
    }));
  }

  static Future<Credentials?> loadCredentials() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('creds');
    if (s == null) return null;
    final m = json.decode(s);
    return Credentials(
      kind: LoginKind.values[m['kind']],
      server: m['server'], username: m['user'], password: m['pass'], m3uSource: m['m3u'], mac: m['mac'] ?? '',
    );
  }

  static Future<void> clear() async => (await SharedPreferences.getInstance()).clear();

  static Future<Set<String>> loadFavorites() async =>
      ((await SharedPreferences.getInstance()).getStringList('favs') ?? []).toSet();

  static Future<void> saveFavorites(Set<String> f) async =>
      (await SharedPreferences.getInstance()).setStringList('favs', f.toList());
}
