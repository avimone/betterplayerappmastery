import '../youtube/better_player_youtube_extractor.dart';
import '../youtube/better_player_youtube_types.dart';
import '../configuration/better_player_event.dart';
import '../configuration/better_player_event_type.dart';
import 'better_player_controller.dart';

extension BetterPlayerControllerYouTube on BetterPlayerController {
  /// Setup data source from YouTube URL
  Future<void> setupYouTubeDataSource(
    String youtubeUrl, {
    BetterPlayerYouTubeQuality quality = BetterPlayerYouTubeQuality.medium,
    bool autoPlay = true,
    bool useCache = true,
  }) async {
    try {
      // Show loading indicator
      postEvent(BetterPlayerEvent(BetterPlayerEventType.setupDataSource));

      // Extract YouTube data source
      final dataSource =
          await BetterPlayerYouTubeExtractor.extractYouTubeDataSource(
        youtubeUrl,
        quality: quality,
        useCache: useCache,
      );

      // Setup the data source
      await setupDataSource(dataSource);

      if (autoPlay) {
        await play();
      }
    } catch (e) {
      // Handle YouTube extraction errors
      postEvent(BetterPlayerEvent(
        BetterPlayerEventType.exception,
        parameters: {'error': 'YouTube extraction failed: $e'},
      ));
      rethrow;
    }
  }

  /// Get available YouTube video qualities
  Future<List<BetterPlayerYouTubeQualityInfo>> getYouTubeQualities(
      String youtubeUrl) async {
    return BetterPlayerYouTubeExtractor.getAvailableQualities(youtubeUrl);
  }

  /// Switch YouTube video quality
  Future<void> changeYouTubeQuality(
    String youtubeUrl,
    BetterPlayerYouTubeQuality newQuality,
  ) async {
    final currentPosition = await videoPlayerController?.position;
    final wasPlaying = isPlaying() ?? false;

    await setupYouTubeDataSource(
      youtubeUrl,
      quality: newQuality,
      autoPlay: false,
    );

    if (currentPosition != null) {
      await seekTo(currentPosition);
    }

    if (wasPlaying) {
      await play();
    }
  }
}
