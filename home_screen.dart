import 'package:flutter/material.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<JfItem> _resume = [];
  List<JfItem> _nextUp = [];
  List<JfItem> _latest = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final api = JellyfinApi.instance;
    try {
      final results = await Future.wait([
        api.resume(),
        api.nextUp(),
        api.latest(limit: 24),
      ]);
      if (!mounted) return;
      setState(() {
        _resume = results[0];
        _nextUp = results[1];
        _latest = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Le serveur est injoignable. Verifie ta connexion.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final name = JellyfinApi.instance.userName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Fantesia' : 'Bonjour $name'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: C.amber,
        backgroundColor: C.surface,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null
                ? EmptyState(
                    icon: Icons.cloud_off_outlined,
                    message: _error!,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Reessayer'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      MediaRow(
                        title: 'Reprendre',
                        items: _resume,
                        wide: true,
                      ),
                      MediaRow(title: 'Prochains episodes', items: _nextUp),
                      MediaRow(title: 'Derniers ajouts', items: _latest),
                      if (_resume.isEmpty &&
                          _nextUp.isEmpty &&
                          _latest.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: EmptyState(
                            icon: Icons.movie_outlined,
                            message:
                                'Rien a afficher pour l\'instant.\nOuvre la mediatheque pour parcourir le catalogue.',
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
