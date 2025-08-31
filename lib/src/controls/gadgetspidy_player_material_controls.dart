import 'dart:async';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_configuration.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_controls_configuration.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_clickable_widget.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_controls_state.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_material_progress_bar.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_multiple_gesture_detector.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_progress_colors.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_controller.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'package:gadgetspidy_player/src/video_player/video_player.dart';

// Flutter imports:
import 'package:flutter/material.dart';

import '../configuration/gadgetspidy_player_controller_event.dart';

class GadgetspidyPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final GadgetspidyPlayerControlsConfiguration controlsConfiguration;

  const GadgetspidyPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _GadgetspidyPlayerMaterialControlsState();
  }
}

class _GadgetspidyPlayerMaterialControlsState
    extends GadgetspidyPlayerControlsState<GadgetspidyPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  GadgetspidyPlayerController? _gadgetspidyPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  GadgetspidyPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  GadgetspidyPlayerController? get gadgetspidyPlayerController =>
      _gadgetspidyPlayerController;

  @override
  GadgetspidyPlayerControlsConfiguration
      get gadgetspidyPlayerControlsConfiguration => _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return GestureDetector(
      onTap: () {
        if (GadgetspidyPlayerMultipleGestureDetector.of(context) != null) {
          GadgetspidyPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (GadgetspidyPlayerMultipleGestureDetector.of(context) != null) {
          GadgetspidyPlayerMultipleGestureDetector.of(context)!
              .onDoubleTap
              ?.call();
        }
        cancelAndRestartTimer();
      },
      onLongPress: () {
        if (GadgetspidyPlayerMultipleGestureDetector.of(context) != null) {
          GadgetspidyPlayerMultipleGestureDetector.of(context)!
              .onLongPress
              ?.call();
        }
      },
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wasLoading)
              Center(child: _buildLoadingWidget())
            else
              _buildHitArea(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            _buildNextVideoWidget(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _gadgetspidyPlayerController;
    _gadgetspidyPlayerController = GadgetspidyPlayerController.of(context);
    _controller = _gadgetspidyPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _gadgetspidyPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildDownloadWidget() {
    final config = _gadgetspidyPlayerController!.gadgetspidyPlayerConfiguration;

    if (config.downloadWidget == null && config.downloadFunction == null) {
      return const SizedBox();
    }

    // If custom widget is provided, use it
    if (config.downloadWidget != null) {
      return AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: config.downloadWidget!,
      );
    }

    // If only function is provided, create a default download button
    if (config.downloadFunction != null) {
      return AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: GadgetspidyPlayerMaterialClickableWidget(
          onTap: () => config.downloadFunction!(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.download_outlined,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildErrorWidget() {
    final errorBuilder = _gadgetspidyPlayerController!
        .gadgetspidyPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _gadgetspidyPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _gadgetspidyPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _gadgetspidyPlayerController!.retryDataSource();
                },
                child: Text(
                  _gadgetspidyPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!gadgetspidyPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    final config = _gadgetspidyPlayerController!.gadgetspidyPlayerConfiguration;
    final showDownloadInTopBar =
        config.downloadButtonPosition == DownloadButtonPosition.topLeft ||
            config.downloadButtonPosition == DownloadButtonPosition.topRight;

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu ||
              showDownloadInTopBar ||
              config.title != null)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                height: _controlsConfiguration.controlBarHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side controls
                    Expanded(
                      child: Row(
                        children: [
                          // Title widget
                          if (config.title != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                config.title!,
                                style: config.titleStyle ??
                                    TextStyle(
                                      color: _controlsConfiguration.textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Download widget in top left
                          if (config.downloadButtonPosition ==
                              DownloadButtonPosition.topLeft)
                            _buildDownloadWidget(),
                        ],
                      ),
                    ),

                    // Right side controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (config.downloadButtonPosition ==
                            DownloadButtonPosition.topRight)
                          _buildDownloadWidget(),
                        _buildPipButton(),
                        _buildVideoTracksButton(),
                        _buildMoreButton(),
                        _buildBackButton(),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    if (!_controlsConfiguration.enablePip) {
      return const SizedBox();
    }

    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        _onPipButtonPressed();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.pipMenuIcon,
          color: _controlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        _gadgetspidyPlayerController!.exitPlayer();
        if (_gadgetspidyPlayerController!.isFullScreen) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
        }
        /*   gadgetspidyPlayerController!.enablePictureInPicture(
            gadgetspidyPlayerController!.gadgetspidyPlayerGlobalKey!); */
        //   gadgetspidyPlayerController!.gadgetspidyPlayerConfiguration!.pip!();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.close,
          color: gadgetspidyPlayerControlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildAudioTracksButton() {
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        onAudioTracksClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          gadgetspidyPlayerControlsConfiguration.audioTracksIcon,
          color: gadgetspidyPlayerControlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildVideoTracksButton() {
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        onVideoTracksClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          gadgetspidyPlayerControlsConfiguration.qualitiesIcon,
          color: gadgetspidyPlayerControlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    if (!_controlsConfiguration.enablePip) {
      return const SizedBox();
    }

    return FutureBuilder<bool>(
      future: _gadgetspidyPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _gadgetspidyPlayerController!.gadgetspidyPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: _controlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: _controlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  ///Handle PiP button press - now using built-in functionality instead of passed function
  void _onPipButtonPressed() async {
    if (_gadgetspidyPlayerController?.gadgetspidyPlayerGlobalKey != null) {
      try {
        await _gadgetspidyPlayerController!.enablePictureInPicture(
            _gadgetspidyPlayerController!.gadgetspidyPlayerGlobalKey!);
      } catch (e) {
        GadgetspidyPlayerUtils.log("Failed to enable Picture in Picture: $e");
        // Optionally show user-friendly error message
        _showPipErrorSnackbar();
      }
    } else {
      GadgetspidyPlayerUtils.log("Cannot enable PiP: Global key not set");
    }
  }

  void _showPipErrorSnackbar() {
    final context = _gadgetspidyPlayerController
        ?.gadgetspidyPlayerGlobalKey?.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Picture in Picture not available on this device'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMoreButton() {
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!gadgetspidyPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    final config = _gadgetspidyPlayerController!.gadgetspidyPlayerConfiguration;
    final showDownloadInBottomBar =
        config.downloadButtonPosition == DownloadButtonPosition.bottomLeft ||
            config.downloadButtonPosition == DownloadButtonPosition.bottomRight;

    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        height: _controlsConfiguration.controlBarHeight + 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 75,
              child: Row(
                children: [
                  if (_controlsConfiguration.enablePlayPause)
                    _buildPlayPause(_controller!)
                  else
                    const SizedBox(),

                  if (_gadgetspidyPlayerController!.isLiveStream())
                    _buildLiveWidget()
                  else
                    _controlsConfiguration.enableProgressText
                        ? Expanded(child: _buildPosition())
                        : const SizedBox(),

                  const Spacer(),

                  // Download widget in bottom bar
                  if (config.downloadButtonPosition ==
                      DownloadButtonPosition.bottomLeft)
                    _buildDownloadWidget(),

                  if (_controlsConfiguration.enableMute)
                    _buildMuteButton(_controller)
                  else
                    const SizedBox(),

                  if (config.downloadButtonPosition ==
                      DownloadButtonPosition.bottomRight)
                    _buildDownloadWidget(),

                  if (_controlsConfiguration.enableFullscreen)
                    _buildExpandButton()
                  else
                    const SizedBox(),
                ],
              ),
            ),
            if (_gadgetspidyPlayerController!.isLiveStream())
              const SizedBox()
            else
              _controlsConfiguration.enableProgressBar
                  ? _buildProgressBar()
                  : const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Text(
      _gadgetspidyPlayerController!.translations.controlsLive,
      style: TextStyle(
          color: _controlsConfiguration.liveTextColor,
          fontWeight: FontWeight.bold),
    );
  }

  Widget _buildExpandButton() {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: GadgetspidyPlayerMaterialClickableWidget(
        onTap: _controlsConfiguration.fullScreenButtonExit
            ? _onFullScreenButtonExit // 🚀 NEW: Exit player behavior
            : _onExpandCollapse, // ✅ EXISTING: Toggle fullscreen behavior
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Icon(
                _gadgetspidyPlayerController!.isFullScreen
                    ? _controlsConfiguration.fullscreenDisableIcon
                    : _controlsConfiguration.fullscreenEnableIcon,
                color: _controlsConfiguration.iconsColor,
                size: _controlsConfiguration.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!gadgetspidyPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      child: Center(
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: _buildMiddleRow(),
        ),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      color: _controlsConfiguration.controlBarColor,
      width: double.infinity,
      height: double.infinity,
      child: _gadgetspidyPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_controlsConfiguration.enableSkips)
                  Expanded(child: _buildSkipButton())
                else
                  const SizedBox(),
                Expanded(child: _buildReplayButton(_controller!)),
                if (_controlsConfiguration.enableSkips)
                  Expanded(child: _buildForwardButton())
                else
                  const SizedBox(),
              ],
            ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: GadgetspidyPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipBackIcon,
        size: _gadgetspidyPlayerController!.isFullScreen ? 57 : 47,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipForwardIcon,
        size: _gadgetspidyPlayerController!.isFullScreen ? 57 : 47,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipForward,
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(
              Icons.replay,
              size: 45,
              color: _controlsConfiguration.iconsColor,
            )
          : Icon(
              controller.value.isPlaying
                  ? _controlsConfiguration.pauseIcon
                  : _controlsConfiguration.playIcon,
              size: _gadgetspidyPlayerController!.isFullScreen ? 54 : 45,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _gadgetspidyPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return GadgetspidyPlayerMaterialClickableWidget(
            onTap: () {
              _gadgetspidyPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_gadgetspidyPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return GadgetspidyPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (_latestValue!.volume == 0) {
          _gadgetspidyPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _gadgetspidyPlayerController!.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
              size: _controlsConfiguration.iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return GadgetspidyPlayerMaterialClickableWidget(
      key: const Key("gadgetspidy_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
          size: _controlsConfiguration.iconSize,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: _controlsConfiguration.enablePlayPause
          ? const EdgeInsets.only(right: 24)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: RichText(
        text: TextSpan(
            text: GadgetspidyPlayerUtils.formatDuration(position),
            style: _controlsConfiguration
                .timeBarStyle /*  TextStyle(
              fontSize: 10.0,
              color: _controlsConfiguration.textColor,
              decoration: TextDecoration.none,
            ) */
            ,
            children: <TextSpan>[
              TextSpan(
                text: ' / ${GadgetspidyPlayerUtils.formatDuration(duration)}',
                style: _controlsConfiguration
                    .timeBarStyle /* TextStyle(
                  fontSize: 10.0,
                  color: _controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ) */
                ,
              )
            ]),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _gadgetspidyPlayerController!.gadgetspidyPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _gadgetspidyPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _gadgetspidyPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  // Handle fullscreen button exit behavior
  void _onFullScreenButtonExit() {
    // When fullScreenButtonExit is true, behave like the back button
    _gadgetspidyPlayerController!.exitPlayer();
    if (_gadgetspidyPlayerController!.isFullScreen) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _gadgetspidyPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _gadgetspidyPlayerController!.seekTo(const Duration());
        }
        _gadgetspidyPlayerController!.play();
        _gadgetspidyPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_gadgetspidyPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _gadgetspidyPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      flex: 40,
      child: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GadgetspidyPlayerMaterialVideoProgressBar(
          _controller,
          _gadgetspidyPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: GadgetspidyPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _gadgetspidyPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
