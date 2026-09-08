import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import 'player_screen.dart';
import 'quality_sheet.dart';

class DetailScreen extends StatefulWidget {
  final String itemId;
  const DetailScreen({super.key, required this.itemId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  JfItem? _item;
  List<JfItem> _seasons = [];
  List<JfItem> _episodes = [];
  List<JfItem> _similar = [];
  JfItem? _season;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = JellyfinApi.instance;
    try {
      final item = await api.item(widget.itemId);

      // Un episode ouvert depuis la reprise garde son propre ecran.
      if (item.type == 'Series') {
        final seasons = await api.seasons(item.id);
        List<JfItem> eps = [];
        if (seasons.isNotEmpty) {
          eps = await api.episodes(item.id, seasons.first.id);
        }
        if (!mounted) return;
        setState(() {
          _item = item;
          _seasons = seasons;
          _season = seasons.isNotEmpty ? seasons.first : null;
          _episodes = eps;
          _loading = false;
        });
      } else {
        final similar =
            await api.similar(item.id).catchError((_) => <JfItem>[]);
        if (!mounted) return;
        setState(() {
          _item = item;
          _similar = similar;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _changeSeason(JfItem season) async {
    setState(() {
      _season = season;
      _episodes = [];
    });
    final eps = await JellyfinApi.instance
        .episodes(_item!.seriesId ?? _item!.id, season.id)
        .catchError((_) => <JfItem>[]);
    if (!mounted) return;
    setState(() => _episodes = eps);
  }

  Future<void> _play(JfItem target, {bool resume = true}) async {
    final quality = await showQualitySheet(context, sourceHeight: target.height);
    if (quality == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: target,
          quality: quality,
          startPosition: resume
              ? Duration(
                  milliseconds: target.playbackPositionTicks ~/ 10000)
              : Duration.zero,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.error_outline,
          message: 'Ce titre n\'a pas pu etre charge.',
        ),
      );
    }

    final api = JellyfinApi.instance;
    final backdrop = api.backdropUrl(item);
    final resumable = item.playbackPositionTicks > 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: C.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null)
                    CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover)
                  else
                    Container(color: C.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, C.bg],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  item.favorite ? Icons.favorite : Icons.favorite_border,
                  color: item.favorite ? C.amber : Colors.white,
                ),
                onPressed: () async {
                  await api.setFavorite(item.id, !item.favorite);
                  _load();
                },
              ),
              IconButton(
                icon: Icon(
                  item.played
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: item.played ? C.amber : Colors.white,
                ),
                onPressed: () async {
                  await api.setPlayed(item.id, !item.played);
                  _load();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (item.productionYear != null) '${item.productionYear}',
                      if (item.durationLabel.isNotEmpty) item.durationLabel,
                      if (item.officialRating != null) item.officialRating!,
                      if (item.height != null) '${item.height}p',
                      if (item.communityRating != null)
                        item.communityRating!.toStringAsFixed(1),
                    ].join('   '),
                    style: const TextStyle(color: C.textDim, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  if (item.type != 'Series')
                    FilledButton.icon(
                      onPressed: () => _play(item),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(resumable ? 'Reprendre' : 'Lire'),
                    ),
                  if (item.type != 'Series' && resumable) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _play(item, resume: false),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Reprendre au debut'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: C.text,
                        side: const BorderSide(color: C.surfaceHigh),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  if (item.overview != null &&
                      item.overview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(item.overview!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (item.genres.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.genres
                          .take(6)
                          .map((g) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: C.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(g,
                                    style: const TextStyle(
                                        fontSize: 12, color: C.textDim)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_seasons.isNotEmpty) _seasonPicker(),
          if (_episodes.isNotEmpty) _episodeList(),
          if (_similar.isNotEmpty)
            SliverToBoxAdapter(
              child: MediaRow(title: 'Dans le meme genre', items: _similar),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _seasonPicker() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Row(
          children: [
            Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            DropdownButton<String>(
              value: _season?.id,
              dropdownColor: C.surfaceHigh,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: _seasons
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (id) {
                final s = _seasons.firstWhere((e) => e.id == id);
                _changeSeason(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _episodeList() {
    final api = JellyfinApi.instance;
    return SliverList.separated(
      itemCount: _episodes.length,
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final ep = _episodes[i];
        final thumb = api.backdropUrl(ep, width: 320) ?? api.posterUrl(ep);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 92,
              height: 54,
              child: thumb == null
                  ? Container(color: C.surface)
                  : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
            ),
          ),
          title: Text(
            '${ep.indexNumber ?? ''}. ${ep.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            ep.durationLabel,
            style: const TextStyle(fontSize: 12, color: C.textDim),
          ),
          trailing: Icon(
            ep.played ? Icons.check_circle : Icons.play_arrow,
            color: ep.played ? C.amber : C.textDim,
            size: 20,
          ),
          onTap: () => _play(ep),
        );
      },
    );
  }
}
