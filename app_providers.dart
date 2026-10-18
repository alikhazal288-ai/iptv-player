import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/m3u_parser.dart';
import '../services/storage_service.dart';
import '../services/stalker_service.dart';
import '../services/xtream_api_service.dart';

class Library {
  final List<MediaItem> live, movies, series;
  final XtreamApiService? xtream;
  final StalkerService? stalker;
  const Library(this.live, this.movies, this.series, this.xtream, [this.stalker]);
}

class SessionNotifier extends StateNotifier<AsyncValue<Library?>> {
  SessionNotifier() : super(const AsyncData(null));

  Future<void> restore() async {
    final c = await StorageService.loadCredentials();
    if (c != null) await login(c, save: false);
  }

  Future<void> login(Credentials c, {bool save = true}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      Library lib;
      if (c.kind == LoginKind.xtream) {
        final api = XtreamApiService(c.server, c.username, c.password);
        await api.authenticate();
        final r = await Future.wait([api.liveStreams(), api.movies(), api.series()]);
        lib = Library(r[0], r[1], r[2], api);
      } else if (c.kind == LoginKind.stalker) {
        final api = StalkerService(c.server, c.mac.trim());
        await api.authenticate();
        final r = await Future.wait([api.liveStreams(), api.movies()]);
        lib = Library(r[0], r[1], const [], null, api);
      } else {
        final text = c.kind == LoginKind.m3uUrl
            ? (await http.get(Uri.parse(c.m3uSource)).timeout(const Duration(seconds: 60))).body
            : await File(c.m3uSource).readAsString();
        final all = M3uParser.parse(text);
        if (all.isEmpty) throw Exception('No entries found in playlist');
        lib = Library(
          all.where((e) => e.type == ContentType.live).toList(),
          all.where((e) => e.type == ContentType.movie).toList(),
          all.where((e) => e.type == ContentType.series).toList(),
          null,
        );
      }
      if (save) await StorageService.saveCredentials(c);
      return lib;
    });
  }

  Future<void> logout() async {
    await StorageService.clear();
    state = const AsyncData(null);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, AsyncValue<Library?>>((_) => SessionNotifier());

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) { StorageService.loadFavorites().then((v) => state = v); }
  void toggle(String key) {
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
    StorageService.saveFavorites(state);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((_) => FavoritesNotifier());
