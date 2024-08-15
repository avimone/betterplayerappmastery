import 'package:better_player/better_player.dart';
import 'package:examplenew/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart';

class HlsTracksPage extends StatefulWidget {
  @override
  _HlsTracksPageState createState() => _HlsTracksPageState();
}

class _HlsTracksPageState extends State<HlsTracksPage> {
  late BetterPlayerController _betterPlayerController;
  GlobalKey _betterPlayerKey = GlobalKey();
  final pip = Floating();
  bool isPipAvailable = false; // Variable to track PiP availability status
  @override
  void initState() {
    ///default landscape
    /*  SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]); */
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
            aspectRatio: 16 / 9,
            fit: BoxFit.contain,
            fullScreenByDefault: true,
            autoDetectFullscreenAspectRatio: true,
            pip: () async {
              final statusAfterEnabling = await pip.enable(ImmediatePiP());
            },
            controlsConfiguration: BetterPlayerControlsConfiguration(
              overflowModalColor: Colors.black,
              overflowModalTextColor: Colors.white,
              overflowMenuIconsColor: Colors.white,
              loadingColor: Colors.amber,
            ));
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      "https://player.vimeo.com/external/955785077.m3u8?s=6b46c3d85e93f772b1c1d155cca22af1b0512868&oauth2_token_id=1698974288",
      useAsmsSubtitles: true,
      videoFormat: BetterPlayerVideoFormat.hls,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    _betterPlayerController?.setBetterPlayerGlobalKey(_betterPlayerKey);

    _betterPlayerController?.enablePictureInPicture(_betterPlayerKey);
    pipCheck();
    super.initState();
  }

  void pipCheck() async {
    final canUsePiP = await pip.isPipAvailable;
    if (canUsePiP) {
      final statusAfterEnabling = await pip.enable(OnLeavePiP());
    }
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PiPSwitcher(
      childWhenDisabled: Scaffold(
        appBar: AppBar(
          title: Text("HLS tracks"),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Player with HLS stream which loads tracks from HLS."
                " You can choose tracks by using overflow menu (3 dots in right corner).",
                style: TextStyle(fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _betterPlayerController),
            )
          ],
        ),
      ),
      childWhenEnabled: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: _betterPlayerController),
      ),
    );
  }
}
