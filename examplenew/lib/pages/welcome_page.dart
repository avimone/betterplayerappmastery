import 'dart:io';

import 'package:examplenew/constants.dart';
import 'package:examplenew/pages/auto_fullscreen_orientation_page.dart';
import 'package:examplenew/pages/basic_player_page.dart';
import 'package:examplenew/pages/cache_page.dart';
import 'package:examplenew/pages/clearkey_page.dart';
import 'package:examplenew/pages/controller_controls_page.dart';
import 'package:examplenew/pages/controls_always_visible_page.dart';
import 'package:examplenew/pages/controls_configuration_page.dart';
import 'package:examplenew/pages/custom_controls/change_player_theme_page.dart';
import 'package:examplenew/pages/dash_page.dart';
import 'package:examplenew/pages/drm_page.dart';
import 'package:examplenew/pages/event_listener_page.dart';
import 'package:examplenew/pages/fade_placeholder_page.dart';
import 'package:examplenew/pages/hls_audio_page.dart';
import 'package:examplenew/pages/hls_subtitles_page.dart';
import 'package:examplenew/pages/hls_tracks_page.dart';
import 'package:examplenew/pages/memory_player_page.dart';
import 'package:examplenew/pages/normal_player_page.dart';
import 'package:examplenew/pages/notification_player_page.dart';
import 'package:examplenew/pages/overridden_aspect_ratio_page.dart';
import 'package:examplenew/pages/overriden_duration_page.dart';
import 'package:examplenew/pages/placeholder_until_play_page.dart';
import 'package:examplenew/pages/playlist_page.dart';
import 'package:examplenew/pages/resolutions_page.dart';
import 'package:examplenew/pages/reusable_video_list/reusable_video_list_page.dart';
import 'package:examplenew/pages/rotation_and_fit_page.dart';
import 'package:examplenew/pages/subtitles_page.dart';
import 'package:examplenew/pages/video_list/video_list_page.dart';
import 'package:examplenew/pages/picture_in_picture_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    _saveAssetSubtitleToFile();
    _saveAssetVideoToFile();
    _saveAssetEncryptVideoToFile();
    _saveLogoToFile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Better Player examplenew"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Image.asset(
              "assets/logo.png",
              height: 200,
              width: 200,
            ),
            Text(
              "Welcome to Better Player examplenew app. Click on any element below to see examplenew.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...buildexamplenewElementWidgets()
          ],
        ),
      ),
    );
  }

  List<Widget> buildexamplenewElementWidgets() {
    return [
      _buildexamplenewElementWidget("Basic player", () {
        _navigateToPage(BasicPlayerPage());
      }),
      _buildexamplenewElementWidget("Normal player", () {
        _navigateToPage(NormalPlayerPage());
      }),
      _buildexamplenewElementWidget("Controls configuration", () {
        _navigateToPage(ControlsConfigurationPage());
      }),
      _buildexamplenewElementWidget("Event listener", () {
        _navigateToPage(EventListenerPage());
      }),
      _buildexamplenewElementWidget("Subtitles", () {
        _navigateToPage(SubtitlesPage());
      }),
      _buildexamplenewElementWidget("Resolutions", () {
        _navigateToPage(ResolutionsPage());
      }),
      _buildexamplenewElementWidget("HLS subtitles", () {
        _navigateToPage(HlsSubtitlesPage());
      }),
      _buildexamplenewElementWidget("HLS tracks", () {
        _navigateToPage(HlsTracksPage());
      }),
      _buildexamplenewElementWidget("HLS Audio", () {
        _navigateToPage(HlsAudioPage());
      }),
      _buildexamplenewElementWidget("Cache", () {
        _navigateToPage(CachePage());
      }),
      _buildexamplenewElementWidget("Playlist", () {
        _navigateToPage(PlaylistPage());
      }),
      _buildexamplenewElementWidget("Video in list", () {
        _navigateToPage(VideoListPage());
      }),
      _buildexamplenewElementWidget("Rotation and fit", () {
        _navigateToPage(RotationAndFitPage());
      }),
      _buildexamplenewElementWidget("Memory player", () {
        _navigateToPage(MemoryPlayerPage());
      }),
      _buildexamplenewElementWidget("Controller controls", () {
        _navigateToPage(ControllerControlsPage());
      }),
      _buildexamplenewElementWidget("Auto fullscreen orientation", () {
        _navigateToPage(AutoFullscreenOrientationPage());
      }),
      _buildexamplenewElementWidget("Overridden aspect ratio", () {
        _navigateToPage(OverriddenAspectRatioPage());
      }),
      _buildexamplenewElementWidget("Notifications player", () {
        _navigateToPage(NotificationPlayerPage());
      }),
      _buildexamplenewElementWidget("Reusable video list", () {
        _navigateToPage(ReusableVideoListPage());
      }),
      _buildexamplenewElementWidget("Fade placeholder", () {
        _navigateToPage(FadePlaceholderPage());
      }),
      _buildexamplenewElementWidget("Placeholder until play", () {
        _navigateToPage(PlaceholderUntilPlayPage());
      }),
      _buildexamplenewElementWidget("Change player theme", () {
        _navigateToPage(ChangePlayerThemePage());
      }),
      _buildexamplenewElementWidget("Overridden duration", () {
        _navigateToPage(OverriddenDurationPage());
      }),
      _buildexamplenewElementWidget("Picture in Picture", () {
        _navigateToPage(PictureInPicturePage());
      }),
      _buildexamplenewElementWidget("Controls always visible", () {
        _navigateToPage(ControlsAlwaysVisiblePage());
      }),
      _buildexamplenewElementWidget("DRM", () {
        _navigateToPage(DrmPage());
      }),
      _buildexamplenewElementWidget("ClearKey DRM", () {
        _navigateToPage(ClearKeyPage());
      }),
      _buildexamplenewElementWidget("DASH", () {
        _navigateToPage(DashPage());
      }),
    ];
  }

  Widget _buildexamplenewElementWidget(String name, Function onClicked) {
    return Material(
      child: InkWell(
        onTap: onClicked as void Function()?,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                name,
                style: TextStyle(fontSize: 16),
              ),
            ),
            Divider(),
          ],
        ),
      ),
    );
  }

  Future _navigateToPage(Widget routeWidget) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => routeWidget),
    );
  }

  ///Save subtitles to file, so we can use it later
  Future _saveAssetSubtitleToFile() async {
    String content =
        await rootBundle.loadString("assets/examplenew_subtitles.srt");
    final directory = await getApplicationDocumentsDirectory();
    var file = File("${directory.path}/examplenew_subtitles.srt");
    file.writeAsString(content);
  }

  ///Save video to file, so we can use it later
  Future _saveAssetVideoToFile() async {
    var content = await rootBundle.load("assets/testvideo.mp4");
    final directory = await getApplicationDocumentsDirectory();
    var file = File("${directory.path}/testvideo.mp4");
    file.writeAsBytesSync(content.buffer.asUint8List());
  }

  Future _saveAssetEncryptVideoToFile() async {
    var content =
        await rootBundle.load("assets/${Constants.fileTestVideoEncryptUrl}");
    final directory = await getApplicationDocumentsDirectory();
    var file = File("${directory.path}/${Constants.fileTestVideoEncryptUrl}");
    file.writeAsBytesSync(content.buffer.asUint8List());
  }

  ///Save logo to file, so we can use it later
  Future _saveLogoToFile() async {
    var content = await rootBundle.load("assets/${Constants.logo}");
    final directory = await getApplicationDocumentsDirectory();
    var file = File("${directory.path}/${Constants.logo}");
    file.writeAsBytesSync(content.buffer.asUint8List());
  }
}
