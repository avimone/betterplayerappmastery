import 'dart:io';
import 'dart:math';
import 'package:better_player/better_player.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

///Base class for both material and cupertino controls
abstract class BetterPlayerControlsState<T extends StatefulWidget>
    extends State<T> {
  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  BetterPlayerController? get betterPlayerController;

  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration;

  VideoPlayerValue? get latestValue;

  bool controlsNotVisible = true;

  bool _isSpeedSupported = true; // Default to true, will be tested
  bool _hasTestedSpeedSupport = false;

  void cancelAndRestartTimer();

  bool get shouldShowSpeedControls =>
      betterPlayerControlsConfiguration.enablePlaybackSpeed &&
      _isSpeedSupported;

  @override
  void initState() {
    super.initState();

    // Listen for video initialization to test speed support
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSpeedTestingListener();
    });
  }

  void _setupSpeedTestingListener() {
    betterPlayerController?.videoPlayerController?.addListener(() {
      if (betterPlayerController?.videoPlayerController?.value.initialized ==
              true &&
          !_hasTestedSpeedSupport) {
        // Delay the test slightly to ensure video is fully ready
        Future.delayed(Duration(milliseconds: 800), () {
          _testSpeedSupport();
        });
      }
    });
  }

  Future<void> _testSpeedSupport() async {
    if (_hasTestedSpeedSupport) return;
    if (betterPlayerController?.videoPlayerController == null) return;
    if (betterPlayerController?.videoPlayerController?.value.initialized !=
        true) return;

    try {
      final originalSpeed =
          betterPlayerController!.videoPlayerController!.value.speed;

      // Test with a small speed change
      await betterPlayerController!.setSpeed(1.25);
      await Future.delayed(Duration(milliseconds: 150));

      // Reset to original speed
      await betterPlayerController!.setSpeed(originalSpeed);

      // If we get here without exception, speed is supported
      _isSpeedSupported = true;
      BetterPlayerUtils.log("Speed controls are supported for this video");
    } on PlatformException catch (e) {
      if (e.code.contains('unsupported')) {
        _isSpeedSupported = false;
        BetterPlayerUtils.log(
            "Speed not supported for this video: ${e.message}");
      } else {
        _isSpeedSupported = true; // Assume supported for other errors
      }
    } catch (e) {
      _isSpeedSupported = true; // Assume supported for other errors
      BetterPlayerUtils.log("Speed test error (assuming supported): $e");
    }

    _hasTestedSpeedSupport = true;

    // Trigger UI rebuild to hide/show speed controls
    if (mounted) {
      setState(() {});
    }
  }

  // Add method to reset speed testing when datasource changes
  void resetSpeedTesting() {
    _hasTestedSpeedSupport = false;
    _isSpeedSupported = true; // Reset to default
    if (mounted) {
      setState(() {});
    }
  }

  bool isVideoFinished(VideoPlayerValue? videoPlayerValue) {
    return videoPlayerValue?.position != null &&
        videoPlayerValue?.duration != null &&
        videoPlayerValue!.position.inMilliseconds != 0 &&
        videoPlayerValue.duration!.inMilliseconds != 0 &&
        videoPlayerValue.position >= videoPlayerValue.duration!;
  }

  void skipBack() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final beginning = const Duration().inMilliseconds;
      final skip = (latestValue!.position -
              Duration(
                  milliseconds: betterPlayerControlsConfiguration
                      .backwardSkipTimeInMilliseconds))
          .inMilliseconds;
      betterPlayerController!
          .seekTo(Duration(milliseconds: max(skip, beginning)));
    }
  }

  void skipForward() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final end = latestValue!.duration!.inMilliseconds;
      final skip = (latestValue!.position +
              Duration(
                  milliseconds: betterPlayerControlsConfiguration
                      .forwardSkipTimeInMilliseconds))
          .inMilliseconds;
      betterPlayerController!.seekTo(Duration(milliseconds: min(skip, end)));
    }
  }

  void onShowMoreClicked() {
    // Test speed support before showing menu if not already tested and video is ready
    if (!_hasTestedSpeedSupport &&
        betterPlayerController?.videoPlayerController?.value.initialized ==
            true) {
      _testSpeedSupport().then((_) {
        // Show the menu after testing is complete
        _showModalBottomSheet([_buildMoreOptionsList()]);
      });
    } else {
      _showModalBottomSheet([_buildMoreOptionsList()]);
    }
  }

  void onVideoTracksClicked() async {
    var items = await _showQualitiesSelectionWidget();
    await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
                300, MediaQuery.of(context).size.height - 300, 0.0, 0.0),
            items: items,
            elevation: 8.0,
            color: Colors.black)
        .then((value) {
      setState(() {});
    });
  }

  void onAudioTracksClicked() async {
    var items = await _showAudioTracksSelectionWidget();
    await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height - 300, 0.0, 0.0),
            items: items,
            elevation: 8.0,
            color: Colors.black)
        .then((value) {
      setState(() {});
    });
  }

  Widget _buildMoreOptionsList() {
    final translations = betterPlayerController!.translations;
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            // MODIFIED: Use shouldShowSpeedControls instead of enablePlaybackSpeed
            if (shouldShowSpeedControls)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.playbackSpeedIcon,
                  translations.overflowMenuPlaybackSpeed, () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              }),
            if (betterPlayerControlsConfiguration.enableSubtitles)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.subtitlesIcon,
                  translations.overflowMenuSubtitles, () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              }),
            /*          if (betterPlayerControlsConfiguration.enableQualities)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.qualitiesIcon,
                  translations.overflowMenuQuality, () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              }),
            if (betterPlayerControlsConfiguration.enableAudioTracks)
              _buildMoreOptionsListRow(
                  betterPlayerControlsConfiguration.audioTracksIcon,
                  translations.overflowMenuAudioTracks, () {
                Navigator.of(context).pop();
                _showAudioTracksSelectionWidget();
              }), */
            if (betterPlayerControlsConfiguration
                .overflowMenuCustomItems.isNotEmpty)
              ...betterPlayerControlsConfiguration.overflowMenuCustomItems.map(
                (customItem) => _buildMoreOptionsListRow(
                  customItem.icon,
                  customItem.title,
                  () {
                    Navigator.of(context).pop();
                    customItem.onClicked.call();
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsListRow(
      IconData icon, String name, void Function() onTap) {
    return BetterPlayerMaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
              color: betterPlayerControlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedChooserWidget() {
    _showModalBottomSheet([
      _buildSpeedRow(0.25),
      _buildSpeedRow(0.5),
      _buildSpeedRow(0.75),
      _buildSpeedRow(1.0),
      _buildSpeedRow(1.25),
      _buildSpeedRow(1.5),
      _buildSpeedRow(1.75),
      _buildSpeedRow(2.0),
    ]);
  }

  Widget _buildSpeedRow(double value) {
    final bool isSelected =
        betterPlayerController!.videoPlayerController!.value.speed == value;

    return BetterPlayerMaterialClickableWidget(
      onTap: () async {
        Navigator.of(context).pop();

        try {
          await betterPlayerController!.setSpeed(value);
        } on PlatformException catch (e) {
          if (e.code.contains('unsupported')) {
            // If speed fails during usage, mark as unsupported and hide controls
            _isSpeedSupported = false;
            _hasTestedSpeedSupport = true;
            if (mounted) setState(() {});

            // Show user-friendly message
            final context = this.context;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'This video does not support playback speed changes'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            // Show generic error for other platform exceptions
            final context = this.context;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Failed to change playback speed: ${e.message}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          // Show generic error for other exceptions
          final context = this.context;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to change playback speed'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              "$value x",
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  ///Latest value can be null
  bool isLoading(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;

      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  void _showSubtitlesSelectionWidget() {
    final subtitles =
        List.of(betterPlayerController!.betterPlayerSubtitlesSourceList);
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull(
            (source) => source.type == BetterPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.none));
    }

    _showModalBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList());
  }

  Widget _buildSubtitlesSourceRow(BetterPlayerSubtitlesSource subtitlesSource) {
    final selectedSourceType =
        betterPlayerController!.betterPlayerSubtitlesSource;
    final bool isSelected = (subtitlesSource == selectedSourceType) ||
        (subtitlesSource.type == BetterPlayerSubtitlesSourceType.none &&
            subtitlesSource.type == selectedSourceType!.type);

    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setupSubtitleSource(subtitlesSource);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color:
                      betterPlayerControlsConfiguration.overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              subtitlesSource.type == BetterPlayerSubtitlesSourceType.none
                  ? betterPlayerController!.translations.generalNone
                  : subtitlesSource.name ??
                      betterPlayerController!.translations.generalDefault,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  ///Build both track and resolution selection
  ///Track selection is used for HLS / DASH videos
  ///Resolution selection is used for normal videos
  List<PopupMenuEntry<String>> _showQualitiesSelectionWidget() {
    // HLS / DASH
    final List<String> asmsTrackNames =
        betterPlayerController!.betterPlayerDataSource!.asmsTrackNames ?? [];
    final List<BetterPlayerAsmsTrack> asmsTracks =
        betterPlayerController!.betterPlayerAsmsTracks;
    final List<BetterPlayerAsmsTrack> asmsTracksSorted =
        asmsTracks.toList(); // Create a copy to avoid modifying original list
    asmsTracksSorted.sort((a, b) => a.width!.compareTo(b.width!));
    final List<PopupMenuEntry<String>> children = [];
    for (var index = 0; index < asmsTracksSorted.length; index++) {
      final track = asmsTracksSorted[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = betterPlayerController!.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracksSorted[index], preferredName));
    }

    // normal videos
    final resolutions =
        betterPlayerController!.betterPlayerDataSource!.resolutions;

    resolutions?.forEach((key, value) {
      children.add(_buildResolutionSelectionRow(key, value));
    });

    if (children.isEmpty) {
      children.add(
        _buildTrackRow(BetterPlayerAsmsTrack.defaultTrack(),
            betterPlayerController!.translations.qualityAuto),
      );
    }

    return children;
    // _showModalBottomSheet(children);
  }

  PopupMenuEntry<String> _buildTrackRow(
      BetterPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    final String mimeType = (track.mimeType ?? '').replaceAll('video/', '');
    final String trackName = preferredName ??
        "${width}x$height ${BetterPlayerUtils.formatBitrate(bitrate)} $mimeType";

    final BetterPlayerAsmsTrack? selectedTrack =
        betterPlayerController!.betterPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;
    print(preferredName ??
        "${width}x$height ${BetterPlayerUtils.formatBitrate(bitrate)} $mimeType");

    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setTrack(track);
      },
      value: trackName,
      child: BetterPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          betterPlayerController!.setTrack(track);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              SizedBox(width: isSelected ? 8 : 16),
              Visibility(
                  visible: isSelected,
                  child: Icon(
                    Icons.check_outlined,
                    color: Colors.white,
                  )),
              const SizedBox(width: 16),
              Text(
                trackName,
                style: _getOverflowMenuElementTextStyle(isSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<String> _buildResolutionSelectionRow(String name, String url) {
    final bool isSelected =
        url == betterPlayerController!.betterPlayerDataSource!.url;
    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setResolution(url);
      },
      child: BetterPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          betterPlayerController!.setResolution(url);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              SizedBox(width: isSelected ? 8 : 16),
              Visibility(
                  visible: isSelected,
                  child: Icon(
                    Icons.check_outlined,
                    color: Colors.white,
                  )),
              const SizedBox(width: 16),
              Text(
                name,
                style: _getOverflowMenuElementTextStyle(isSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _showAudioTracksSelectionWidget() {
    //HLS / DASH
    final List<BetterPlayerAsmsAudioTrack>? asmsTracks =
        betterPlayerController!.betterPlayerAsmsAudioTracks;
    final List<PopupMenuEntry<String>> children = [];
    final BetterPlayerAsmsAudioTrack? selectedAsmsAudioTrack =
        betterPlayerController!.betterPlayerAsmsAudioTrack;
    if (asmsTracks != null) {
      for (var index = 0; index < asmsTracks.length; index++) {
        final bool isSelected = selectedAsmsAudioTrack != null &&
            selectedAsmsAudioTrack == asmsTracks[index];
        children.add(_buildAudioTrackRow(asmsTracks[index], isSelected));
      }
    }

    if (children.isEmpty) {
      children.add(
        _buildAudioTrackRow(
          BetterPlayerAsmsAudioTrack(
            label: betterPlayerController!.translations.generalDefault,
          ),
          true,
        ),
      );
    }
    return children;
    //_showModalBottomSheet(children);
  }

  PopupMenuEntry<String> _buildAudioTrackRow(
      BetterPlayerAsmsAudioTrack audioTrack, bool isSelected) {
    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        betterPlayerController!.setAudioTrack(audioTrack);
      },
      child: BetterPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          betterPlayerController!.setAudioTrack(audioTrack);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              SizedBox(width: isSelected ? 8 : 16),
              Visibility(
                  visible: isSelected,
                  child: Icon(
                    Icons.check_outlined,
                    color: Colors.white,
                  )),
              const SizedBox(width: 16),
              Text(
                audioTrack.label!,
                style: _getOverflowMenuElementTextStyle(isSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
    );
  }

  void _showModalBottomSheet(List<Widget> children) {
    Platform.isAndroid
        ? _showMaterialBottomSheet(children)
        : _showCupertinoModalBottomSheet(children);
  }

  void _showCupertinoModalBottomSheet(List<Widget> children) {
    showCupertinoModalPopup<void>(
      barrierColor: Colors.transparent,
      context: context,
      useRootNavigator:
          betterPlayerController?.betterPlayerConfiguration.useRootNavigator ??
              false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: betterPlayerControlsConfiguration.overflowModalColor,
                /*shape: RoundedRectangleBorder(side: Bor,borderRadius: 24,)*/
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMaterialBottomSheet(List<Widget> children) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      useRootNavigator:
          betterPlayerController?.betterPlayerConfiguration.useRootNavigator ??
              false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: betterPlayerControlsConfiguration.overflowModalColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  ///Builds directionality widget which wraps child widget and forces left to
  ///right directionality.
  Widget buildLTRDirectionality(Widget child) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  ///Called when player controls visibility should be changed.
  void changePlayerControlsNotVisible(bool notVisible) {
    setState(() {
      if (notVisible) {
        betterPlayerController?.postEvent(
            BetterPlayerEvent(BetterPlayerEventType.controlsHiddenStart));
      }
      controlsNotVisible = notVisible;
    });
  }
}
