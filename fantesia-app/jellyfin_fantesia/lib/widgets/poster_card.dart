import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../screens/detail_screen.dart';
import '../theme.dart';

/// Une jaquette cliquable. L'affiche porte l'ecran : le cadre reste minimal.
class PosterCard extends StatelessWidget {
  final JfItem item;
  final double width;

  /// Format paysage pour les episodes et la reprise de lecture.
  final bool wide;

  const PosterCard({
    super.key,
    required this.item,
    this.width = 116,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final api = JellyfinApi.instance;
    final url = wide
        ? (api.backdropUrl(item, width: 640) ?? api.posterUrl(item))
        : api.posterUrl(item);
    final w = wide ? width * 1.75 : width;
    final h = wide ? width * 0.98 : width * 1.5;
    final progress = item.playedPercentage / 100;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(itemId: item.id)),
      ),
      child: SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    width: w,
                    height: h,
                    color: C.surface,
                    child: url == null
                        ? const Icon(Icons.movie_outlined,
                            color: C.textDim, size: 32)
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: C.textDim),
                          ),
                  ),
                  if (progress > 0.01 && progress < 0.98)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.black54,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(C.amber),
                      ),
                    ),
                  if (item.played)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: C.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 12, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wide && item.type == 'Episode'
                  ? (item.seriesName ?? item.name)
                  : item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              _subtitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: C.textDim),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (item.type == 'Episode' && item.indexNumber != null) {
      final s = (item.parentIndexNumber ?? 0).toString().padLeft(2, '0');
      final e = item.indexNumber.toString().padLeft(2, '0');
      return 'S${s}E$e';
    }
    return item.productionYear?.toString() ?? '';
  }
}

/// Une rangee horizontale titree.
class MediaRow extends StatelessWidget {
  final String title;
  final List<JfItem> items;
  final bool wide;

  const MediaRow({
    super.key,
    required this.title,
    required this.items,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: wide ? 152 : 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => PosterCard(item: items[i], wide: wide),
          ),
        ),
      ],
    );
  }
}

/// Message affiche quand une liste est vide : dit quoi faire, pas juste que
/// c'est vide.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: C.textDim),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.textDim, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
