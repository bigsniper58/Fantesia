import 'package:flutter/material.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';

class LibrariesScreen extends StatefulWidget {
  const LibrariesScreen({super.key});

  @override
  State<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends State<LibrariesScreen>
    with AutomaticKeepAliveClientMixin {
  List<JfItem> _views = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await JellyfinApi.instance.views();
      if (!mounted) return;
      setState(() {
        _views = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mediatheque')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _views.isEmpty
              ? EmptyState(
                  icon: Icons.folder_off_outlined,
                  message: 'Aucune bibliotheque accessible avec ce compte.',
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Reessayer'),
                  ),
                )
              : ListView.separated(
                  itemCount: _views.length,
                  separatorBuilder: (_, __) => const Divider(indent: 16),
                  itemBuilder: (_, i) {
                    final v = _views[i];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(_iconFor(v), color: C.amber),
                      title: Text(v.name),
                      trailing:
                          const Icon(Icons.chevron_right, color: C.textDim),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LibraryGridScreen(view: v),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _iconFor(JfItem v) {
    final n = v.name.toLowerCase();
    if (n.contains('film')) return Icons.local_movies_outlined;
    if (n.contains('serie') || n.contains('série') || n.contains('tv')) {
      return Icons.live_tv_outlined;
    }
    if (n.contains('music') || n.contains('musique')) {
      return Icons.library_music_outlined;
    }
    return Icons.folder_outlined;
  }
}

/// Grille d'une bibliotheque, chargee par pages au defilement.
class LibraryGridScreen extends StatefulWidget {
  final JfItem view;
  const LibraryGridScreen({super.key, required this.view});

  @override
  State<LibraryGridScreen> createState() => _LibraryGridScreenState();
}

class _LibraryGridScreenState extends State<LibraryGridScreen> {
  final _scroll = ScrollController();
  final List<JfItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  String _sort = 'SortName';

  static const _sorts = {
    'SortName': 'Titre',
    'DateCreated': 'Ajout recent',
    'CommunityRating': 'Mieux notes',
    'PremiereDate': 'Date de sortie',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
              _scroll.position.maxScrollExtent - 600 &&
          !_loadingMore &&
          !_end) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _items.clear();
      _end = false;
    });
    final page = await JellyfinApi.instance
        .libraryItems(widget.view.id, sortBy: _sort)
        .catchError((_) => <JfItem>[]);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loading = false;
      _end = page.length < 60;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final page = await JellyfinApi.instance
        .libraryItems(widget.view.id, startIndex: _items.length, sortBy: _sort)
        .catchError((_) => <JfItem>[]);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loadingMore = false;
      _end = page.length < 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.view.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            color: C.surfaceHigh,
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _load();
            },
            itemBuilder: (_) => _sorts.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'Cette bibliotheque est vide.',
                )
              : GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _items.length) {
                      return const Center(
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return PosterCard(item: _items[i], width: 130);
                  },
                ),
    );
  }
}
