import 'package:flutter/material.dart';

///Helper class for GestureDetector used within Gadgetspidy Player. Used to pass
///gestures to upper GestureDetectors.
class GadgetspidyPlayerMultipleGestureDetector extends InheritedWidget {
  final void Function()? onTap;
  final void Function()? onDoubleTap;
  final void Function()? onLongPress;

  const GadgetspidyPlayerMultipleGestureDetector({
    Key? key,
    required Widget child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  }) : super(key: key, child: child);

  static GadgetspidyPlayerMultipleGestureDetector? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<
        GadgetspidyPlayerMultipleGestureDetector>();
  }

  @override
  bool updateShouldNotify(GadgetspidyPlayerMultipleGestureDetector oldWidget) =>
      false;
}
