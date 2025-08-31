import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'gadgetspidy_player_mock_controller.dart';
import 'gadgetspidy_player_test_utils.dart';
import 'mock_method_channel.dart';
import 'mock_video_player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final MockMethodChannel mockMethodChannel = MockMethodChannel();

  group(
    "GadgetspidyPlayerController tests",
    () {
      setUp(
        () => {
          TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
              .setMockMethodCallHandler(
                  mockMethodChannel.channel, mockMethodChannel.handle)
        },
      );

      test("Create controller without data source", () {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerMockController(
                const GadgetspidyPlayerConfiguration());
        expect(
            gadgetspidyPlayerMockController.gadgetspidyPlayerDataSource, null);
        expect(gadgetspidyPlayerMockController.videoPlayerController, null);
      });

      test("Setup data source in controller", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerMockController(
                const GadgetspidyPlayerConfiguration());
        await gadgetspidyPlayerMockController.setupDataSource(
            GadgetspidyPlayerDataSource.network(
                GadgetspidyPlayerTestUtils.forBiggerBlazesUrl));
        expect(
            gadgetspidyPlayerMockController.gadgetspidyPlayerDataSource != null,
            true);
        expect(gadgetspidyPlayerMockController.videoPlayerController != null,
            true);
      });

      test(
        "play should change isPlaying flag",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          gadgetspidyPlayerController.videoPlayerController =
              videoPlayerController;
          await Future.delayed(const Duration(seconds: 1), () {});
          gadgetspidyPlayerController.play();
          expect(gadgetspidyPlayerController.isPlaying(), true);
        },
      );

      test(
        "pause should change isPlaying flag",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          gadgetspidyPlayerController.videoPlayerController =
              videoPlayerController;
          await Future.delayed(const Duration(seconds: 1), () {});
          gadgetspidyPlayerController.play();
          expect(gadgetspidyPlayerController.isPlaying(), true);
          gadgetspidyPlayerController.pause();
          expect(gadgetspidyPlayerController.isPlaying(), false);
        },
      );

      test(
        "seekTo should change player position",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          videoPlayerController.setDuration(const Duration(seconds: 100));
          gadgetspidyPlayerController.videoPlayerController =
              videoPlayerController;
          gadgetspidyPlayerController.seekTo(const Duration(seconds: 5));
          Duration? position =
              await gadgetspidyPlayerController.videoPlayerController!.position;
          expect(position, const Duration(seconds: 5));
          gadgetspidyPlayerController.seekTo(const Duration(seconds: 30));
          position =
              await gadgetspidyPlayerController.videoPlayerController!.position;
          expect(position, const Duration(seconds: 30));
        },
      );

      test(
        "seekTo should send event",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          videoPlayerController.setDuration(const Duration(seconds: 100));
          gadgetspidyPlayerController.videoPlayerController =
              videoPlayerController;

          int seekEventCalls = 0;
          int finishEventCalls = 0;
          gadgetspidyPlayerController.addEventsListener((event) {
            if (event.gadgetspidyPlayerEventType ==
                GadgetspidyPlayerEventType.seekTo) {
              seekEventCalls += 1;
            }
            if (event.gadgetspidyPlayerEventType ==
                GadgetspidyPlayerEventType.finished) {
              finishEventCalls += 1;
            }
          });
          gadgetspidyPlayerController.seekTo(const Duration(seconds: 5));
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(seekEventCalls, 1);
          gadgetspidyPlayerController.seekTo(const Duration(seconds: 150));
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(seekEventCalls, 2);
          expect(finishEventCalls, 1);
        },
      );

      test("full screen and auto play should work", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerMockController(
          const GadgetspidyPlayerConfiguration(
              fullScreenByDefault: true, autoPlay: true),
        );
        gadgetspidyPlayerMockController.videoPlayerController =
            MockVideoPlayerController();
        await gadgetspidyPlayerMockController.setupDataSource(
          GadgetspidyPlayerDataSource.network(
              GadgetspidyPlayerTestUtils.forBiggerBlazesUrl),
        );
        await Future.delayed(const Duration(seconds: 1), () {});
        expect(gadgetspidyPlayerMockController.isFullScreen, true);
        expect(gadgetspidyPlayerMockController.isPlaying(), true);
      });

      test("exitFullScreen should exit full screen", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController(
          controller: MockVideoPlayerController(),
        );
        expect(gadgetspidyPlayerMockController.isFullScreen, false);
        gadgetspidyPlayerMockController.exitFullScreen();
        expect(gadgetspidyPlayerMockController.isFullScreen, false);
      });

      test("enterFullScreen should enter full screen", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        await gadgetspidyPlayerMockController.setupDataSource(
          GadgetspidyPlayerDataSource.network(
              GadgetspidyPlayerTestUtils.forBiggerBlazesUrl),
        );
        expect(gadgetspidyPlayerMockController.isFullScreen, false);
        gadgetspidyPlayerMockController.enterFullScreen();
        expect(gadgetspidyPlayerMockController.isFullScreen, true);
      });

      test("toggleFullScreen should change full screen state", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        await gadgetspidyPlayerMockController.setupDataSource(
          GadgetspidyPlayerDataSource.network(
              GadgetspidyPlayerTestUtils.forBiggerBlazesUrl),
        );

        expect(gadgetspidyPlayerMockController.isFullScreen, false);
        gadgetspidyPlayerMockController.toggleFullScreen();
        expect(gadgetspidyPlayerMockController.isFullScreen, true);
        gadgetspidyPlayerMockController.toggleFullScreen();
        expect(gadgetspidyPlayerMockController.isFullScreen, false);
      });

      test("setLooping changes looping state", () async {
        final mockVideoPlayerController = MockVideoPlayerController();
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        mockVideoPlayerController.setNetworkDataSource(
            GadgetspidyPlayerTestUtils.bugBuckBunnyVideoUrl);

        gadgetspidyPlayerMockController.videoPlayerController =
            mockVideoPlayerController;
        expect(mockVideoPlayerController.isLoopingState, false);
        gadgetspidyPlayerMockController.setLooping(true);
        expect(mockVideoPlayerController.isLoopingState, true);
        gadgetspidyPlayerMockController.setLooping(false);
        expect(mockVideoPlayerController.isLoopingState, false);
      });

      test("setControlsVisibility updates controlVisiblityStream", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        var showCalls = 0;
        var hideCalls = 0;
        gadgetspidyPlayerMockController.controlsVisibilityStream
            .listen((event) {
          if (event) {
            showCalls += 1;
          } else {
            hideCalls += 1;
          }
        });
        gadgetspidyPlayerMockController.setControlsVisibility(false);
        gadgetspidyPlayerMockController.setControlsVisibility(false);
        gadgetspidyPlayerMockController.setControlsVisibility(true);
        gadgetspidyPlayerMockController.setControlsVisibility(true);
        gadgetspidyPlayerMockController.setControlsVisibility(false);
        await Future.delayed(const Duration(milliseconds: 100), () {});
        expect(hideCalls, 3);
        expect(showCalls, 2);
      });

      test("setControlsEnabled updates values correctly", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        var hideCalls = 0;
        gadgetspidyPlayerMockController.controlsVisibilityStream
            .listen((event) {
          hideCalls += 1;
        });
        gadgetspidyPlayerMockController.setControlsEnabled(false);
        gadgetspidyPlayerMockController.setControlsEnabled(false);
        await Future.delayed(const Duration(milliseconds: 100), () {});
        expect(hideCalls, 2);
        expect(gadgetspidyPlayerMockController.controlsEnabled, false);
        gadgetspidyPlayerMockController.setControlsEnabled(true);
        expect(gadgetspidyPlayerMockController.controlsEnabled, true);
      });

      test("toggleControlsVisibility sends correct events", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        var controlsVisibleEventCount = 0;
        var controlsHiddenEventCount = 0;
        gadgetspidyPlayerMockController.addEventsListener((event) {
          if (event.gadgetspidyPlayerEventType ==
              GadgetspidyPlayerEventType.controlsVisible) {
            controlsVisibleEventCount += 1;
          }
          if (event.gadgetspidyPlayerEventType ==
              GadgetspidyPlayerEventType.controlsHiddenEnd) {
            controlsHiddenEventCount += 1;
          }
        });
        gadgetspidyPlayerMockController.toggleControlsVisibility(false);
        gadgetspidyPlayerMockController.toggleControlsVisibility(true);
        gadgetspidyPlayerMockController.toggleControlsVisibility(true);
        await Future.delayed(const Duration(milliseconds: 100), () {});
        expect(controlsVisibleEventCount, 2);
        expect(controlsHiddenEventCount, 1);
      });

      test("postEvent sends events to listeners", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();

        int firstEventCounter = 0;
        int secondEventCounter = 0;

        gadgetspidyPlayerMockController.addEventsListener((event) {
          firstEventCounter++;
        });
        gadgetspidyPlayerMockController.addEventsListener((event) {
          secondEventCounter++;
        });
        gadgetspidyPlayerMockController
            .postEvent(GadgetspidyPlayerEvent(GadgetspidyPlayerEventType.play));
        gadgetspidyPlayerMockController.postEvent(
            GadgetspidyPlayerEvent(GadgetspidyPlayerEventType.progress));

        gadgetspidyPlayerMockController.postEvent(
            GadgetspidyPlayerEvent(GadgetspidyPlayerEventType.pause));
        await Future.delayed(const Duration(milliseconds: 100), () {});
        expect(firstEventCounter, 3);
        expect(secondEventCounter, 3);
      });

      test("addEventsListener update list of event listener", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        gadgetspidyPlayerMockController.addEventsListener((event) {});
        gadgetspidyPlayerMockController.addEventsListener((event) {});
        expect(gadgetspidyPlayerMockController.eventListeners.length, 2);
      });

      void dummyEventListener(GadgetspidyPlayerEvent event) {}

      test("removeEventsListener update list of event listener", () async {
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        gadgetspidyPlayerMockController.addEventsListener(dummyEventListener);
        gadgetspidyPlayerMockController.addEventsListener((event) {});
        expect(gadgetspidyPlayerMockController.eventListeners.length, 2);
        gadgetspidyPlayerMockController
            .removeEventsListener(dummyEventListener);
        expect(gadgetspidyPlayerMockController.eventListeners.length, 1);
      });

      test("setVolume changes volume", () async {
        final mockVideoPlayerController = MockVideoPlayerController();
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        mockVideoPlayerController.setNetworkDataSource(
            GadgetspidyPlayerTestUtils.bugBuckBunnyVideoUrl);
        gadgetspidyPlayerMockController.videoPlayerController =
            mockVideoPlayerController;
        gadgetspidyPlayerMockController.setVolume(1.0);
        expect(mockVideoPlayerController.volume, 1.0);
        gadgetspidyPlayerMockController.setVolume(0.5);
        expect(mockVideoPlayerController.volume, 0.5);
      });

      test(
        "setVolume should send event",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerMockController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          gadgetspidyPlayerMockController.videoPlayerController =
              videoPlayerController;

          int setVolumeCalls = 0;
          gadgetspidyPlayerMockController.addEventsListener((event) {
            if (event.gadgetspidyPlayerEventType ==
                GadgetspidyPlayerEventType.setVolume) {
              setVolumeCalls += 1;
            }
          });
          gadgetspidyPlayerMockController.setVolume(1.0);
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(setVolumeCalls, 1);
          gadgetspidyPlayerMockController.setVolume(1.0);
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(setVolumeCalls, 2);
        },
      );

      test("setSpeed changes speed", () async {
        final mockVideoPlayerController = MockVideoPlayerController();
        final GadgetspidyPlayerMockController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        mockVideoPlayerController.setNetworkDataSource(
            GadgetspidyPlayerTestUtils.bugBuckBunnyVideoUrl);
        gadgetspidyPlayerMockController.videoPlayerController =
            mockVideoPlayerController;
        gadgetspidyPlayerMockController.setSpeed(1.1);
        expect(mockVideoPlayerController.speed, 1.1);
        gadgetspidyPlayerMockController.setSpeed(0.5);
        expect(mockVideoPlayerController.speed, 0.5);
        expect(() => gadgetspidyPlayerMockController.setSpeed(2.5),
            throwsA(isA<ArgumentError>()));
        expect(mockVideoPlayerController.speed, 0.5);
        expect(() => gadgetspidyPlayerMockController.setSpeed(0.0),
            throwsA(isA<ArgumentError>()));
        expect(mockVideoPlayerController.speed, 0.5);
      });

      test(
        "setSpeed should send event",
        () async {
          final GadgetspidyPlayerController gadgetspidyPlayerMockController =
              GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
          final videoPlayerController =
              GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
          gadgetspidyPlayerMockController.videoPlayerController =
              videoPlayerController;

          int setSpeedCalls = 0;
          gadgetspidyPlayerMockController.addEventsListener((event) {
            if (event.gadgetspidyPlayerEventType ==
                GadgetspidyPlayerEventType.setSpeed) {
              setSpeedCalls += 1;
            }
          });
          gadgetspidyPlayerMockController.setSpeed(1.5);
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(setSpeedCalls, 1);
          gadgetspidyPlayerMockController.setSpeed(1.0);
          await Future.delayed(const Duration(milliseconds: 100), () {});
          expect(setSpeedCalls, 2);
        },
      );

      test("isBuffering returns valid value", () async {
        final GadgetspidyPlayerController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        final videoPlayerController =
            GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
        gadgetspidyPlayerMockController.videoPlayerController =
            videoPlayerController;
        videoPlayerController.setBuffering(false);
        expect(gadgetspidyPlayerMockController.isBuffering(), false);
        videoPlayerController.setBuffering(true);
        expect(gadgetspidyPlayerMockController.isBuffering(), true);
      });

      test("isLiveStream returns valid value", () async {
        final GadgetspidyPlayerController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        expect(() => gadgetspidyPlayerMockController.isLiveStream(),
            throwsA(isA<StateError>()));
        gadgetspidyPlayerMockController.setupDataSource(
            GadgetspidyPlayerDataSource(GadgetspidyPlayerDataSourceType.network,
                GadgetspidyPlayerTestUtils.forBiggerBlazesUrl,
                liveStream: true));
        final videoPlayerController =
            GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
        gadgetspidyPlayerMockController.videoPlayerController =
            videoPlayerController;
        expect(gadgetspidyPlayerMockController.isLiveStream(), true);
      });

      test("isVideoInitalized returns valid value", () async {
        final GadgetspidyPlayerController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        expect(() => gadgetspidyPlayerMockController.isVideoInitialized(),
            throwsA(isA<StateError>()));
        final videoPlayerController =
            GadgetspidyPlayerTestUtils.setupMockVideoPlayerControler();
        gadgetspidyPlayerMockController.videoPlayerController =
            videoPlayerController;
        videoPlayerController.setDuration(const Duration(seconds: 1));
        expect(gadgetspidyPlayerMockController.isVideoInitialized(), true);
      });

      test("startNextVideoTimer starts next video timer", () async {
        final GadgetspidyPlayerController gadgetspidyPlayerMockController =
            GadgetspidyPlayerTestUtils.setupGadgetspidyPlayerMockController();
        int eventCount = 0;
        gadgetspidyPlayerMockController.nextVideoTimeStream.listen((event) {
          eventCount += 1;
        });
        gadgetspidyPlayerMockController.startNextVideoTimer();
        await Future.delayed(const Duration(milliseconds: 3000), () {});
        expect(eventCount, 3);
      });
    },
  );
}
