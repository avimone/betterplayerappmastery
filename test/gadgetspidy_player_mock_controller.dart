import 'package:gadgetspidy_player/gadgetspidy_player.dart';

class GadgetspidyPlayerMockController extends GadgetspidyPlayerController {
  GadgetspidyPlayerMockController(
    GadgetspidyPlayerConfiguration gadgetspidyPlayerConfiguration, {
    GadgetspidyPlayerPlaylistConfiguration gadgetspidyPlayerPlaylistConfiguration =
        const GadgetspidyPlayerPlaylistConfiguration(),
  }) : super(gadgetspidyPlayerConfiguration,
            gadgetspidyPlayerPlaylistConfiguration:
                gadgetspidyPlayerPlaylistConfiguration);
}
