/// Un element de la mediatheque : film, serie, saison, episode, collection.
class JfItem {
  final String id;
  final String name;
  final String type;
  final String? seriesId;
  final String? seriesName;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? overview;
  final int? productionYear;
  final double? communityRating;
  final String? officialRating;
  final int? runTimeTicks;
  final String? imageTag;
  final String? backdropTag;
  final String? parentBackdropItemId;
  final String? parentBackdropTag;
  final List<String> genres;
  final double playedPercentage;
  final int playbackPositionTicks;
  final bool played;
  final bool favorite;
  final int? height;

  JfItem({
    required this.id,
    required this.name,
    required this.type,
    this.seriesId,
    this.seriesName,
    this.indexNumber,
    this.parentIndexNumber,
    this.overview,
    this.productionYear,
    this.communityRating,
    this.officialRating,
    this.runTimeTicks,
    this.imageTag,
    this.backdropTag,
    this.parentBackdropItemId,
    this.parentBackdropTag,
    this.genres = const [],
    this.playedPercentage = 0,
    this.playbackPositionTicks = 0,
    this.played = false,
    this.favorite = false,
    this.height,
  });

  factory JfItem.fromJson(Map<String, dynamic> j) {
    final userData = (j['UserData'] as Map<String, dynamic>?) ?? const {};
    final imageTags = (j['ImageTags'] as Map<String, dynamic>?) ?? const {};
    final backdrops = (j['BackdropImageTags'] as List?) ?? const [];
    final parentBackdrops =
        (j['ParentBackdropImageTags'] as List?) ?? const [];

    int? sourceHeight;
    final sources = j['MediaSources'] as List?;
    if (sources != null && sources.isNotEmpty) {
      final streams = (sources.first['MediaStreams'] as List?) ?? const [];
      for (final s in streams) {
        if (s['Type'] == 'Video' && s['Height'] != null) {
          sourceHeight = (s['Height'] as num).toInt();
          break;
        }
      }
    }

    return JfItem(
      id: j['Id'] as String,
      name: (j['Name'] ?? '') as String,
      type: (j['Type'] ?? '') as String,
      seriesId: j['SeriesId'] as String?,
      seriesName: j['SeriesName'] as String?,
      indexNumber: (j['IndexNumber'] as num?)?.toInt(),
      parentIndexNumber: (j['ParentIndexNumber'] as num?)?.toInt(),
      overview: j['Overview'] as String?,
      productionYear: (j['ProductionYear'] as num?)?.toInt(),
      communityRating: (j['CommunityRating'] as num?)?.toDouble(),
      officialRating: j['OfficialRating'] as String?,
      runTimeTicks: (j['RunTimeTicks'] as num?)?.toInt(),
      imageTag: imageTags['Primary'] as String?,
      backdropTag: backdrops.isNotEmpty ? backdrops.first as String : null,
      parentBackdropItemId: j['ParentBackdropItemId'] as String?,
      parentBackdropTag:
          parentBackdrops.isNotEmpty ? parentBackdrops.first as String : null,
      genres: ((j['Genres'] as List?) ?? const []).cast<String>(),
      playedPercentage:
          (userData['PlayedPercentage'] as num?)?.toDouble() ?? 0,
      playbackPositionTicks:
          (userData['PlaybackPositionTicks'] as num?)?.toInt() ?? 0,
      played: (userData['Played'] as bool?) ?? false,
      favorite: (userData['IsFavorite'] as bool?) ?? false,
      height: sourceHeight,
    );
  }

  bool get isFolder =>
      type == 'Series' || type == 'Season' || type == 'BoxSet';

  bool get isPlayable => type == 'Movie' || type == 'Episode' || type == 'Video';

  /// Titre affiche dans les listes : "S01E04 - Titre" pour un episode.
  String get displayTitle {
    if (type == 'Episode' && indexNumber != null) {
      final s = (parentIndexNumber ?? 0).toString().padLeft(2, '0');
      final e = indexNumber.toString().padLeft(2, '0');
      return 'S${s}E$e - $name';
    }
    return name;
  }

  String get durationLabel {
    if (runTimeTicks == null || runTimeTicks == 0) return '';
    final minutes = (runTimeTicks! / 600000000).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

/// Une option de qualite proposee a l'utilisateur.
///
/// Jellyfin raisonne en debit ; l'application raisonne en definition. Chaque
/// palier fixe donc une hauteur maximale et lui associe un debit coherent,
/// sinon le serveur choisit lui-meme une resolution en fonction du debit seul.
class Quality {
  final String label;
  final String hint;
  final int? maxHeight;
  final int? maxBitrate;

  const Quality(this.label, this.hint, this.maxHeight, this.maxBitrate);

  bool get isDirect => maxHeight == null;

  static const List<Quality> all = [
    Quality('Automatique', 'Qualite d\'origine, sans reencodage', null, null),
    Quality('4K', '2160p, environ 40 Mb/s', 2160, 40000000),
    Quality('1440p', 'environ 16 Mb/s', 1440, 16000000),
    Quality('1080p', 'environ 8 Mb/s', 1080, 8000000),
    Quality('720p', 'environ 4 Mb/s', 720, 4000000),
    Quality('480p', 'environ 1,5 Mb/s', 480, 1500000),
    Quality('360p', 'connexion faible, environ 800 kb/s', 360, 800000),
  ];
}

/// Resultat d'un appel PlaybackInfo : de quoi construire l'URL de lecture.
class PlaybackSource {
  final String mediaSourceId;
  final String playSessionId;
  final bool supportsDirectPlay;
  final String? transcodingUrl;

  PlaybackSource({
    required this.mediaSourceId,
    required this.playSessionId,
    required this.supportsDirectPlay,
    this.transcodingUrl,
  });
}
