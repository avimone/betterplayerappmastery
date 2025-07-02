// better_player_material_controls_v2.dart
import 'package:better_player/better_player.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/core/better_player_controls_base.dart';
import 'package:flutter/material.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  final Function(bool) onControlsVisibilityChanged;
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
      child: Container(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Loading indicator
            if (state.isBuffering) Center(child: buildLoadingIndicator()),

            // Main controls
            AnimatedOpacity(
              opacity: state.controlsVisible ? 1.0 : 0.0,
              duration: controlsConfig.controlsHideTime,
              onEnd: () =>
                  widget.onControlsVisibilityChanged(state.controlsVisible),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildCenterArea()),
                    _buildBottomBar(),
                  ],
                ),
              ),
            ),

            // Next video timer
            _buildNextVideoWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (!controlsConfig.showControls) return const SizedBox();

    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Download button (left)
            if (_shouldShowDownloadButton(DownloadButtonPosition.topLeft))
              _buildDownloadButton(),

            const Spacer(),

            // Right side buttons
            if (controlsConfig.enablePip) _buildPipButton(),

            if (controlsConfig.enableQualities && state.tracks.isNotEmpty)
              IconButton(
                onPressed: showQualitySelection,
                icon: Icon(
                  controlsConfig.qualitiesIcon,
                  color: controlsConfig.iconsColor,
                ),
              ),

            if (controlsConfig.enableOverflowMenu)
              IconButton(
                onPressed: showOverflowMenu,
                icon: Icon(
                  controlsConfig.overflowMenuIcon,
                  color: controlsConfig.iconsColor,
                ),
              ),

            // Download button (right)
            if (_shouldShowDownloadButton(DownloadButtonPosition.topRight))
              _buildDownloadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterArea() {
    if (state.isLive) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Skip back
        if (controlsConfig.enableSkips)
          _buildCenterButton(
            icon: controlsConfig.skipBackIcon,
            onPressed: skipBack,
          ),

        // Play/Pause
        if (controlsConfig.enablePlayPause)
          _buildCenterButton(
            icon: state.isPlaying
                ? controlsConfig.pauseIcon
                : controlsConfig.playIcon,
            onPressed: onPlayPause,
            size: 54,
          ),

        // Skip forward
        if (controlsConfig.enableSkips)
          _buildCenterButton(
            icon: controlsConfig.skipForwardIcon,
            onPressed: skipForward,
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!controlsConfig.showControls) return const SizedBox();

    return SafeArea(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress bar
            if (controlsConfig.enableProgressBar && !state.isLive)
              Expanded(
                child: BetterPlayerMaterialVideoProgressBar(
                  controller.videoPlayerController,
                  controller,
                  colors: BetterPlayerProgressColors(
                    playedColor: controlsConfig.progressBarPlayedColor,
                    handleColor: controlsConfig.progressBarHandleColor,
                    bufferedColor: controlsConfig.progressBarBufferedColor,
                    backgroundColor: controlsConfig.progressBarBackgroundColor,
                  ),
                  onDragStart: () => widget.onControlsVisibilityChanged(false),
                  onDragEnd: () => widget.onControlsVisibilityChanged(true),
                ),
              ),

            const SizedBox(height: 8),

            // Bottom controls row
            Row(
              children: [
                // Download button (left)
                if (_shouldShowDownloadButton(
                    DownloadButtonPosition.bottomLeft))
                  _buildDownloadButton(),

                // Play/Pause (small)
                if (controlsConfig.enablePlayPause)
                  buildPlayPauseButton(size: 24),

                // Time display or LIVE indicator
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: state.isLive
                        ? Text(
                            translations.controlsLive,
                            style: TextStyle(
                              color: controlsConfig.liveTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : buildProgressText(),
                  ),
                ),

                // Volume button
                if (controlsConfig.enableMute) buildMuteButton(size: 24),

                // Download button (right)
                if (_shouldShowDownloadButton(
                    DownloadButtonPosition.bottomRight))
                  _buildDownloadButton(),

                // Fullscreen button
                if (controlsConfig.enableFullscreen)
                  buildFullscreenButton(size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: size,
          color: controlsConfig.iconsColor,
        ),
        iconSize: size,
      ),
    );
  }

  Widget _buildPipButton() {
    return FutureBuilder<bool>(
      future: controller.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox();

        return IconButton(
          onPressed: () => controller.enablePictureInPicture(
            controller.betterPlayerGlobalKey!,
          ),
          icon: Icon(
            controlsConfig.pipMenuIcon,
            color: controlsConfig.iconsColor,
          ),
        );
      },
    );
  }

  Widget _buildDownloadButton() {
    final downloadWidget = config.downloadWidget;
    final downloadFunction = config.downloadFunction;

    if (downloadWidget != null) {
      return downloadWidget;
    }

    if (downloadFunction != null) {
      return IconButton(
        onPressed: () => downloadFunction(),
        icon: Icon(
          Icons.download,
          color: controlsConfig.iconsColor,
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

        return Positioned(
          bottom: 100,
          right: 20,
          child: GestureDetector(
            onTap: () => controller.playNextVideo(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: controlsConfig.controlBarColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${translations.controlsNextVideoIn} $time...",
                style: TextStyle(color: controlsConfig.textColor),
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
