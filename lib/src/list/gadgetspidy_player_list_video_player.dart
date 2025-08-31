import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'package:flutter/material.dart';

///Special version of Gadgetspidy Player which is used to play video in list view.
class GadgetspidyPlayerListVideoPlayer extends StatefulWidget {
  ///Video to show
  final GadgetspidyPlayerDataSource dataSource;

  ///Video player configuration
  final GadgetspidyPlayerConfiguration configuration;

  ///Fraction of the screen height that will trigger play/pause. For example
  ///if playFraction is 0.6 video will be played if 60% of player height is
  ///visible.
  final double playFraction;

  ///Flag to determine if video should be auto played
  final bool autoPlay;

  ///Flag to determine if video should be auto paused
  final bool autoPause;

  final GadgetspidyPlayerListVideoPlayerController?
      gadgetspidyPlayerListVideoPlayerController;

  const GadgetspidyPlayerListVideoPlayer(
    this.dataSource, {
    this.configuration = const GadgetspidyPlayerConfiguration(),
    this.playFraction = 0.6,
    this.autoPlay = true,
    this.autoPause = true,
    this.gadgetspidyPlayerListVideoPlayerController,
    Key? key,
  })  : assert(playFraction >= 0.0 && playFraction <= 1.0,
            "Play fraction can't be null and must be between 0.0 and 1.0"),
        super(key: key);

  @override
  _GadgetspidyPlayerListVideoPlayerState createState() =>
      _GadgetspidyPlayerListVideoPlayerState();
}

class _GadgetspidyPlayerListVideoPlayerState
    extends State<GadgetspidyPlayerListVideoPlayer>
    with AutomaticKeepAliveClientMixin<GadgetspidyPlayerListVideoPlayer> {
  GadgetspidyPlayerController? _gadgetspidyPlayerController;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _gadgetspidyPlayerController = GadgetspidyPlayerController(
      widget.configuration.copyWith(
        playerVisibilityChangedBehavior: onVisibilityChanged,
      ),
      gadgetspidyPlayerDataSource: widget.dataSource,
      gadgetspidyPlayerPlaylistConfiguration:
          const GadgetspidyPlayerPlaylistConfiguration(),
    );

    if (widget.gadgetspidyPlayerListVideoPlayerController != null) {
      widget.gadgetspidyPlayerListVideoPlayerController!
          .setGadgetspidyPlayerController(_gadgetspidyPlayerController);
    }
  }

  @override
  void dispose() {
    _gadgetspidyPlayerController!.dispose();
    _isDisposing = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AspectRatio(
      aspectRatio: _gadgetspidyPlayerController!.getAspectRatio() ??
          GadgetspidyPlayerUtils.calculateAspectRatio(context),
      child: GadgetspidyPlayer(
        key: Key("${_getUniqueKey()}_player"),
        controller: _gadgetspidyPlayerController!,
      ),
    );
  }

  void onVisibilityChanged(double visibleFraction) async {
    final bool? isPlaying = _gadgetspidyPlayerController!.isPlaying();
    final bool? initialized =
        _gadgetspidyPlayerController!.isVideoInitialized();
    if (visibleFraction >= widget.playFraction) {
      if (widget.autoPlay && initialized! && !isPlaying! && !_isDisposing) {
        _gadgetspidyPlayerController!.play();
      }
    } else {
      if (widget.autoPause && initialized! && isPlaying! && !_isDisposing) {
        _gadgetspidyPlayerController!.pause();
      }
    }
  }

  String _getUniqueKey() => widget.dataSource.hashCode.toString();

  @override
  bool get wantKeepAlive => true;
}
