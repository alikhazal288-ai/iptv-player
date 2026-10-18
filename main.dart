import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

const kBg = Color(0xFF121212);
const kAccent = Color(0xFF00E5FF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: IptvApp()));
}

class IptvApp extends ConsumerStatefulWidget {
  const IptvApp({super.key});
  @override
  ConsumerState<IptvApp> createState() => _IptvAppState();
}

class _IptvAppState extends ConsumerState<IptvApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Shortcuts(
      // Make the D-pad "select" button activate focused widgets (Android TV)
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent()},
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kAccent, surface: Color(0xFF1C1C1E)),
          focusColor: kAccent.withOpacity(.3),
        ),
        home: session.valueOrNull != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
