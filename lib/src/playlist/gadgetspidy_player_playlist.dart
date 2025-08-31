import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';

// Flutter imports:
import 'package:flutter/material.dart';

///Special version of Gadgetspidy Player used to play videos in playlist.
class GadgetspidyPlayerPlaylist extends StatefulWidget {
  final List<GadgetspidyPlayerDataSource> gadgetspidyPlayerDataSourceList;
  final GadgetspidyPlayerConfiguration gadgetspidyPlayerConfiguration;
  final GadgetspidyPlayerPlaylistConfiguration
      gadgetspidyPlayerPlaylistConfiguration;

  const GadgetspidyPlayerPlaylist({
    Key? key,
    required this.gadgetspidyPlayerDataSourceList,
    required this.gadgetspidyPlayerConfiguration,
    required this.gadgetspidyPlayerPlaylistConfiguration,
  }) : super(key: key);

  @override
  GadgetspidyPlayerPlaylistState createState() =>
      GadgetspidyPlayerPlaylistState();
}

///State of GadgetspidyPlayerPlaylist, used to access GadgetspidyPlayerPlaylistController.
class GadgetspidyPlayerPlaylistState extends State<GadgetspidyPlayerPlaylist> {
  GadgetspidyPlayerPlaylistController? _gadgetspidyPlayerPlaylistController;

  GadgetspidyPlayerController? get _gadgetspidyPlayerController =>
      _gadgetspidyPlayerPlaylistController!.gadgetspidyPlayerController;

  ///Get GadgetspidyPlayerPlaylistController
  GadgetspidyPlayerPlaylistController?
      get gadgetspidyPlayerPlaylistController =>
          _gadgetspidyPlayerPlaylistController;

  @override
  void initState() {
    _gadgetspidyPlayerPlaylistController = GadgetspidyPlayerPlaylistController(
        widget.gadgetspidyPlayerDataSourceList,
        gadgetspidyPlayerConfiguration: widget.gadgetspidyPlayerConfiguration,
        gadgetspidyPlayerPlaylistConfiguration:
            widget.gadgetspidyPlayerPlaylistConfiguration);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _gadgetspidyPlayerController!.getAspectRatio() ??
          GadgetspidyPlayerUtils.calculateAspectRatio(context),
      child: GadgetspidyPlayer(
        controller: _gadgetspidyPlayerController!,
      ),
    );
  }

  @override
  void dispose() {
    _gadgetspidyPlayerPlaylistController!.dispose();
    super.dispose();
  }
}
