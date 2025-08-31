import 'package:gadgetspidy_player/src/core/gadgetspidy_player_controller.dart';
import 'package:flutter/material.dart';

///Widget which is used to inherit GadgetspidyPlayerController through widget tree.
class GadgetspidyPlayerControllerProvider extends InheritedWidget {
  const GadgetspidyPlayerControllerProvider({
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  final GadgetspidyPlayerController controller;

  @override
  bool updateShouldNotify(GadgetspidyPlayerControllerProvider old) =>
      controller != old.controller;
}
