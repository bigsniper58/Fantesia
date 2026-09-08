import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

/// Acces au serveur Jellyfin de Fantesia.
///
/// L'adresse du serveur vient de [AppConfig] et n'est jamais demandee a
/// l'utilisateur. Seuls le nom d'utilisateur et le mot de passe le sont.
class JellyfinApi {
  JellyfinApi._();
  static final JellyfinApi instance = JellyfinApi._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _client = http.Client();

  String? _token;
  String? _userId;
  String? _userName;
  String? _deviceId;
  String _deviceName = 'Android';

  String? get userId => _userId;
  String? get userName => _userName;
  bool get isLoggedIn => _token != null && _userId != null;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.jellyfinUrl}$path').replace(queryParameters: query);

  /// En-tete d'autorisation au format attendu par Jellyfin 10.11 et suivants.
  /// L'ancien en-tete X-Emby-Authorization est abandonne et casse la connexion
  /// sur les versions recentes.
  Map<String, String> get _headers {
    final parts = [
      'Client="${AppConfig.clientName}"',
      'Device="$_deviceName"',
      'DeviceId="${_deviceId ?? 'fantesia-unknown'}"',
      'Version="${AppConfig.clientVersion}"',
      if (_token != null) 'Token="$_token"',
    ];
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'MediaBrowser ${parts.join(', ')}',
    };
  }

  /// A appeler au demarrage : prepare l'identifiant d'appareil et recharge la
  /// session precedente si elle existe.
  Future<void> init() async {
    _deviceId = await _storage.read(key: 'deviceId');
    if (_deviceId == null) {
      final rnd = Random.secure();
      _deviceId = List.generate(16, (_) => rnd.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await _storage.write(key: 'deviceId', value: _deviceId);
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceName = '${info.brand} ${info.model}';
    } catch (_) {
      // Nom generique si l'info n'est pas disponible.
    }

    _token = await _storage.read(key: 'token');
    _userId = await _storage.read(key: 'userId');
    _userName = await _storage.read(key: 'userName');
  }

  Future<void> login(String username, String password) async {
    final res = await _client.post(
      _uri('/Users/AuthenticateByName'),
      headers: _headers,
      body: jsonEncode({'Username': username, 'Pw': password}),
    );

    if (res.statusCode == 401) {
      throw Exception('Nom d\'utilisateur ou mot de passe incorrect.');
    }
    if (res.statusCode >= 400) {
      throw Exception('Le serveur a repondu ${res.statusCode}.');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['AccessToken'] as String;
    _userId = (data['User'] as Map<String, dynamic>)['Id'] as String;
    _userName = (data['User'] as Map<String, dynamic>)['Name'] as String;

    await _storage.write(key: 'token', value: _token);
    await _storage.write(key: 'userId', value: _userId);
    await _storage.write(key: 'userName', value: _userName);
  }

  Future<void> logout() async {
    try {
      await _client.post(_uri('/Sessions/Logout'), headers: _headers);
    } catch (_) {
      // La session locale est effacee meme si le serveur est injoignable.
    }
    _token = null;
    _userId = null;
    _userName = null;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'userId');
    await _storage.delete(key: 'userName');
  }

  /// Verifie que le jeton stocke est toujours valide.
  Future<bool> validateSession() async {
    if (!isLoggedIn) return false;
    try {
      final res = await _client.get(_uri('/Users/Me'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<JfItem>> _items(String path, Map<String, String> query) async {
    final res = await _client.get(_uri(path, query), headers: _headers);
    if (res.statusCode >= 400) {
      throw Exception('Erreur ${res.statusCode} sur $path');
    }
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['Items'] as List? ?? const []);
    return list
        .map((e) => JfItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static const _fields =
      'PrimaryImageAspectRatio,Overview,Genres,BackdropImageTags,ParentBackdropImageTags,ParentBackdropItemId';

  /// Les bibliotheques de l'utilisateur (Films, Series, Musique...).
  Future<List<JfItem>> views() =>
      _items('/UserViews', {'userId': _userId!});

  /// Reprendre la lecture.
  Future<List<JfItem>> resume() => _items('/UserItems/Resume', {
        'userId': _userId!,
        'limit': '20',
        'mediaTypes': 'Video',
        'fields': _fields,
        'enableImageTypes': 'Primary,Backdrop,Thumb',
      });

  /// Prochains episodes des series commencees.
  Future<List<JfItem>> nextUp() => _items('/Shows/NextUp', {
        'userId': _userId!,
        'limit': '20',
        'fields': _fields,
      });

  /// Derniers ajouts, toutes bibliotheques ou une seule.
  Future<List<JfItem>> latest({String? parentId, int limit = 20}) =>
      _items('/Items/Latest', {
        'userId': _userId!,
        'limit': '$limit',
        'fields': _fields,
        if (parentId != null) 'parentId': parentId,
      });

  /// Contenu d'une bibliotheque, trie par titre.
  Future<List<JfItem>> libraryItems(
    String parentId, {
    int startIndex = 0,
    int limit = 60,
    String sortBy = 'SortName',
  }) =>
      _items('/Items', {
        'userId': _userId!,
        'parentId': parentId,
        'recursive': 'true',
        'includeItemTypes': 'Movie,Series',
        'sortBy': sortBy,
        'sortOrder': sortBy == 'SortName' ? 'Ascending' : 'Descending',
        'startIndex': '$startIndex',
        'limit': '$limit',
        'fields': _fields,
      });

  Future<List<JfItem>> search(String term) => _items('/Items', {
        'userId': _userId!,
        'searchTerm': term,
        'recursive': 'true',
        'includeItemTypes': 'Movie,Series,Episode',
        'limit': '50',
        'fields': _fields,
      });

  Future<JfItem> item(String itemId) async {
    final res = await _client.get(
      _uri('/Items/$itemId', {'userId': _userId!, 'fields': _fields}),
      headers: _headers,
    );
    if (res.statusCode >= 400) {
      throw Exception('Erreur ${res.statusCode} sur l\'element $itemId');
    }
    return JfItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<JfItem>> seasons(String seriesId) =>
      _items('/Shows/$seriesId/Seasons', {
        'userId': _userId!,
        'fields': _fields,
      });

  Future<List<JfItem>> episodes(String seriesId, String seasonId) =>
      _items('/Shows/$seriesId/Episodes', {
        'userId': _userId!,
        'seasonId': seasonId,
        'fields': _fields,
      });

  Future<List<JfItem>> similar(String itemId) =>
      _items('/Items/$itemId/Similar', {
        'userId': _userId!,
        'limit': '12',
        'fields': _fields,
      });

  // --- Images -------------------------------------------------------------

  String? posterUrl(JfItem item, {int height = 480}) {
    if (item.imageTag == null) return null;
    return '${AppConfig.jellyfinUrl}/Items/${item.id}/Images/Primary'
        '?maxHeight=$height&tag=${item.imageTag}&quality=90';
  }

  String? backdropUrl(JfItem item, {int width = 1280}) {
    if (item.backdropTag != null) {
      return '${AppConfig.jellyfinUrl}/Items/${item.id}/Images/Backdrop/0'
          '?maxWidth=$width&tag=${item.backdropTag}&quality=85';
    }
    if (item.parentBackdropItemId != null && item.parentBackdropTag != null) {
      return '${AppConfig.jellyfinUrl}/Items/${item.parentBackdropItemId}'
          '/Images/Backdrop/0?maxWidth=$width'
          '&tag=${item.parentBackdropTag}&quality=85';
    }
    return null;
  }

  // --- Lecture ------------------------------------------------------------

  /// Demande au serveur comment lire l'element avec la qualite choisie.
  Future<PlaybackSource> playbackInfo(String itemId, Quality quality) async {
    final body = <String, dynamic>{
      'UserId': _userId,
      'EnableDirectPlay': quality.isDirect,
      'EnableDirectStream': true,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': quality.isDirect,
      'AllowAudioStreamCopy': true,
      'AutoOpenLiveStream': true,
      if (quality.maxBitrate != null) 'MaxStreamingBitrate': quality.maxBitrate,
    };

    final res = await _client.post(
      _uri('/Items/$itemId/PlaybackInfo', {'userId': _userId!}),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('Lecture impossible (erreur ${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final sources = (data['MediaSources'] as List?) ?? const [];
    if (sources.isEmpty) {
      throw Exception('Aucune source de lecture disponible pour ce titre.');
    }
    final src = sources.first as Map<String, dynamic>;

    return PlaybackSource(
      mediaSourceId: (src['Id'] ?? itemId) as String,
      playSessionId: (data['PlaySessionId'] ?? '') as String,
      supportsDirectPlay: (src['SupportsDirectPlay'] as bool?) ?? false,
      transcodingUrl: src['TranscodingUrl'] as String?,
    );
  }

  /// URL a donner au lecteur.
  ///
  /// En qualite automatique on demande le fichier tel quel : aucun transcodage,
  /// donc aucune charge sur le serveur. Des qu'une definition est choisie, on
  /// passe par HLS en fixant a la fois la hauteur et un debit coherent.
  String streamUrl(String itemId, PlaybackSource source, Quality quality) {
    if (quality.isDirect) {
      return '${AppConfig.jellyfinUrl}/Videos/$itemId/stream'
          '?static=true'
          '&mediaSourceId=${source.mediaSourceId}'
          '&playSessionId=${source.playSessionId}'
          '&api_key=$_token';
    }

    final params = {
      'mediaSourceId': source.mediaSourceId,
      'playSessionId': source.playSessionId,
      'api_key': _token!,
      'videoCodec': 'h264',
      'audioCodec': 'aac',
      'maxHeight': '${quality.maxHeight}',
      'maxWidth': '${(quality.maxHeight! * 16 / 9).round()}',
      'videoBitRate': '${quality.maxBitrate}',
      'audioBitRate': '192000',
      'maxAudioChannels': '2',
      'transcodingMaxAudioChannels': '2',
      'segmentContainer': 'ts',
      'minSegments': '1',
      'breakOnNonKeyFrames': 'true',
      'requireAvc': 'true',
      'subtitleMethod': 'Encode',
    };
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '${AppConfig.jellyfinUrl}/Videos/$itemId/master.m3u8?$qs';
  }

  // --- Etat de lecture ----------------------------------------------------

  Future<void> reportStart(
      String itemId, PlaybackSource src, Duration position) async {
    await _post('/Sessions/Playing', {
      'ItemId': itemId,
      'MediaSourceId': src.mediaSourceId,
      'PlaySessionId': src.playSessionId,
      'PositionTicks': position.inMilliseconds * 10000,
      'IsPaused': false,
      'CanSeek': true,
    });
  }

  Future<void> reportProgress(
      String itemId, PlaybackSource src, Duration position, bool paused) async {
    await _post('/Sessions/Playing/Progress', {
      'ItemId': itemId,
      'MediaSourceId': src.mediaSourceId,
      'PlaySessionId': src.playSessionId,
      'PositionTicks': position.inMilliseconds * 10000,
      'IsPaused': paused,
      'CanSeek': true,
    });
  }

  Future<void> reportStop(
      String itemId, PlaybackSource src, Duration position) async {
    await _post('/Sessions/Playing/Stopped', {
      'ItemId': itemId,
      'MediaSourceId': src.mediaSourceId,
      'PlaySessionId': src.playSessionId,
      'PositionTicks': position.inMilliseconds * 10000,
    });
  }

  Future<void> setFavorite(String itemId, bool value) async {
    final uri = _uri('/UserFavoriteItems/$itemId', {'userId': _userId!});
    if (value) {
      await _client.post(uri, headers: _headers);
    } else {
      await _client.delete(uri, headers: _headers);
    }
  }

  Future<void> setPlayed(String itemId, bool value) async {
    final uri = _uri('/UserPlayedItems/$itemId', {'userId': _userId!});
    if (value) {
      await _client.post(uri, headers: _headers);
    } else {
      await _client.delete(uri, headers: _headers);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _client.post(_uri(path), headers: _headers, body: jsonEncode(body));
    } catch (_) {
      // Le suivi de progression ne doit jamais interrompre la lecture.
    }
  }
}
