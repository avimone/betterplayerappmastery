// better_player_cupertino_controls_v2.dart
import 'package:better_player/better_player.dart';
import 'package:better_player/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player/src/core/better_player_controls_base.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BetterPlayerCupertinoControls extends StatefulWidget {
  final Function(bool) onControlsVisibilityChanged;
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerCupertinoControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<BetterPlayerCupertinoControls> createState() =>
      _BetterPlayerCupertinoControlsState();
}

class _BetterPlayerCupertinoControlsState
    extends BetterPlayerControlsBase<BetterPlayerCupertinoControls> {
  @override
  Widget build(BuildContext context) {
    final isFullScreen = controller.isFullScreen;
    final orientation = MediaQuery.of(context).orientation;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: buildControls(context),
    );
  }

  @override
  Widget buildControls(BuildContext context) {
    // Handle error state
    if (state.hasError) {
      return Container(
        color: Colors.black,
        child: buildErrorWidget(),
      );
    }

    return GestureDetector(
      onTap: onControlsTap,
      onDoubleTap: onPlayPause,
      child: AbsorbPointer(
        absorbing: !state.controlsVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Loading indicator
            if (state.isBuffering) Center(child: buildLoadingIndicator()),

            // Main controls container
            Column(
              children: [
                _buildTopBar(),
                if (state.isBuffering)
                  Expanded(child: Center(child: buildLoadingIndicator()))
                else
                  _buildHitArea(),
                _buildNextVideoWidget(),
                _buildBottomBar(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (!controller.controlsEnabled || !controlsConfig.showControls) {
      return const SizedBox();
    }

    final barHeight = controlsConfig.controlBarHeight * 0.8;
    const buttonPadding = 10.0;

    return AnimatedOpacity(
      opacity: state.controlsVisible ? 1.0 : 0.0,
      duration: controlsConfig.controlsHideTime,
      child: Container(
        height: barHeight,
        margin: const EdgeInsets.only(top: 5, right: 5, left: 5),
        child: Row(
          children: [
            // Exit button
            _buildTopBarButton(
              icon: Icons.close,
              onPressed: () => controller.exitPlayer(),
              barHeight: barHeight,
              buttonPadding: buttonPadding,
            ),

            const SizedBox(width: 4),

            // Download button (left)
            if (_shouldShowDownloadButton(DownloadButtonPosition.topLeft))
              _buildDownloadButton(barHeight, buttonPadding),

            const SizedBox(width: 4),

            // Fullscreen button
            if (controlsConfig.enableFullscreen)
              _buildTopBarButton(
                icon: state.isFullScreen
                    ? controlsConfig.fullscreenDisableIcon
                    : controlsConfig.fullscreenEnableIcon,
                onPressed: toggleFullscreen,
                barHeight: barHeight,
                buttonPadding: buttonPadding,
              ),

            const SizedBox(width: 4),

            // PiP button
            if (controlsConfig.enablePip)
              _buildPipButton(barHeight, buttonPadding),

            const SizedBox(width: 4),

            // Quality button
            if (controlsConfig.enableQualities && state.tracks.isNotEmpty)
              _buildTopBarButton(
                icon: controlsConfig.qualitiesIcon,
                onPressed: showQualitySelection,
                barHeight: barHeight,
                buttonPadding: buttonPadding,
              ),

            const Spacer(),

            // Download button (right)
            if (_shouldShowDownloadButton(DownloadButtonPosition.topRight))
              _buildDownloadButton(barHeight, buttonPadding),

            const SizedBox(width: 4),

            // Mute button
            if (controlsConfig.enableMute)
              _buildTopBarButton(
                icon: state.volume > 0
                    ? controlsConfig.muteIcon
                    : controlsConfig.unMuteIcon,
                onPressed: toggleMute,
                barHeight: barHeight,
                buttonPadding: buttonPadding,
              ),

            const SizedBox(width: 4),

            // More button
            if (controlsConfig.enableOverflowMenu)
              _buildTopBarButton(
                icon: controlsConfig.overflowMenuIcon,
                onPressed: showOverflowMenu,
                barHeight: barHeight,
                buttonPadding: buttonPadding,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        onTap: state.isPlaying
            ? onControlsTap
            : () => controller.setControlsVisibility(true),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!controller.controlsEnabled || !controlsConfig.showControls) {
      return const SizedBox();
    }

    final barHeight = controlsConfig.controlBarHeight;

    return AnimatedOpacity(
      opacity: state.controlsVisible ? 1.0 : 0.0,
      duration: controlsConfig.controlsHideTime,
      onEnd: () => widget.onControlsVisibilityChanged(state.controlsVisible),
      child: Container(
        alignment: Alignment.bottomCenter,
        margin: const EdgeInsets.all(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(color: controlsConfig.controlBarColor),
            child: state.isLive ? _buildLiveControls() : _buildVodControls(),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 8),

        // Download button (left)
        if (_shouldShowDownloadButton(DownloadButtonPosition.bottomLeft))
          _buildDownloadButton(controlsConfig.controlBarHeight, 8.0),

        // Play/Pause
        if (controlsConfig.enablePlayPause) _buildPlayPauseButton(),

        const SizedBox(width: 8),

        // LIVE indicator
        Expanded(
          child: Text(
            translations.controlsLive,
            style: TextStyle(
              color: controlsConfig.liveTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Download button (right)
        if (_shouldShowDownloadButton(DownloadButtonPosition.bottomRight))
          _buildDownloadButton(controlsConfig.controlBarHeight, 8.0),
      ],
    );
  }

  Widget _buildVodControls() {
    return Row(
      children: [
        // Download button (left)
        if (_shouldShowDownloadButton(DownloadButtonPosition.bottomLeft))
          _buildDownloadButton(controlsConfig.controlBarHeight, 8.0),

        // Skip back
        if (controlsConfig.enableSkips)
          _buildSkipButton(
            icon: controlsConfig.skipBackIcon,
            onPressed: skipBack,
          ),

        // Play/Pause
        if (controlsConfig.enablePlayPause) _buildPlayPauseButton(),

        // Skip forward
        if (controlsConfig.enableSkips)
          _buildSkipButton(
            icon: controlsConfig.skipForwardIcon,
            onPressed: skipForward,
          ),

        // Position text
        if (controlsConfig.enableProgressText) _buildPositionText(),

        // Progress bar
        if (controlsConfig.enableProgressBar) _buildProgressBar(),

        // Remaining text
        if (controlsConfig.enableProgressText) _buildRemainingText(),

        // Download button (right)
        if (_shouldShowDownloadButton(DownloadButtonPosition.bottomRight))
          _buildDownloadButton(controlsConfig.controlBarHeight, 8.0),
      ],
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double barHeight,
    required double buttonPadding,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: barHeight,
          padding: EdgeInsets.symmetric(horizontal: buttonPadding),
          decoration: BoxDecoration(color: controlsConfig.controlBarColor),
          child: Center(
            child: Icon(
              icon,
              color: controlsConfig.iconsColor,
              size: barHeight * 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: onPlayPause,
      child: Container(
        height: controlsConfig.controlBarHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          state.isPlaying ? controlsConfig.pauseIcon : controlsConfig.playIcon,
          color: controlsConfig.iconsColor,
          size: controlsConfig.controlBarHeight * 0.6,
        ),
      ),
    );
  }

  Widget _buildSkipButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: controlsConfig.controlBarHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          icon,
          color: controlsConfig.iconsColor,
          size: controlsConfig.controlBarHeight * 0.4,
        ),
      ),
    );
  }

  Widget _buildPositionText() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        BetterPlayerUtils.formatDuration(state.position),
        style: TextStyle(
          color: controlsConfig.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  Widget _buildRemainingText() {
    final remaining = state.duration - state.position;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(remaining)}',
        style: TextStyle(
          color: controlsConfig.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: BetterPlayerCupertinoVideoProgressBar(
          controller.videoPlayerController,
          controller,
          onDragStart: () => widget.onControlsVisibilityChanged(false),
          onDragEnd: () => widget.onControlsVisibilityChanged(true),
          onTapDown: () => controller.setControlsVisibility(true),
          colors: BetterPlayerProgressColors(
            playedColor: controlsConfig.progressBarPlayedColor,
            handleColor: controlsConfig.progressBarHandleColor,
            bufferedColor: controlsConfig.progressBarBufferedColor,
            backgroundColor: controlsConfig.progressBarBackgroundColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPipButton(double barHeight, double buttonPadding) {
    return FutureBuilder<bool>(
      future: controller.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        if (snapshot.data != true || controller.betterPlayerGlobalKey == null) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: () => controller.enablePictureInPicture(
            controller.betterPlayerGlobalKey!,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(horizontal: buttonPadding),
              decoration: BoxDecoration(
                color: controlsConfig.controlBarColor.withOpacity(0.5),
              ),
              child: Center(
                child: Icon(
                  controlsConfig.pipMenuIcon,
                  color: controlsConfig.iconsColor,
                  size: barHeight * 0.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadButton(double barHeight, double buttonPadding) {
    final downloadWidget = config.downloadWidget;
    final downloadFunction = config.downloadFunction;

    if (downloadWidget != null) {
      return AnimatedOpacity(
        opacity: state.controlsVisible ? 1.0 : 0.0,
        duration: controlsConfig.controlsHideTime,
        child: downloadWidget,
      );
    }

    if (downloadFunction != null) {
      return GestureDetector(
        onTap: () => downloadFunction(),
        child: AnimatedOpacity(
          opacity: state.controlsVisible ? 1.0 : 0.0,
          duration: controlsConfig.controlsHideTime,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(horizontal: buttonPadding),
              decoration: BoxDecoration(color: controlsConfig.controlBarColor),
              child: Center(
                child: Icon(
                  Icons.download_outlined,
                  color: controlsConfig.iconsColor,
                  size: barHeight * 0.4,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: controller.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time == null || time <= 0) return const SizedBox();

        return InkWell(
          onTap: () => controller.playNextVideo(),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4, right: 8),
              decoration: BoxDecoration(
                color: controlsConfig.controlBarColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "${translations.controlsNextVideoIn} $time ...",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldShowDownloadButton(DownloadButtonPosition position) {
    return config.downloadButtonPosition == position &&
        (config.downloadWidget != null || config.downloadFunction != null);
  }
}
