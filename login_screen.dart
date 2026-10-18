import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _tab = 0; // 0 = Xtream, 1 = M3U
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _m3u = TextEditingController();
  final _mac = TextEditingController(text: '00:1A:79:');
  String? _filePath;

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r?.files.single.path != null) {
      setState(() { _filePath = r!.files.single.path; _m3u.text = r.files.single.name; });
    }
  }

  void _submit() {
    final c = _tab == 0
        ? Credentials(kind: LoginKind.xtream, server: _server.text, username: _user.text, password: _pass.text)
        : _tab == 2
        ? Credentials(kind: LoginKind.stalker, server: _server.text, mac: _mac.text)
        : _filePath != null
            ? Credentials(kind: LoginKind.m3uFile, m3uSource: _filePath!)
            : Credentials(kind: LoginKind.m3uUrl, m3uSource: _m3u.text.trim());
    ref.read(sessionProvider.notifier).login(c);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.live_tv_rounded, size: 56, color: kAccent),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Xtream Codes')),
                    ButtonSegment(value: 1, label: Text('M3U')),
                    ButtonSegment(value: 2, label: Text('Stalker')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 20),
                if (_tab == 0) ...[
                  _field(_server, 'Server URL (http://host:port)', Icons.dns),
                  _field(_user, 'Username', Icons.person),
                  _field(_pass, 'Password', Icons.lock, obscure: true),
                ] else if (_tab == 2) ...[
                  _field(_server, 'Portal URL (http://host/c/)', Icons.dns),
                  _field(_mac, 'MAC address (00:1A:79:XX:XX:XX)', Icons.memory),
                ] else ...[
                  _field(_m3u, 'M3U URL', Icons.link, onChanged: (_) => _filePath = null),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload local .m3u file'),
                  ),
                ],
                const SizedBox(height: 20),
                s.isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
                          onPressed: _submit,
                          child: const Text('Connect'),
                        ),
                      ),
                if (s.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('${s.error}', style: const TextStyle(color: Colors.redAccent)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
          {bool obscure = false, ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c, obscureText: obscure, onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
