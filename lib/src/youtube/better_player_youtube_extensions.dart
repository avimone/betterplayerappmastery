// 3. Create extension methods: lib/src/youtube/better_player_youtube_extensions.dart

import 'package:better_player/src/youtube/better_player_youtube_types.dart';

import '../configuration/better_player_data_source.dart';
import 'better_player_youtube_extractor.dart';

extension BetterPlayerYouTubeExtensions on BetterPlayerDataSource {
  /// Factory constructor for YouTube data sources
  static Future<BetterPlayerDataSource> youtube(
    String youtubeUrl, {
    BetterPlayerYouTubeQuality quality = BetterPlayerYouTubeQuality.medium,
    bool useCache = true,
    Duration cacheDuration = const Duration(hours: 1),
  }) async {
    return BetterPlayerYouTubeExtractor.extractYouTubeDataSource(
      youtubeUrl,
      quality: quality,
      useCache: useCache,
      cacheDuration: cacheDuration,
    );
  }
}
