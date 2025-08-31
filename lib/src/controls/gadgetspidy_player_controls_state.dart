import 'dart:io';
import 'dart:math';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_clickable_widget.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

///Base class for both material and cupertino controls
abstract class GadgetspidyPlayerControlsState<T extends StatefulWidget>
    extends State<T> {
  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  GadgetspidyPlayerController? get gadgetspidyPlayerController;

  GadgetspidyPlayerControlsConfiguration
      get gadgetspidyPlayerControlsConfiguration;

  VideoPlayerValue? get latestValue;

  bool controlsNotVisible = true;

  void cancelAndRestartTimer();

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
                  milliseconds: gadgetspidyPlayerControlsConfiguration
                      .backwardSkipTimeInMilliseconds))
          .inMilliseconds;
      gadgetspidyPlayerController!
          .seekTo(Duration(milliseconds: max(skip, beginning)));
    }
  }

  void skipForward() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final end = latestValue!.duration!.inMilliseconds;
      final skip = (latestValue!.position +
              Duration(
                  milliseconds: gadgetspidyPlayerControlsConfiguration
                      .forwardSkipTimeInMilliseconds))
          .inMilliseconds;
      gadgetspidyPlayerController!
          .seekTo(Duration(milliseconds: min(skip, end)));
    }
  }

  void onShowMoreClicked() {
    _showModalBottomSheet([_buildMoreOptionsList()]);
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
    final translations = gadgetspidyPlayerController!.translations;
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            if (gadgetspidyPlayerControlsConfiguration.enablePlaybackSpeed)
              _buildMoreOptionsListRow(
                  gadgetspidyPlayerControlsConfiguration.playbackSpeedIcon,
                  translations.overflowMenuPlaybackSpeed, () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              }),
            if (gadgetspidyPlayerControlsConfiguration.enableSubtitles)
              _buildMoreOptionsListRow(
                  gadgetspidyPlayerControlsConfiguration.subtitlesIcon,
                  translations.overflowMenuSubtitles, () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              }),
            /*          if (gadgetspidyPlayerControlsConfiguration.enableQualities)
              _buildMoreOptionsListRow(
                  gadgetspidyPlayerControlsConfiguration.qualitiesIcon,
                  translations.overflowMenuQuality, () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              }),
            if (gadgetspidyPlayerControlsConfiguration.enableAudioTracks)
              _buildMoreOptionsListRow(
                  gadgetspidyPlayerControlsConfiguration.audioTracksIcon,
                  translations.overflowMenuAudioTracks, () {
                Navigator.of(context).pop();
                _showAudioTracksSelectionWidget();
              }), */
            if (gadgetspidyPlayerControlsConfiguration
                .overflowMenuCustomItems.isNotEmpty)
              ...gadgetspidyPlayerControlsConfiguration.overflowMenuCustomItems
                  .map(
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
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
              color:
                  gadgetspidyPlayerControlsConfiguration.overflowMenuIconsColor,
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
        gadgetspidyPlayerController!.videoPlayerController!.value.speed ==
            value;

    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        gadgetspidyPlayerController!.setSpeed(value);
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
                  color: gadgetspidyPlayerControlsConfiguration
                      .overflowModalTextColor,
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
    final subtitles = List.of(
        gadgetspidyPlayerController!.gadgetspidyPlayerSubtitlesSourceList);
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull((source) =>
            source.type == GadgetspidyPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(GadgetspidyPlayerSubtitlesSource(
          type: GadgetspidyPlayerSubtitlesSourceType.none));
    }

    _showModalBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList());
  }

  Widget _buildSubtitlesSourceRow(
      GadgetspidyPlayerSubtitlesSource subtitlesSource) {
    final selectedSourceType =
        gadgetspidyPlayerController!.gadgetspidyPlayerSubtitlesSource;
    final bool isSelected = (subtitlesSource == selectedSourceType) ||
        (subtitlesSource.type == GadgetspidyPlayerSubtitlesSourceType.none &&
            subtitlesSource.type == selectedSourceType!.type);

    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        gadgetspidyPlayerController!.setupSubtitleSource(subtitlesSource);
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
                  color: gadgetspidyPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              subtitlesSource.type == GadgetspidyPlayerSubtitlesSourceType.none
                  ? gadgetspidyPlayerController!.translations.generalNone
                  : subtitlesSource.name ??
                      gadgetspidyPlayerController!.translations.generalDefault,
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
    final List<String> asmsTrackNames = gadgetspidyPlayerController!
            .gadgetspidyPlayerDataSource!.asmsTrackNames ??
        [];
    final List<GadgetspidyPlayerAsmsTrack> asmsTracks =
        gadgetspidyPlayerController!.gadgetspidyPlayerAsmsTracks;
    final List<GadgetspidyPlayerAsmsTrack> asmsTracksSorted =
        asmsTracks.toList(); // Create a copy to avoid modifying original list
    asmsTracksSorted.sort((a, b) => a.width!.compareTo(b.width!));
    final List<PopupMenuEntry<String>> children = [];
    for (var index = 0; index < asmsTracksSorted.length; index++) {
      final track = asmsTracksSorted[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = gadgetspidyPlayerController!.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracksSorted[index], preferredName));
    }

    // normal videos
    final resolutions =
        gadgetspidyPlayerController!.gadgetspidyPlayerDataSource!.resolutions;

    resolutions?.forEach((key, value) {
      children.add(_buildResolutionSelectionRow(key, value));
    });

    if (children.isEmpty) {
      children.add(
        _buildTrackRow(GadgetspidyPlayerAsmsTrack.defaultTrack(),
            gadgetspidyPlayerController!.translations.qualityAuto),
      );
    }

    return children;
    // _showModalBottomSheet(children);
  }

  PopupMenuEntry<String> _buildTrackRow(
      GadgetspidyPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    final String mimeType = (track.mimeType ?? '').replaceAll('video/', '');
    final String trackName = preferredName ??
        "${width}x$height ${GadgetspidyPlayerUtils.formatBitrate(bitrate)} $mimeType";

    final GadgetspidyPlayerAsmsTrack? selectedTrack =
        gadgetspidyPlayerController!.gadgetspidyPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;
    print(preferredName ??
        "${width}x$height ${GadgetspidyPlayerUtils.formatBitrate(bitrate)} $mimeType");

    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        gadgetspidyPlayerController!.setTrack(track);
      },
      value: trackName,
      child: GadgetspidyPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          gadgetspidyPlayerController!.setTrack(track);
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
        url == gadgetspidyPlayerController!.gadgetspidyPlayerDataSource!.url;
    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        gadgetspidyPlayerController!.setResolution(url);
      },
      child: GadgetspidyPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          gadgetspidyPlayerController!.setResolution(url);
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
    final List<GadgetspidyPlayerAsmsAudioTrack>? asmsTracks =
        gadgetspidyPlayerController!.gadgetspidyPlayerAsmsAudioTracks;
    final List<PopupMenuEntry<String>> children = [];
    final GadgetspidyPlayerAsmsAudioTrack? selectedAsmsAudioTrack =
        gadgetspidyPlayerController!.gadgetspidyPlayerAsmsAudioTrack;
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
          GadgetspidyPlayerAsmsAudioTrack(
            label: gadgetspidyPlayerController!.translations.generalDefault,
          ),
          true,
        ),
      );
    }
    return children;
    //_showModalBottomSheet(children);
  }

  PopupMenuEntry<String> _buildAudioTrackRow(
      GadgetspidyPlayerAsmsAudioTrack audioTrack, bool isSelected) {
    return PopupMenuItem<String>(
      onTap: () {
        Navigator.of(context).pop();
        gadgetspidyPlayerController!.setAudioTrack(audioTrack);
      },
      child: GadgetspidyPlayerMaterialClickableWidget(
        onTap: () {
          Navigator.of(context).pop();
          gadgetspidyPlayerController!.setAudioTrack(audioTrack);
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
      useRootNavigator: gadgetspidyPlayerController
              ?.gadgetspidyPlayerConfiguration.useRootNavigator ??
          false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color:
                    gadgetspidyPlayerControlsConfiguration.overflowModalColor,
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
      useRootNavigator: gadgetspidyPlayerController
              ?.gadgetspidyPlayerConfiguration.useRootNavigator ??
          false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color:
                    gadgetspidyPlayerControlsConfiguration.overflowModalColor,
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
        gadgetspidyPlayerController?.postEvent(GadgetspidyPlayerEvent(
            GadgetspidyPlayerEventType.controlsHiddenStart));
      }
      controlsNotVisible = notVisible;
    });
  }
}
