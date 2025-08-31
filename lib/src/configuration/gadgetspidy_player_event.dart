import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_event_type.dart';

///Event that happens in player. It can be used to determine current player state
///on higher layer.
class GadgetspidyPlayerEvent {
  final GadgetspidyPlayerEventType gadgetspidyPlayerEventType;
  final Map<String, dynamic>? parameters;

  GadgetspidyPlayerEvent(this.gadgetspidyPlayerEventType, {this.parameters});
}
