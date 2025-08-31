import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'gadgetspidy_player_mock_controller.dart';
import 'gadgetspidy_player_test_utils.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets("GadgetspidyPlayer simple player - network",
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWidget(GadgetspidyPlayer.network(
        GadgetspidyPlayerTestUtils.bugBuckBunnyVideoUrl)));
    expect(find.byWidgetPredicate((widget) => widget is GadgetspidyPlayer),
        findsOneWidget);
  });

  testWidgets("GadgetspidyPlayer simple player - file",
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWidget(GadgetspidyPlayer.network(
        GadgetspidyPlayerTestUtils.bugBuckBunnyVideoUrl)));
    expect(find.byWidgetPredicate((widget) => widget is GadgetspidyPlayer),
        findsOneWidget);
  });

  testWidgets("GadgetspidyPlayer - with controller",
      (WidgetTester tester) async {
    final GadgetspidyPlayerMockController gadgetspidyPlayerController =
        GadgetspidyPlayerMockController(const GadgetspidyPlayerConfiguration());
    await tester.pumpWidget(_wrapWidget(GadgetspidyPlayer(
      controller: gadgetspidyPlayerController,
    )));
    expect(find.byWidgetPredicate((widget) => widget is GadgetspidyPlayer),
        findsOneWidget);
  });
}

///Wrap widget with material app to handle all features like navigation and
///localization properly.
Widget _wrapWidget(Widget widget) {
  return MaterialApp(home: widget);
}
