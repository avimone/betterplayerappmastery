// better_player_material_controls_v2.dart
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// Simplified Material Controls using the new architecture
class BetterPlayerMaterialControls extends StatefulWidget {
  final Function(bool visibility) onControlsVisibilityChanged;
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<BetterPlayerMaterialControls> createState() =>
      _BetterPlayerMaterialControlsState();
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsBase<BetterPlayerMaterialControls> {
  @override
  Widget buildControls(BuildContext context) {
    if (!shouldShowControls) {
      return const SizedBox();
    }

    final state = controller.state;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Loading indicator
        if (state.isBuffering)
          Center(
            child: _buildLoadingWidget(),
          ),

        // Error widget
        if (state.hasError) _buildErrorWidget(),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),

        // Center controls
        if (!state.isBuffering && !state.hasError) _buildCenterControls(),

        // Bottom bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(),
        ),

        // Next video widget
        if (controller.betterPlayerPlaylistConfiguration != null)
          Positioned(
            bottom: config.controlBarHeight + 30,
            right: 16,
            child: _buildNextVideoWidget(),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    final hasContent = _shouldShowTopBar();

    if (!hasContent) {
      return const SizedBox();
    }

    return AnimatedOpacity(
      opacity: controller.state.controlsVisible ? 1.0 : 0.0,
      duration: config.controlsHideTime,
      child: Container(
        height: config.controlBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              config.controlBarColor,
              config.controlBarColor.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // Back button
            _buildIconButton(
              icon: Icons.arrow_back,
              onTap: () => controller.exitPlayer(),
            ),

            const Spacer(),

            // Download button (if position is top)
            if (_shouldShowDownloadButton(true)) _buildDownloadButton(),

            // Quality button
            if (config.enableQualities)
              _buildIconButton(
                icon: config.qualitiesIcon,
                onTap: showQualitySelection,
              ),

            // PiP button
            if (config.enablePip) _buildPipButton(),

            // Overflow menu
            if (config.enableOverflowMenu)
              _buildIconButton(
                icon: config.overflowMenuIcon,
                onTap: showOverflowMenu,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return AnimatedOpacity(
      opacity: controller.state.controlsVisible ? 1.0 : 0.0,
      duration: config.controlsHideTime,
      child: Container(
        color: config.controlBarColor.withOpacity(0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Skip back
            if (config.enableSkips && !controller.isLiveStream())
              _buildCenterButton(
                icon: config.skipBackIcon,
                onTap: skipBack,
              ),

            // Play/pause
            if (config.enablePlayPause)
              _buildCenterButton(
                icon: _getPlayPauseIcon(),
                onTap: () {
                  if (isVideoFinished) {
                    controller.seekTo(Duration.zero);
                  }
                  if (controller.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                size: 50,
              ),

            // Skip forward
            if (config.enableSkips && !controller.isLiveStream())
              _buildCenterButton(
                icon: config.skipForwardIcon,
                onTap: skipForward,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return AnimatedOpacity(
      opacity: controller.state.controlsVisible ? 1.0 : 0.0,
      duration: config.controlsHideTime,
      onEnd: () {
        widget.onControlsVisibilityChanged(controller.state.controlsVisible);
      },
      child: Container(
        height: config.controlBarHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              config.controlBarColor,
              config.controlBarColor.withOpacity(0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            if (config.enableProgressBar && !controller.isLiveStream())
              _buildProgressBar(),

            // Controls row
            Expanded(
              child: Row(
                children: [
                  // Play/pause button
                  if (config.enablePlayPause)
                    _buildIconButton(
                      icon: controller.isPlaying
                          ? config.pauseIcon
                          : config.playIcon,
                      onTap: () {
                        if (controller.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      },
                    ),

                  // Position text or live indicator
                  if (controller.isLiveStream())
                    _buildLiveIndicator()
                  else if (config.enableProgressText)
                    _buildPositionText(),

                  const Spacer(),

                  // Download button (if position is bottom)
                  if (_shouldShowDownloadButton(false)) _buildDownloadButton(),

                  // Mute button
                  if (config.enableMute)
                    _buildIconButton(
                      icon: controller.volume > 0
                          ? config.muteIcon
                          : config.unMuteIcon,
                      onTap: () {
                        if (controller.volume > 0) {
                          controller.setVolume(0);
                        } else {
                          controller.setVolume(1);
                        }
                      },
                    ),

                  // Fullscreen button
                  if (config.enableFullscreen)
                    _buildIconButton(
                      icon: controller.isFullScreen
                          ? config.fullscreenDisableIcon
                          : config.fullscreenEnableIcon,
                      onTap: () => controller.toggleFullScreen(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: config.iconsColor,
            size: config.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 40,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size * 1.5,
          height: size * 1.5,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: config.iconsColor,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      height: 20,
      child: BetterPlayerMaterialVideoProgressBar(
        controller.videoPlayerController,
        controller,
        onDragStart: () {
          controller.setControlsVisibility(true);
        },
        onDragEnd: () {
          controller.setControlsVisibility(true);
        },
        colors: BetterPlayerProgressColors(
          playedColor: config.progressBarPlayedColor,
          handleColor: config.progressBarHandleColor,
          bufferedColor: config.progressBarBufferedColor,
          backgroundColor: config.progressBarBackgroundColor,
        ),
      ),
    );
  }

  Widget _buildPositionText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '${formatDuration(controller.position)} / ${formatDuration(controller.duration)}',
        style: config.timeBarStyle,
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.liveTextColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        controller.translations.controlsLive,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return config.loadingWidget ??
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(config.loadingColor),
        );
  }

  Widget _buildErrorWidget() {
    final error = controller.state.error;
    if (error == null) return const SizedBox();

    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: config.iconsColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              error.userFriendlyMessage,
              style: TextStyle(color: config.textColor),
              textAlign: TextAlign.center,
            ),
            if (config.enableRetry && error.isRecoverable) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => controller.retryDataSource(),
                child: Text(
                  controller.translations.generalRetry,
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: controller.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time == null || time <= 0) {
          return const SizedBox();
        }

        return Material(
          color: config.controlBarColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => controller.playNextVideo(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${controller.translations.controlsNextVideoIn} $time...',
                style: TextStyle(color: config.textColor),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadButton() {
    final downloadConfig = controller.betterPlayerConfiguration;

    if (downloadConfig.downloadWidget != null) {
      return downloadConfig.downloadWidget!;
    }

    if (downloadConfig.downloadFunction != null) {
      return _buildIconButton(
        icon: Icons.download_outlined,
        onTap: () => downloadConfig.downloadFunction!(),
      );
    }

    return const SizedBox();
  }

  Widget _buildPipButton() {
    return FutureBuilder<bool>(
      future: controller.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox();
        }

        return _buildIconButton(
          icon: config.pipMenuIcon,
          onTap: () {
            if (controller.betterPlayerGlobalKey != null) {
              controller.enablePictureInPicture(
                controller.betterPlayerGlobalKey!,
              );
            }
          },
        );
      },
    );
  }

  bool _shouldShowTopBar() {
    return config.enableOverflowMenu ||
        config.enableQualities ||
        config.enablePip ||
        _shouldShowDownloadButton(true);
  }

  bool _shouldShowDownloadButton(bool isTop) {
    final downloadConfig = controller.betterPlayerConfiguration;
    final hasDownload = downloadConfig.downloadWidget != null ||
        downloadConfig.downloadFunction != null;

    if (!hasDownload) return false;

    final position = downloadConfig.downloadButtonPosition;

    if (isTop) {
      return position == DownloadButtonPosition.topLeft ||
          position == DownloadButtonPosition.topRight;
    } else {
      return position == DownloadButtonPosition.bottomLeft ||
          position == DownloadButtonPosition.bottomRight;
    }
  }

  IconData _getPlayPauseIcon() {
    if (isVideoFinished) {
      return Icons.replay;
    }
    return controller.isPlaying ? config.pauseIcon : config.playIcon;
  }
}
