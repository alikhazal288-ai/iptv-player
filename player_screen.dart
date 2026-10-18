import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/models.dart';
import '../services/xtream_api_service.dart';

class PlayerScreen extends StatefulWidget {
  final String url, title;
  final XtreamApiService? epg;
  final String? streamId;
  final Future<String> Function()? resolver;
  const PlayerScreen({super.key, required this.url, required this.title, this.epg, this.streamId, this.resolver});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player(configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
  late final VideoController _video = VideoController(_player);
  final _focus = FocusNode();
  final _subs = <StreamSubscription>[];
  int _aspectMode = 0; // 0 original, 1 16:9, 2 fit(crop), 3 stretch
  bool _controls = true;
  Timer? _hide;
  int _retries = 0;
  List<EpgEntry> _epg = [];

  static const _labels = ['Original', '16:9', 'Fit (crop)', 'Stretch'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open();
    // Auto-reconnect on error or unexpected end of a live stream
    _subs.add(_player.stream.error.listen((_) => _reconnect()));
    _subs.add(_player.stream.completed.listen((done) {
      if (done && (widget.streamId != null || widget.resolver != null)) _reconnect();
    }));
    _subs.add(_player.stream.playing.listen((p) { if (p) _retries = 0; }));
    if (widget.epg != null && widget.streamId != null) {
      widget.epg!.shortEpg(widget.streamId!).then((e) { if (mounted) setState(() => _epg = e); }).catchError((_) {});
    }
    _kick();
  }

  Future<void> _open() async {
    try {
      final url = widget.resolver != null ? await widget.resolver!() : widget.url;
      if (mounted) await _player.open(Media(url));
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_retries >= 8) return;
    _retries++;
    Future.delayed(Duration(seconds: _retries.clamp(1, 5)), () { if (mounted) _open(); });
  }

  void _kick() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _controls = false); });
  }

  BoxFit get _fit => switch (_aspectMode) { 2 => BoxFit.cover, 3 => BoxFit.fill, _ => BoxFit.contain };
  double? get _aspect => _aspectMode == 1 ? 16 / 9 : null;

  void _trackSheet({required bool audio}) {
    final tracks = _player.state.tracks;
    showModalBottomSheet(context: context, builder: (_) => ListView(shrinkWrap: true, children: [
      if (!audio) ListTile(title: const Text('Off'), onTap: () { _player.setSubtitleTrack(SubtitleTrack.no()); Navigator.pop(context); }),
      if (audio)
        for (final t in tracks.audio.where((t) => t.id != 'auto' && t.id != 'no'))
          ListTile(title: Text(t.title ?? t.language ?? 'Track ${t.id}'),
              onTap: () { _player.setAudioTrack(t); Navigator.pop(context); })
      else
        for (final t in tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no'))
          ListTile(title: Text(t.title ?? t.language ?? 'Track ${t.id}'),
              onTap: () { _player.setSubtitleTrack(t); Navigator.pop(context); }),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focus, autofocus: true,
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          _kick();
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.mediaPlayPause) {
            _player.playOrPause();
          } else if (k == LogicalKeyboardKey.arrowRight) {
            _player.seek(_player.state.position + const Duration(seconds: 10));
          } else if (k == LogicalKeyboardKey.arrowLeft) {
            _player.seek(_player.state.position - const Duration(seconds: 10));
          }
        },
        child: GestureDetector(
          onTap: _kick,
          child: Stack(children: [
            Center(child: Video(controller: _video, fit: _fit, aspectRatio: _aspect, controls: NoVideoControls)),
            StreamBuilder<bool>(
              stream: _player.stream.buffering,
              builder: (_, s) => s.data == true ? const Center(child: CircularProgressIndicator()) : const SizedBox(),
            ),
            if (_controls) ...[
              Positioned(top: 0, left: 0, right: 0, child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent])),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: const TextStyle(fontSize: 18)),
                    if (_epg.isNotEmpty) Text('Now: ${_epg.first.title}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                  ])),
                  IconButton(icon: const Icon(Icons.audiotrack), tooltip: 'Audio', onPressed: () => _trackSheet(audio: true)),
                  IconButton(icon: const Icon(Icons.subtitles), tooltip: 'Subtitles', onPressed: () => _trackSheet(audio: false)),
                  TextButton.icon(icon: const Icon(Icons.aspect_ratio), label: Text(_labels[_aspectMode]),
                      onPressed: () => setState(() => _aspectMode = (_aspectMode + 1) % 4)),
                ]),
              )),
              Positioned(bottom: 24, left: 0, right: 0, child: StreamBuilder<bool>(
                stream: _player.stream.playing, initialData: true,
                builder: (_, s) => Center(child: IconButton(iconSize: 56,
                  icon: Icon(s.data! ? Icons.pause_circle : Icons.play_circle), onPressed: _player.playOrPause)),
              )),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hide?.cancel();
    for (final s in _subs) { s.cancel(); }
    _focus.dispose();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
