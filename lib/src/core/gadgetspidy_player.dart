import 'dart:async';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_controller_event.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_with_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

///Widget which uses provided controller to render video player.
class GadgetspidyPlayer extends StatefulWidget {
  const GadgetspidyPlayer({Key? key, required this.controller})
      : super(key: key);

  factory GadgetspidyPlayer.network(
    String url, {
    GadgetspidyPlayerConfiguration? gadgetspidyPlayerConfiguration,
  }) =>
      GadgetspidyPlayer(
        controller: GadgetspidyPlayerController(
          gadgetspidyPlayerConfiguration ??
              const GadgetspidyPlayerConfiguration(),
          gadgetspidyPlayerDataSource: GadgetspidyPlayerDataSource(
              GadgetspidyPlayerDataSourceType.network, url),
        ),
      );

  factory GadgetspidyPlayer.file(
    String url, {
    GadgetspidyPlayerConfiguration? gadgetspidyPlayerConfiguration,
  }) =>
      GadgetspidyPlayer(
        controller: GadgetspidyPlayerController(
          gadgetspidyPlayerConfiguration ??
              const GadgetspidyPlayerConfiguration(),
          gadgetspidyPlayerDataSource: GadgetspidyPlayerDataSource(
              GadgetspidyPlayerDataSourceType.file, url),
        ),
      );

  final GadgetspidyPlayerController controller;

  @override
  _GadgetspidyPlayerState createState() {
    return _GadgetspidyPlayerState();
  }
}

class _GadgetspidyPlayerState extends State<GadgetspidyPlayer>
    with WidgetsBindingObserver {
  GadgetspidyPlayerConfiguration get _gadgetspidyPlayerConfiguration =>
      widget.controller.gadgetspidyPlayerConfiguration;

  bool _isFullScreen = false;

  ///State of navigator on widget created
  late NavigatorState _navigatorState;

  ///Flag which determines if widget has initialized
  bool _initialized = false;

  ///Subscription for controller events
  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (!_initialized) {
      final navigator = Navigator.of(context);
      setState(() {
        _navigatorState = navigator;
      });
      _setup();
      _initialized = true;
    }
    super.didChangeDependencies();
  }

  Future<void> _setup() async {
    _controllerEventSubscription =
        widget.controller.controllerEventStream.listen(onControllerEvent);

    //Default locale
    var locale = const Locale("en", "US");
    try {
      if (mounted) {
        final contextLocale = Localizations.localeOf(context);
        locale = contextLocale;
      }
    } catch (exception) {
      GadgetspidyPlayerUtils.log(exception.toString());
    }
    widget.controller.setupTranslations(locale);
  }

  @override
  void dispose() {
    ///If somehow GadgetspidyPlayer widget has been disposed from widget tree and
    ///full screen is on, then full screen route must be pop and return to normal
    ///state.
    if (_isFullScreen) {
      // WakelockPlus.disable();
      _navigatorState.maybePop();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive,
          overlays:
              _gadgetspidyPlayerConfiguration.systemOverlaysAfterFullScreen);
      SystemChrome.setPreferredOrientations(
          _gadgetspidyPlayerConfiguration.deviceOrientationsAfterFullScreen);
    }

    WidgetsBinding.instance.removeObserver(this);
    _controllerEventSubscription?.cancel();
    widget.controller.dispose();
    VisibilityDetectorController.instance
        .forget(Key("${widget.controller.hashCode}_key"));
    super.dispose();
  }

  @override
  void didUpdateWidget(GadgetspidyPlayer oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller.controllerEventStream.listen(onControllerEvent);
    }
    super.didUpdateWidget(oldWidget);
  }

  void onControllerEvent(GadgetspidyPlayerControllerEvent event) {
    switch (event) {
      case GadgetspidyPlayerControllerEvent.openFullscreen:
        onFullScreenChanged();
        break;
      case GadgetspidyPlayerControllerEvent.hideFullscreen:
        onFullScreenChanged();
        break;
      default:
        setState(() {});
        break;
    }
  }

  // ignore: avoid_void_async
  Future<void> onFullScreenChanged() async {
    final controller = widget.controller;
    if (controller.isFullScreen && !_isFullScreen) {
      _isFullScreen = true;
      controller.postEvent(
          GadgetspidyPlayerEvent(GadgetspidyPlayerEventType.openFullscreen));
      await _pushFullScreenWidget(context);
    } else if (_isFullScreen) {
      Navigator.of(context, rootNavigator: true).pop();

      _isFullScreen = false;
      controller.postEvent(
          GadgetspidyPlayerEvent(GadgetspidyPlayerEventType.hideFullscreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GadgetspidyPlayerControllerProvider(
      controller: widget.controller,
      child: _buildPlayer(),
    );
  }

  Widget _buildFullScreenVideo(
      BuildContext context,
      Animation<double> animation,
      GadgetspidyPlayerControllerProvider controllerProvider) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        Navigator.pop(context);
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          alignment: Alignment.center,
          color: Colors.black,
          child: controllerProvider,
        ),
      ),
    );
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      GadgetspidyPlayerControllerProvider controllerProvider) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return _buildFullScreenVideo(context, animation, controllerProvider);
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final controllerProvider = GadgetspidyPlayerControllerProvider(
        controller: widget.controller, child: _buildPlayer());

    final routePageBuilder = _gadgetspidyPlayerConfiguration.routePageBuilder;
    if (routePageBuilder == null) {
      return _defaultRoutePageBuilder(
          context, animation, secondaryAnimation, controllerProvider);
    }

    return routePageBuilder(
        context, animation, secondaryAnimation, controllerProvider);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (_gadgetspidyPlayerConfiguration.autoDetectFullscreenDeviceOrientation ==
        true) {
      final aspectRatio =
          widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;
      List<DeviceOrientation> deviceOrientations;
      if (aspectRatio < 1.0) {
        deviceOrientations = [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown
        ];
      } else {
        deviceOrientations = [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ];
      }
      await SystemChrome.setPreferredOrientations(deviceOrientations);
    } else {
      await SystemChrome.setPreferredOrientations(
        widget.controller.gadgetspidyPlayerConfiguration
            .deviceOrientationsOnFullScreen,
      );
    }

    if (!_gadgetspidyPlayerConfiguration.allowedScreenSleep) {
      WakelockPlus.enable();
    }

    await Navigator.of(context, rootNavigator: true).push(route);
    _isFullScreen = false;
    widget.controller.exitFullScreen();

    // The wakelock plugins checks whether it needs to perform an action internally,
    // so we do not need to check Wakelock.isEnabled.
    //  WakelockPlus.disable();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive,
        overlays:
            _gadgetspidyPlayerConfiguration.systemOverlaysAfterFullScreen);
    await SystemChrome.setPreferredOrientations(
        _gadgetspidyPlayerConfiguration.deviceOrientationsAfterFullScreen);
  }

  Widget _buildPlayer() {
    return VisibilityDetector(
      key: Key("${widget.controller.hashCode}_key"),
      onVisibilityChanged: (VisibilityInfo info) =>
          widget.controller.onPlayerVisibilityChanged(info.visibleFraction),
      child: GadgetspidyPlayerWithControls(
        controller: widget.controller,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    widget.controller.setAppLifecycleState(state);
  }
}

///Page route builder used in fullscreen mode.
typedef GadgetspidyPlayerRoutePageBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    GadgetspidyPlayerControllerProvider controllerProvider);
