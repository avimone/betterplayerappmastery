import 'package:gadgetspidy_player/gadgetspidy_player.dart';

///Controller of Gadgetspidy Player List Video Player.
class GadgetspidyPlayerListVideoPlayerController {
  GadgetspidyPlayerController? _gadgetspidyPlayerController;

  void setVolume(double volume) {
    _gadgetspidyPlayerController?.setVolume(volume);
  }

  void pause() {
    _gadgetspidyPlayerController?.pause();
  }

  void play() {
    _gadgetspidyPlayerController?.play();
  }

  void seekTo(Duration duration) {
    _gadgetspidyPlayerController?.seekTo(duration);
  }

  // ignore: use_setters_to_change_properties
  void setGadgetspidyPlayerController(
      GadgetspidyPlayerController? gadgetspidyPlayerController) {
    _gadgetspidyPlayerController = gadgetspidyPlayerController;
  }

  void setMixWithOthers(bool mixWithOthers) {
    _gadgetspidyPlayerController?.setMixWithOthers(mixWithOthers);
  }
}
