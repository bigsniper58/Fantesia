import 'dart:async';

import 'package:flutter/material.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<JfItem> _results = [];
  bool _searching = false;
  bool _touched = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _touched = value.isNotEmpty;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String term) async {
    setState(() {
      _searching = true;
      _touched = true;
    });
    final res = await JellyfinApi.instance
        .search(term.trim())
        .catchError((_) => <JfItem>[]);
    if (!mounted) return;
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: false,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Titre, serie, episode',
            prefixIcon: const Icon(Icons.search, color: C.textDim),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: C.textDim),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
        toolbarHeight: 76,
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _results.isEmpty
              ? EmptyState(
                  icon: _touched ? Icons.search_off : Icons.search,
                  message: _touched
                      ? 'Aucun resultat.\nEssaie avec moins de mots.'
                      : 'Cherche un film, une serie ou un episode.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (_, i) =>
                      PosterCard(item: _results[i], width: 130),
                ),
    );
  }
}
