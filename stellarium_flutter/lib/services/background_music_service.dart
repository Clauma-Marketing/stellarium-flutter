import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Service that manages background music playback across the app.
/// Uses singleton pattern to ensure music persists across all screens.
class BackgroundMusicService {
  BackgroundMusicService._();

  static final BackgroundMusicService instance = BackgroundMusicService._();

  AudioPlayer? _player;
  bool _isInitialized = false;

  /// Initialize and start playing background music.
  /// Music will loop continuously until stopped.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip audio on web platform (not well supported)
    if (kIsWeb) return;

    try {
      _player = AudioPlayer();

      // Load the music from assets
      await _player!.setAsset('assets/meditation-music-322801.mp3');

      // Set to loop continuously
      await _player!.setLoopMode(LoopMode.one);

      // Set a comfortable background volume
      await _player!.setVolume(0.3);

      // Start playing
      await _player!.play();

      _isInitialized = true;
      debugPrint('Background music started');
    } catch (e) {
      debugPrint('Error initializing background music: $e');
    }
  }

  /// Stop the background music.
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  /// Pause the background music.
  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('Error pausing background music: $e');
    }
  }

  /// Resume the background music.
  Future<void> resume() async {
    try {
      await _player?.play();
    } catch (e) {
      debugPrint('Error resuming background music: $e');
    }
  }

  /// Set the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    try {
      await _player?.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Check if music is currently playing.
  bool get isPlaying => _player?.playing ?? false;

  /// Dispose of the audio player resources.
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _isInitialized = false;
  }
}
