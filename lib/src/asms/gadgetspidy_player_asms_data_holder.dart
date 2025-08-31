import 'package:gadgetspidy_player/src/asms/gadgetspidy_player_asms_audio_track.dart';
import 'package:gadgetspidy_player/src/asms/gadgetspidy_player_asms_subtitle.dart';
import 'package:gadgetspidy_player/src/asms/gadgetspidy_player_asms_track.dart';

class GadgetspidyPlayerAsmsDataHolder {
  List<GadgetspidyPlayerAsmsTrack>? tracks;
  List<GadgetspidyPlayerAsmsSubtitle>? subtitles;
  List<GadgetspidyPlayerAsmsAudioTrack>? audios;

  GadgetspidyPlayerAsmsDataHolder({this.tracks, this.subtitles, this.audios});
}
