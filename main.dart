import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'api/jellyfin_api.dart';
import 'screens/login_screen.dart';
import 'screens/quality_sheet.dart';
import 'screens/root_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FantesiaApp());
}

class FantesiaApp extends StatelessWidget {
  const FantesiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fantesia',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Boot(),
    );
  }
}

/// Decide au lancement entre la connexion et la mediatheque.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _ready = false;
  bool _session = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final api = JellyfinApi.instance;
    await api.init();
    await QualityPrefs.load();
    final valid = await api.validateSession();
    if (!valid && api.isLoggedIn) await api.logout();
    if (!mounted) return;
    setState(() {
      _session = valid;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _session ? const RootScreen() : const LoginScreen();
  }
}
