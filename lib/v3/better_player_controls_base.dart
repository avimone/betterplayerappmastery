// better_player_controls_base.dart
import 'dart:async';
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// Base class for Better Player controls with improved architecture
abstract class BetterPlayerControlsBase<T extends StatefulWidget>
    extends State<T> {
  /// Controller instance
  late BetterPlayerController controller;

  /// Controls configuration
  late BetterPlayerControlsConfiguration config;

  /// Subscription to state changes
  StreamSubscription? _stateSubscription;
  StreamSubscription? _visibilitySubscription;

  /// Get the theme-specific controls widget
  Widget buildControls(BuildContext context);

  @override
  void initState() {
    super.initState();
    controller = BetterPlayerController.of(context);
    config = controller.betterPlayerControlsConfiguration;

    // Listen to visibility changes
    _visibilitySubscription = controller.controlsVisibilityStream.listen((_) {
      if (mounted) setState(() {});
    });

    // Listen to state changes
    controller.state.addListener(_onStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = BetterPlayerController.of(context);
    if (newController != controller) {
      controller.state.removeListener(_onStateChanged);
      controller = newController;
      config = controller.betterPlayerControlsConfiguration;
      controller.state.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    controller.state.removeListener(_onStateChanged);
    _stateSubscription?.cancel();
    _visibilitySubscription?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AbsorbPointer(
        absorbing: !controller.state.controlsVisible,
        child: buildControls(context),
      ),
    );
  }

  /// Handle single tap
  void onTap() {
    if (controller.state.controlsVisible) {
      controller.setControlsVisibility(false);
    } else {
      controller.setControlsVisibility(true);
    }
  }

  /// Handle double tap
  void onDoubleTap() {
    if (controller.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  /// Skip backward
  void skipBack() {
    final position = controller.position;
    final skip = position -
        Duration(
          milliseconds: config.backwardSkipTimeInMilliseconds,
        );
    controller.seekTo(skip.isNegative ? Duration.zero : skip);
  }

  /// Skip forward
  void skipForward() {
    final position = controller.position;
    final duration = controller.duration;
    final skip = position +
        Duration(
          milliseconds: config.forwardSkipTimeInMilliseconds,
        );
    controller.seekTo(skip > duration ? duration : skip);
  }

  /// Show quality selection
  void showQualitySelection() {
    final tracks = controller.betterPlayerAsmsTracks;
    final resolutions = controller.betterPlayerDataSource?.resolutions;

    if (tracks.isNotEmpty) {
      _showTrackSelection(tracks);
    } else if (resolutions != null && resolutions.isNotEmpty) {
      _showResolutionSelection(resolutions);
    }
  }

  /// Show audio track selection
  void showAudioTrackSelection() {
    final tracks = controller.betterPlayerAsmsAudioTracks ?? [];
    if (tracks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => AudioTrackSelectionSheet(
        tracks: tracks,
        selectedTrack: controller.betterPlayerAsmsAudioTrack,
        onTrackSelected: (track) {
          controller.setAudioTrack(track);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Show subtitles selection
  void showSubtitlesSelection() {
    final sources = controller.betterPlayerSubtitlesSourceList;
    if (sources.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SubtitleSelectionSheet(
        sources: sources,
        selectedSource: controller.betterPlayerSubtitlesSource,
        onSourceSelected: (source) {
          controller.setupSubtitleSource(source);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Show playback speed selection
  void showPlaybackSpeedSelection() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      builder: (context) => PlaybackSpeedSheet(
        speeds: speeds,
        selectedSpeed: controller.playbackSpeed,
        onSpeedSelected: (speed) {
          controller.setSpeed(speed);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Show overflow menu
  void showOverflowMenu() {
    final items = <OverflowMenuItem>[];

    if (config.enablePlaybackSpeed) {
      items.add(OverflowMenuItem(
        icon: config.playbackSpeedIcon,
        title: controller.translations.overflowMenuPlaybackSpeed,
        onTap: showPlaybackSpeedSelection,
      ));
    }

    if (config.enableSubtitles) {
      items.add(OverflowMenuItem(
        icon: config.subtitlesIcon,
        title: controller.translations.overflowMenuSubtitles,
        onTap: showSubtitlesSelection,
      ));
    }

    if (config.enableQualities) {
      items.add(OverflowMenuItem(
        icon: config.qualitiesIcon,
        title: controller.translations.overflowMenuQuality,
        onTap: showQualitySelection,
      ));
    }

    if (config.enableAudioTracks) {
      items.add(OverflowMenuItem(
        icon: config.audioTracksIcon,
        title: controller.translations.overflowMenuAudioTracks,
        onTap: showAudioTrackSelection,
      ));
    }

    // Add custom items
    for (final item in config.overflowMenuCustomItems) {
      items.add(OverflowMenuItem(
        icon: item.icon,
        title: item.title,
        onTap: item.onClicked,
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: config.overflowModalColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => OverflowMenuSheet(
        items: items,
        textColor: config.overflowModalTextColor,
        iconColor: config.overflowMenuIconsColor,
      ),
    );
  }

  void _showTrackSelection(List<BetterPlayerAsmsTrack> tracks) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TrackSelectionSheet(
        tracks: tracks,
        selectedTrack: controller.betterPlayerAsmsTrack,
        onTrackSelected: (track) {
          controller.setTrack(track);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showResolutionSelection(Map<String, String> resolutions) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ResolutionSelectionSheet(
        resolutions: resolutions,
        currentUrl: controller.betterPlayerDataSource?.url ?? '',
        onResolutionSelected: (url) {
          controller.setResolution(url);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Check if video is finished
  bool get isVideoFinished {
    final position = controller.position;
    final duration = controller.duration;
    return position >= duration && duration != Duration.zero;
  }

  /// Check if controls should be shown
  bool get shouldShowControls =>
      config.showControls && controller.controlsEnabled;

  /// Format duration for display
  String formatDuration(Duration duration) {
    return BetterPlayerUtils.formatDuration(duration);
  }
}

/// Overflow menu item
class OverflowMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  OverflowMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// Base selection sheet widget
abstract class SelectionSheet<T> extends StatelessWidget {
  final String title;
  final T? selected;
  final Function(T) onSelected;

  const SelectionSheet({
    Key? key,
    required this.title,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  List<T> getItems();
  String getItemTitle(T item);
  String? getItemSubtitle(T item) => null;

  @override
  Widget build(BuildContext context) {
    final items = getItems();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selected;

                return ListTile(
                  leading: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : const SizedBox(width: 24),
                  title: Text(
                    getItemTitle(item),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: getItemSubtitle(item) != null
                      ? Text(getItemSubtitle(item)!)
                      : null,
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Track selection sheet
class TrackSelectionSheet extends SelectionSheet<BetterPlayerAsmsTrack> {
  final List<BetterPlayerAsmsTrack> tracks;

  TrackSelectionSheet({
    Key? key,
    required this.tracks,
    required BetterPlayerAsmsTrack? selectedTrack,
    required Function(BetterPlayerAsmsTrack) onTrackSelected,
  }) : super(
          key: key,
          title: 'Quality',
          selected: selectedTrack,
          onSelected: onTrackSelected,
        );

  @override
  List<BetterPlayerAsmsTrack> getItems() => tracks;

  @override
  String getItemTitle(BetterPlayerAsmsTrack track) {
    if (track.height == 0 && track.width == 0) {
      return 'Auto';
    }
    return '${track.height}p';
  }

  @override
  String? getItemSubtitle(BetterPlayerAsmsTrack track) {
    if (track.bitrate == 0) return null;
    return BetterPlayerUtils.formatBitrate(track.bitrate ?? 0);
  }
}

/// Resolution selection sheet
class ResolutionSelectionSheet extends StatelessWidget {
  final Map<String, String> resolutions;
  final String currentUrl;
  final Function(String) onResolutionSelected;

  const ResolutionSelectionSheet({
    Key? key,
    required this.resolutions,
    required this.currentUrl,
    required this.onResolutionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Quality',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: resolutions.entries.map((entry) {
                final isSelected = entry.value == currentUrl;

                return ListTile(
                  leading: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : const SizedBox(width: 24),
                  title: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () => onResolutionSelected(entry.value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio track selection sheet
class AudioTrackSelectionSheet
    extends SelectionSheet<BetterPlayerAsmsAudioTrack> {
  final List<BetterPlayerAsmsAudioTrack> tracks;

  AudioTrackSelectionSheet({
    Key? key,
    required this.tracks,
    required BetterPlayerAsmsAudioTrack? selectedTrack,
    required Function(BetterPlayerAsmsAudioTrack) onTrackSelected,
  }) : super(
          key: key,
          title: 'Audio',
          selected: selectedTrack,
          onSelected: onTrackSelected,
        );

  @override
  List<BetterPlayerAsmsAudioTrack> getItems() => tracks;

  @override
  String getItemTitle(BetterPlayerAsmsAudioTrack track) {
    return track.label ?? track.language ?? 'Unknown';
  }
}

/// Subtitle selection sheet
class SubtitleSelectionSheet
    extends SelectionSheet<BetterPlayerSubtitlesSource> {
  final List<BetterPlayerSubtitlesSource> sources;

  SubtitleSelectionSheet({
    Key? key,
    required this.sources,
    required BetterPlayerSubtitlesSource? selectedSource,
    required Function(BetterPlayerSubtitlesSource) onSourceSelected,
  }) : super(
          key: key,
          title: 'Subtitles',
          selected: selectedSource,
          onSelected: onSourceSelected,
        );

  @override
  List<BetterPlayerSubtitlesSource> getItems() => sources;

  @override
  String getItemTitle(BetterPlayerSubtitlesSource source) {
    if (source.type == BetterPlayerSubtitlesSourceType.none) {
      return 'None';
    }
    return source.name ?? 'Default';
  }
}

/// Playback speed selection sheet
class PlaybackSpeedSheet extends SelectionSheet<double> {
  final List<double> speeds;

  PlaybackSpeedSheet({
    Key? key,
    required this.speeds,
    required double selectedSpeed,
    required Function(double) onSpeedSelected,
  }) : super(
          key: key,
          title: 'Playback Speed',
          selected: selectedSpeed,
          onSelected: onSpeedSelected,
        );

  @override
  List<double> getItems() => speeds;

  @override
  String getItemTitle(double speed) => '${speed}x';
}

/// Overflow menu sheet
class OverflowMenuSheet extends StatelessWidget {
  final List<OverflowMenuItem> items;
  final Color textColor;
  final Color iconColor;

  const OverflowMenuSheet({
    Key? key,
    required this.items,
    required this.textColor,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          return ListTile(
            leading: Icon(item.icon, color: iconColor),
            title: Text(
              item.title,
              style: TextStyle(color: textColor),
            ),
            onTap: () {
              Navigator.pop(context);
              item.onTap();
            },
          );
        }).toList(),
      ),
    );
  }
}
