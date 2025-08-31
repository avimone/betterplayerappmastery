import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/video_player/video_player.dart';

import 'gadgetspidy_player_mock_controller.dart';
import 'mock_video_player_controller.dart';

class GadgetspidyPlayerTestUtils {
  static const String bugBuckBunnyVideoUrl =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
  static const String forBiggerBlazesUrl =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4";
  static const String elephantDreamStreamUrl =
      "http://cdn.theoplayer.com/video/elephants-dream/playlist.m3u8";

  static GadgetspidyPlayerMockController setupGadgetspidyPlayerMockController(
      {VideoPlayerController? controller}) {
    final mockController =
        GadgetspidyPlayerMockController(const GadgetspidyPlayerConfiguration());
    if (controller != null) {
      mockController.videoPlayerController = controller;
    }
    return mockController;
  }

  static MockVideoPlayerController setupMockVideoPlayerControler() {
    final mockVideoPlayerController = MockVideoPlayerController();
    mockVideoPlayerController
        .setNetworkDataSource(GadgetspidyPlayerTestUtils.forBiggerBlazesUrl);
    return mockVideoPlayerController;
  }
}
