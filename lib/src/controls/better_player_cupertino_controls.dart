import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../configuration/better_player_configuration.dart';

class BetterPlayerCupertinoControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerCupertinoControls({
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerCupertinoControlsState();
  }
}

class _BetterPlayerCupertinoControlsState
    extends BetterPlayerControlsState<BetterPlayerCupertinoControls> {
  final marginSize = 5.0;
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;
  bool _wasLoading = false;

  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _betterPlayerController = BetterPlayerController.of(context);

    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }

    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    final backgroundColor = _controlsConfiguration.controlBarColor;
    final iconColor = _controlsConfiguration.iconsColor;
    final orientation = MediaQuery.of(context).orientation;
    final barHeight = orientation == Orientation.portrait
        ? _controlsConfiguration.controlBarHeight
        : _controlsConfiguration.controlBarHeight + 10;
    const buttonPadding = 10.0;
    final isFullScreen = _betterPlayerController?.isFullScreen == true;

    _wasLoading = isLoading(_latestValue);
    final controlsColumn = Column(children: <Widget>[
      _buildTopBar(
        backgroundColor,
        iconColor,
        barHeight,
        buttonPadding,
      ),
      if (_wasLoading)
        Expanded(child: Center(child: _buildLoadingWidget()))
      else
        _buildHitArea(),
      _buildNextVideoWidget(),
      _buildBottomBar(
        backgroundColor,
        iconColor,
        barHeight,
      ),
    ]);
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
        _onPlayPause();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: AbsorbPointer(
          absorbing: controlsNotVisible,
          child:
              isFullScreen ? SafeArea(child: controlsColumn) : controlsColumn),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller!.removeListener(_updateState);
    _hideTimer?.cancel();
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildLiveWidget() {
    return Expanded(
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(
            color: _controlsConfiguration.liveTextColor,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  GestureDetector _buildExitButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        _betterPlayerController!.exitPlayer();
        if (_betterPlayerController!.isFullScreen) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
        }
        /*   betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!); */
        //   betterPlayerController!.betterPlayerConfiguration!.pip!();
      },
      onDoubleTap: () {
        // Execute the same exit logic on double tap to ensure consistent behavior
        _betterPlayerController!.exitPlayer();
        if (_betterPlayerController!.isFullScreen) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(
              horizontal: buttonPadding,
            ),
            decoration: BoxDecoration(color: backgroundColor),
            child: Center(
              child: Icon(
                Icons.close,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: _controlsConfiguration.fullScreenButtonExit
          ? _onFullScreenButtonExit // 🚀 NEW: Exit player behavior
          : _onExpandCollapse, // ✅ EXISTING: Toggle fullscreen behavior
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(
              horizontal: buttonPadding,
            ),
            decoration: BoxDecoration(color: backgroundColor),
            child: Center(
              child: Icon(
                _betterPlayerController!.isFullScreen
                    ? _controlsConfiguration.fullscreenDisableIcon
                    : _controlsConfiguration.fullscreenEnableIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Expanded _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        onTap: _latestValue != null && _latestValue!.isPlaying
            ? () {
                if (controlsNotVisible == true) {
                  cancelAndRestartTimer();
                } else {
                  _hideTimer?.cancel();
                  changePlayerControlsNotVisible(true);
                }
              }
            : () {
                _hideTimer?.cancel();
                changePlayerControlsNotVisible(false);
              },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  GestureDetector _buildMoreButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        onShowMoreClicked();
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                _controlsConfiguration.overflowMenuIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        cancelAndRestartTimer();

        if (_latestValue!.volume == 0) {
          controller!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                (_latestValue != null && _latestValue!.volume > 0)
                    ? _controlsConfiguration.muteIcon
                    : _controlsConfiguration.unMuteIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Custom button - mirrors Material controls' _buildCustomButtonButton.
  /// Wired through _controlsConfiguration.enableCustomButton +
  /// _controlsConfiguration.customButtonIcon +
  /// betterPlayerConfiguration.customButtonOnTap.
  GestureDetector _buildCustomButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        if (betterPlayerController
                ?.betterPlayerConfiguration.customButtonOnTap ==
            null) {
          return;
        }
        betterPlayerController?.betterPlayerConfiguration.customButtonOnTap!();
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Center(
                child: _controlsConfiguration.customButtonIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(
    VideoPlayerController controller,
    Color iconColor,
    double barHeight,
  ) {
    return GestureDetector(
      onTap: _onPlayPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: iconColor,
          size: barHeight * 0.6,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        BetterPlayerUtils.formatDuration(position),
        style: TextStyle(
          color: _controlsConfiguration.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  Widget _buildRemaining() {
    final position = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration! - _latestValue!.position
        : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(position)}',
        style:
            TextStyle(color: _controlsConfiguration.textColor, fontSize: 12.0),
      ),
    );
  }

  GestureDetector _buildSkipBack(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipBack,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: const EdgeInsets.only(left: 10.0),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        child: Icon(
          _controlsConfiguration.skipBackIcon,
          color: iconColor,
          size: barHeight * 0.4,
        ),
      ),
    );
  }

  GestureDetector _buildSkipForward(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipForward,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        margin: const EdgeInsets.only(right: 8.0),
        child: Icon(
          _controlsConfiguration.skipForwardIcon,
          color: iconColor,
          size: barHeight * 0.4,
        ),
      ),
    );
  }

  Widget _buildDownloadWidget(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    final config = _betterPlayerController!.betterPlayerConfiguration;

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
      return GestureDetector(
        onTap: () => config.downloadFunction!(),
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(horizontal: buttonPadding),
              decoration: BoxDecoration(color: backgroundColor),
              child: Center(
                child: Icon(
                  Icons.download_outlined,
                  color: iconColor,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildTopBar(
    Color backgroundColor,
    Color iconColor,
    double topBarHeight,
    double buttonPadding,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    final config = _betterPlayerController!.betterPlayerConfiguration;
    final barHeight = topBarHeight * 0.8;
    final iconSize = topBarHeight * 0.4;

    return Container(
      height: barHeight,
      margin: EdgeInsets.only(
        top: marginSize,
        right: marginSize,
        left: marginSize,
      ),
      child: Row(
        children: <Widget>[
          _buildExitButton(
            backgroundColor,
            iconColor,
            barHeight,
            iconSize,
            buttonPadding,
          ),
          const SizedBox(width: 4),

          // Download widget on the left
          if (config.downloadButtonPosition == DownloadButtonPosition.topLeft)
            _buildDownloadWidget(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            ),
          const SizedBox(width: 4),

          // Hide expand button if fullScreenButtonExit is true (since it would do the same as close button)
          if (_controlsConfiguration.enableFullscreen &&
              !_controlsConfiguration.fullScreenButtonExit)
            _buildExpandButton(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(width: 4),

          if (_controlsConfiguration.enablePip)
            _buildPipButton(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(width: 4),

          _buildVideoTracksButton(
            backgroundColor,
            iconColor,
            barHeight,
            iconSize,
            buttonPadding,
          ),

          // Title widget - positioned after control buttons but before spacer
          if (config.title != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedOpacity(
                opacity: controlsNotVisible ? 0.0 : 1.0,
                duration: _controlsConfiguration.controlsHideTime,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    config.title!,
                    style: config.titleStyle ??
                        TextStyle(
                          color: _controlsConfiguration.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),

          // Right side controls
          if (config.downloadButtonPosition == DownloadButtonPosition.topRight)
            _buildDownloadWidget(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            ),
          const SizedBox(width: 4),

          if (_controlsConfiguration.enableMute)
            _buildMuteButton(
              _controller,
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(width: 4),

          if (_controlsConfiguration.enableCustomButton)
            _buildCustomButton(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(width: 4),

          if (_controlsConfiguration.enableOverflowMenu)
            _buildMoreButton(
              _controller,
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }

// Modify the _buildBottomBar method
  Widget _buildBottomBar(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    final config = _betterPlayerController!.betterPlayerConfiguration;

    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        alignment: Alignment.bottomCenter,
        margin: EdgeInsets.all(marginSize),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(color: backgroundColor),
            child: _betterPlayerController!.isLiveStream()
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const SizedBox(width: 8),
                      if (config.downloadButtonPosition ==
                          DownloadButtonPosition.bottomLeft)
                        _buildDownloadWidget(
                          backgroundColor,
                          iconColor,
                          barHeight,
                          barHeight * 0.4,
                          8.0,
                        ),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      const SizedBox(width: 8),
                      _buildLiveWidget(),
                      if (config.downloadButtonPosition ==
                          DownloadButtonPosition.bottomRight)
                        _buildDownloadWidget(
                          backgroundColor,
                          iconColor,
                          barHeight,
                          barHeight * 0.4,
                          8.0,
                        ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      if (config.downloadButtonPosition ==
                          DownloadButtonPosition.bottomLeft)
                        _buildDownloadWidget(
                          backgroundColor,
                          iconColor,
                          barHeight,
                          barHeight * 0.4,
                          8.0,
                        ),
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipBack(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipForward(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressText)
                        _buildPosition()
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressBar)
                        _buildProgressBar()
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressText)
                        _buildRemaining()
                      else
                        const SizedBox(),
                      if (config.downloadButtonPosition ==
                          DownloadButtonPosition.bottomRight)
                        _buildDownloadWidget(
                          backgroundColor,
                          iconColor,
                          barHeight,
                          barHeight * 0.4,
                          8.0,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildVideoTracksButton(
    // VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        onVideoTracksClicked();
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                betterPlayerControlsConfiguration.qualitiesIcon,
                // color: betterPlayerControlsConfiguration.iconsColor,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

/*   Widget _buildVideoTracksButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onVideoTracksClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.qualitiesIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  } */

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return InkWell(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 8),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time ...",
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

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    changePlayerControlsNotVisible(false);
    _startHideTimer();
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }
    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);

      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

// Handle fullscreen button exit behavior for Cupertino
  void _onFullScreenButtonExit() {
    // When fullScreenButtonExit is true, behave like the exit button
    _betterPlayerController!.exitPlayer();
    if (_betterPlayerController!.isFullScreen) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _expandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: BetterPlayerCupertinoVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
        if (_betterPlayerController!.betterPlayerDataSource?.liveStream ==
            true) {
          _betterPlayerController!.play();
          _betterPlayerController!.cancelNextVideoTimer();
        }
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
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
          if (isVideoFinished(_latestValue)) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return _controlsConfiguration.loadingWidget;
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }

  Widget _buildPipButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    if (!_controlsConfiguration.enablePip) {
      return const SizedBox();
    }

    return FutureBuilder<bool>(
      future: _betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return GestureDetector(
            onTap: () {
              _onCupertinoPipButtonPressed();
            },
            child: AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: barHeight,
                  padding: EdgeInsets.only(
                    left: buttonPadding,
                    right: buttonPadding,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Icon(
                      _controlsConfiguration.pipMenuIcon,
                      color: iconColor,
                      size: iconSize,
                    ),
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

  ///Enhanced Cupertino PiP button handler with error handling
  void _onCupertinoPipButtonPressed() async {
    if (_betterPlayerController?.betterPlayerGlobalKey != null) {
      try {
        // Check if already in PiP to prevent multiple activations
        if (_betterPlayerController!.isPipActive) {
          await _betterPlayerController!.disablePictureInPicture();
        } else {
          await _betterPlayerController!.enablePictureInPicture(
              _betterPlayerController!.betterPlayerGlobalKey!);
        }
      } catch (e) {
        BetterPlayerUtils.log("Failed to toggle Picture in Picture: $e");
        _showCupertinoPipErrorDialog();
      }
    }
  }

  void _showCupertinoPipErrorDialog() {
    final context =
        _betterPlayerController?.betterPlayerGlobalKey?.currentContext;
    if (context != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Picture in Picture'),
          content: Text('Picture in Picture is not available on this device.'),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}
