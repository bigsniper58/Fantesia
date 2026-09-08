import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/jellyfin_api.dart';
import '../api/models.dart';
import '../theme.dart';
import 'quality_sheet.dart';

class PlayerScreen extends StatefulWidget {
  final JfItem item;
  final Quality quality;
  final Duration startPosition;

  const PlayerScreen({
    super.key,
    required this.item,
    required this.quality,
    this.startPosition = Duration.zero,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  PlaybackSource? _source;
  late Quality _quality;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  bool _controls = true;
  String? _error;

  Timer? _progressTimer;
  Timer? _hideTimer;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _quality = widget.quality;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _subs.addAll([
      _player.stream.position.listen((p) => setState(() => _position = p)),
      _player.stream.duration.listen((d) => setState(() => _duration = d)),
      _player.stream.playing.listen((p) => setState(() => _playing = p)),
      _player.stream.buffering.listen((b) => setState(() => _buffering = b)),
      _player.stream.error.listen((e) {
        if (mounted) setState(() => _error = e);
      }),
    ]);

    _open(widget.startPosition);
    _scheduleHide();
  }

  Future<void> _open(Duration start) async {
    setState(() {
      _buffering = true;
      _error = null;
    });
    final api = JellyfinApi.instance;
    try {
      final source = await api.playbackInfo(widget.item.id, _quality);
      _source = source;
      final url = api.streamUrl(widget.item.id, source, _quality);

      await _player.open(Media(url, start: start), play: true);
      await api.reportStart(widget.item.id, source, start);

      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_source != null) {
          api.reportProgress(
              widget.item.id, _source!, _position, !_playing);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Change la definition sans perdre la position en cours.
  Future<void> _switchQuality() async {
    final q = await showQualitySheet(
      context,
      sourceHeight: widget.item.height,
      force: true,
    );
    if (q == null || q.label == _quality.label) return;
    final at = _position;
    setState(() => _quality = q);
    await _player.stop();
    await _open(at);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  void _seekBy(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _player.seek(target < Duration.zero ? Duration.zero : target);
    _scheduleHide();
  }

  Future<void> _pickTrack(bool audio) async {
    final tracks = audio
        ? _player.state.tracks.audio
        : _player.state.tracks.subtitle;

    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: C.surface,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tracks.length,
          itemBuilder: (_, i) {
            final t = tracks[i];
            final label = t.title ?? t.language ?? t.id;
            return ListTile(
              title: Text(label, style: const TextStyle(fontSize: 14)),
              onTap: () => Navigator.of(ctx).pop(i),
            );
          },
        ),
      ),
    );
    if (chosen == null) return;
    if (audio) {
      await _player.setAudioTrack(tracks[chosen]);
    } else {
      await _player.setSubtitleTrack(tracks[chosen]);
    }
  }

  @override
  void dispose() {
    if (_source != null) {
      JellyfinApi.instance
          .reportStop(widget.item.id, _source!, _position);
    }
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (d) {
          final half = MediaQuery.of(context).size.width / 2;
          _seekBy(d.globalPosition.dx < half ? -10 : 10);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),
            if (_error != null) _errorLayer(),
            if (_buffering && _error == null)
              const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            if (_controls && _error == null) _controlsLayer(),
          ],
        ),
      ),
    );
  }

  Widget _errorLayer() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: C.danger, size: 40),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.text, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () => _open(_position),
                child: const Text('Reessayer'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlsLayer() {
    final max = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.black87],
          stops: [0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: _switchQuality,
                  icon: const Icon(Icons.hd_outlined,
                      color: Colors.white, size: 20),
                  label: Text(
                    _quality.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.audiotrack, color: Colors.white),
                  onPressed: () => _pickTrack(true),
                ),
                IconButton(
                  icon: const Icon(Icons.subtitles_outlined,
                      color: Colors.white),
                  onPressed: () => _pickTrack(false),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 38,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () => _seekBy(-10),
                ),
                const SizedBox(width: 26),
                IconButton(
                  iconSize: 62,
                  icon: Icon(
                    _playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _player.playOrPause();
                    _scheduleHide();
                  },
                ),
                const SizedBox(width: 26),
                IconButton(
                  iconSize: 38,
                  icon: const Icon(Icons.forward_30, color: Colors.white),
                  onPressed: () => _seekBy(30),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(_fmt(_position),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: C.amber,
                        thumbColor: C.amber,
                        inactiveTrackColor: Colors.white24,
                      ),
                      child: Slider(
                        value: max > 0 ? value : 0,
                        max: max > 0 ? max : 1,
                        onChanged: (v) => setState(
                          () => _position =
                              Duration(milliseconds: v.toInt()),
                        ),
                        onChangeEnd: (v) {
                          _player.seek(Duration(milliseconds: v.toInt()));
                          _scheduleHide();
                        },
                      ),
                    ),
                  ),
                  Text(_fmt(_duration),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
