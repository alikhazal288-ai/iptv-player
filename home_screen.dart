import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(sessionProvider).value!;
    final favs = ref.watch(favoritesProvider);
    final all = [...lib.live, ...lib.movies, ...lib.series];
    List<MediaItem> source = switch (_tab) {
      0 => lib.live, 1 => lib.movies, 2 => lib.series,
      _ => all.where((e) => favs.contains(_key(e))).toList(),
    };
    final groups = source.map((e) => e.group).toSet().toList()..sort();
    var items = source.where((e) =>
        (_group == null || e.group == _group) &&
        e.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            backgroundColor: const Color(0xFF181818),
            selectedIndex: _tab,
            labelType: NavigationRailLabelType.all,
            indicatorColor: kAccent.withOpacity(.25),
            onDestinationSelected: (i) => setState(() { _tab = i; _group = null; }),
            trailing: Expanded(child: Align(alignment: Alignment.bottomCenter,
              child: IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(sessionProvider.notifier).logout()))),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.live_tv), label: Text('Live')),
              NavigationRailDestination(icon: Icon(Icons.movie), label: Text('Movies')),
              NavigationRailDestination(icon: Icon(Icons.video_library), label: Text('Series')),
              NavigationRailDestination(icon: Icon(Icons.star), label: Text('Favorites')),
            ],
          ),
          Expanded(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search', prefixIcon: const Icon(Icons.search), filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  )),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: _group, hint: const Text('Category'),
                    items: [const DropdownMenuItem(value: null, child: Text('All')),
                      ...groups.map((g) => DropdownMenuItem(value: g, child: SizedBox(width: 160, child: Text(g, overflow: TextOverflow.ellipsis))))],
                    onChanged: (v) => setState(() => _group = v),
                  ),
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _tab == 0 ? 200 : 160,
                    childAspectRatio: _tab == 0 ? 1.4 : .66,
                    crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _Card(item: items[i], fav: favs.contains(_key(items[i])),
                      onFav: () => ref.read(favoritesProvider.notifier).toggle(_key(items[i])),
                      onTap: () => _open(items[i], lib)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _key(MediaItem e) => '${e.type.name}:${e.id}';

  Future<void> _open(MediaItem item, Library lib) async {
    if (item.type == ContentType.series && lib.xtream != null) {
      final eps = await lib.xtream!.seriesEpisodes(item.id);
      if (!mounted) return;
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _EpisodeSheet(item, eps));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(url: item.url, title: item.name, epg: lib.xtream,
              streamId: item.type == ContentType.live && lib.xtream != null ? item.id : null,
              resolver: item.resolve && lib.stalker != null ? () => lib.stalker!.resolve(item) : null)));
    }
  }
}

class _EpisodeSheet extends StatelessWidget {
  final MediaItem series; final Map<int, List<Episode>> seasons;
  const _EpisodeSheet(this.series, this.seasons);
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false, initialChildSize: .8,
    builder: (_, ctl) => ListView(controller: ctl, children: [
      for (final s in (seasons.keys.toList()..sort())) ExpansionTile(
        title: Text('Season $s'), initiallyExpanded: s == seasons.keys.first,
        children: [for (final e in seasons[s]!) ListTile(
          title: Text('E${e.number} · ${e.title}'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: e.url, title: e.title))),
        )]),
    ]),
  );
}

class _Card extends StatelessWidget {
  final MediaItem item; final bool fav; final VoidCallback onTap, onFav;
  const _Card({required this.item, required this.fav, required this.onTap, required this.onFav});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, onLongPress: onFav, borderRadius: BorderRadius.circular(14),
    focusColor: kAccent.withOpacity(.35),
    child: Ink(
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: item.logo == null ? const Icon(Icons.tv, size: 40)
              : Image.network(item.logo!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 40))),
          if (fav) const Positioned(top: 6, right: 6, child: Icon(Icons.star, color: Color(0xFFFFD700))),
          if (item.rating != null && item.rating!.isNotEmpty && item.rating != '0')
            Positioned(bottom: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
              child: Text('★ ${item.rating}', style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700))))),
        ])),
        Padding(padding: const EdgeInsets.all(8),
          child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
      ]),
    ),
  );
}
