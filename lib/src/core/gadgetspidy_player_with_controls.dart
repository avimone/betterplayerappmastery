import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_controller_event.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_cupertino_controls.dart';
import 'package:gadgetspidy_player/src/controls/gadgetspidy_player_material_controls.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'package:gadgetspidy_player/src/subtitles/gadgetspidy_player_subtitles_drawer.dart';
import 'package:gadgetspidy_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';

class GadgetspidyPlayerWithControls extends StatefulWidget {
  final GadgetspidyPlayerController? controller;

  const GadgetspidyPlayerWithControls({Key? key, this.controller})
      : super(key: key);

  @override
  _GadgetspidyPlayerWithControlsState createState() =>
      _GadgetspidyPlayerWithControlsState();
}

class _GadgetspidyPlayerWithControlsState
    extends State<GadgetspidyPlayerWithControls> {
  GadgetspidyPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      widget.controller!.gadgetspidyPlayerConfiguration.subtitlesConfiguration;

  GadgetspidyPlayerControlsConfiguration get controlsConfiguration =>
      widget.controller!.gadgetspidyPlayerControlsConfiguration;

  final StreamController<bool> playerVisibilityStreamController =
      StreamController();

  bool _initialized = false;

  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    playerVisibilityStreamController.add(true);
    _controllerEventSubscription =
        widget.controller!.controllerEventStream.listen(_onControllerChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(GadgetspidyPlayerWithControls oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller!.controllerEventStream.listen(_onControllerChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    playerVisibilityStreamController.close();
    _controllerEventSubscription?.cancel();
    super.dispose();
  }

  void _onControllerChanged(GadgetspidyPlayerControllerEvent event) {
    setState(() {
      if (!_initialized) {
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final GadgetspidyPlayerController gadgetspidyPlayerController =
        GadgetspidyPlayerController.of(context);

    double? aspectRatio;
    if (gadgetspidyPlayerController.isFullScreen) {
      if (gadgetspidyPlayerController.gadgetspidyPlayerConfiguration
              .autoDetectFullscreenDeviceOrientation ||
          gadgetspidyPlayerController
              .gadgetspidyPlayerConfiguration.autoDetectFullscreenAspectRatio) {
        aspectRatio = gadgetspidyPlayerController
                .videoPlayerController?.value.aspectRatio ??
            1.0;
      } else {
        aspectRatio = gadgetspidyPlayerController
                .gadgetspidyPlayerConfiguration.fullScreenAspectRatio ??
            GadgetspidyPlayerUtils.calculateAspectRatio(context);
      }
    } else {
      aspectRatio = gadgetspidyPlayerController.getAspectRatio();
    }

    aspectRatio ??= 16 / 9;
    final innerContainer = Container(
      width: double.infinity,
      color: gadgetspidyPlayerController
          .gadgetspidyPlayerConfiguration.controlsConfiguration.backgroundColor,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildPlayerWithControls(gadgetspidyPlayerController, context),
      ),
    );

    if (gadgetspidyPlayerController
        .gadgetspidyPlayerConfiguration.expandToFill) {
      return Center(child: innerContainer);
    } else {
      return innerContainer;
    }
  }

  Container _buildPlayerWithControls(
      GadgetspidyPlayerController gadgetspidyPlayerController,
      BuildContext context) {
    final configuration =
        gadgetspidyPlayerController.gadgetspidyPlayerConfiguration;
    var rotation = configuration.rotation;

    if (!(rotation <= 360 && rotation % 90 == 0)) {
      GadgetspidyPlayerUtils.log(
          "Invalid rotation provided. Using rotation = 0");
      rotation = 0;
    }
    if (gadgetspidyPlayerController.gadgetspidyPlayerDataSource == null) {
      return Container();
    }
    _initialized = true;

    final bool placeholderOnTop = gadgetspidyPlayerController
        .gadgetspidyPlayerConfiguration.placeholderOnTop;
    // ignore: avoid_unnecessary_containers
    return Container(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (placeholderOnTop) _buildPlaceholder(gadgetspidyPlayerController),
          Transform.rotate(
            angle: rotation * pi / 180,
            child: _GadgetspidyPlayerVideoFitWidget(
              gadgetspidyPlayerController,
              gadgetspidyPlayerController.getFit(),
            ),
          ),
          gadgetspidyPlayerController.gadgetspidyPlayerConfiguration.overlay ??
              Container(),
          GadgetspidyPlayerSubtitlesDrawer(
            gadgetspidyPlayerController: gadgetspidyPlayerController,
            gadgetspidyPlayerSubtitlesConfiguration: subtitlesConfiguration,
            subtitles: gadgetspidyPlayerController.subtitlesLines,
            playerVisibilityStream: playerVisibilityStreamController.stream,
          ),
          if (!placeholderOnTop) _buildPlaceholder(gadgetspidyPlayerController),
          _buildControls(context, gadgetspidyPlayerController),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(
      GadgetspidyPlayerController gadgetspidyPlayerController) {
    return gadgetspidyPlayerController
            .gadgetspidyPlayerDataSource!.placeholder ??
        gadgetspidyPlayerController
            .gadgetspidyPlayerConfiguration.placeholder ??
        Container();
  }

  Widget _buildControls(
    BuildContext context,
    GadgetspidyPlayerController gadgetspidyPlayerController,
  ) {
    if (controlsConfiguration.showControls) {
      GadgetspidyPlayerTheme? playerTheme = controlsConfiguration.playerTheme;
      if (playerTheme == null) {
        if (Platform.isAndroid) {
          playerTheme = GadgetspidyPlayerTheme.material;
        } else {
          playerTheme = GadgetspidyPlayerTheme.cupertino;
        }
      }

      if (controlsConfiguration.customControlsBuilder != null &&
          playerTheme == GadgetspidyPlayerTheme.custom) {
        return controlsConfiguration.customControlsBuilder!(
            gadgetspidyPlayerController, onControlsVisibilityChanged);
      } else if (playerTheme == GadgetspidyPlayerTheme.material) {
        return _buildMaterialControl();
      } else if (playerTheme == GadgetspidyPlayerTheme.cupertino) {
        return _buildCupertinoControl();
      }
    }

    return const SizedBox();
  }

  Widget _buildMaterialControl() {
    return GadgetspidyPlayerMaterialControls(
      onControlsVisibilityChanged: onControlsVisibilityChanged,
      controlsConfiguration: controlsConfiguration,
    );
  }

  Widget _buildCupertinoControl() {
    return GadgetspidyPlayerCupertinoControls(
      onControlsVisibilityChanged: onControlsVisibilityChanged,
      controlsConfiguration: controlsConfiguration,
    );
  }

  void onControlsVisibilityChanged(bool state) {
    playerVisibilityStreamController.add(state);
  }
}

///Widget used to set the proper box fit of the video. Default fit is 'fill'.
class _GadgetspidyPlayerVideoFitWidget extends StatefulWidget {
  const _GadgetspidyPlayerVideoFitWidget(
    this.gadgetspidyPlayerController,
    this.boxFit, {
    Key? key,
  }) : super(key: key);

  final GadgetspidyPlayerController gadgetspidyPlayerController;
  final BoxFit boxFit;

  @override
  _GadgetspidyPlayerVideoFitWidgetState createState() =>
      _GadgetspidyPlayerVideoFitWidgetState();
}

class _GadgetspidyPlayerVideoFitWidgetState
    extends State<_GadgetspidyPlayerVideoFitWidget> {
  VideoPlayerController? get controller =>
      widget.gadgetspidyPlayerController.videoPlayerController;

  bool _initialized = false;

  VoidCallback? _initializedListener;

  bool _started = false;

  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.gadgetspidyPlayerController.gadgetspidyPlayerConfiguration
        .showPlaceholderUntilPlay) {
      _started = true;
    } else {
      _started = widget.gadgetspidyPlayerController.hasCurrentDataSourceStarted;
    }

    _initialize();
  }

  @override
  void didUpdateWidget(_GadgetspidyPlayerVideoFitWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gadgetspidyPlayerController.videoPlayerController !=
        controller) {
      if (_initializedListener != null) {
        oldWidget.gadgetspidyPlayerController.videoPlayerController!
            .removeListener(_initializedListener!);
      }
      _initialized = false;
      _initialize();
    }
  }

  void _initialize() {
    if (controller?.value.initialized == false) {
      _initializedListener = () {
        if (!mounted) {
          return;
        }

        if (_initialized != controller!.value.initialized) {
          _initialized = controller!.value.initialized;
          setState(() {});
        }
      };
      controller!.addListener(_initializedListener!);
    } else {
      _initialized = true;
    }

    _controllerEventSubscription = widget
        .gadgetspidyPlayerController.controllerEventStream
        .listen((event) {
      if (event == GadgetspidyPlayerControllerEvent.play) {
        if (!_started) {
          setState(() {
            _started =
                widget.gadgetspidyPlayerController.hasCurrentDataSourceStarted;
          });
        }
      }
      if (event == GadgetspidyPlayerControllerEvent.setupDataSource) {
        setState(() {
          _started = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _started) {
      return Center(
        child: ClipRect(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: widget.boxFit,
              child: SizedBox(
                width: controller!.value.size?.width ?? 0,
                height: controller!.value.size?.height ?? 0,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  @override
  void dispose() {
    if (_initializedListener != null) {
      widget.gadgetspidyPlayerController.videoPlayerController!
          .removeListener(_initializedListener!);
    }
    _controllerEventSubscription?.cancel();
    super.dispose();
  }
}
