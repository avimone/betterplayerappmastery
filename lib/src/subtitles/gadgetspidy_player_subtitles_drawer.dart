import 'dart:async';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/subtitles/gadgetspidy_player_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class GadgetspidyPlayerSubtitlesDrawer extends StatefulWidget {
  final List<GadgetspidyPlayerSubtitle> subtitles;
  final GadgetspidyPlayerController gadgetspidyPlayerController;
  final GadgetspidyPlayerSubtitlesConfiguration?
      gadgetspidyPlayerSubtitlesConfiguration;
  final Stream<bool> playerVisibilityStream;

  const GadgetspidyPlayerSubtitlesDrawer({
    Key? key,
    required this.subtitles,
    required this.gadgetspidyPlayerController,
    this.gadgetspidyPlayerSubtitlesConfiguration,
    required this.playerVisibilityStream,
  }) : super(key: key);

  @override
  _GadgetspidyPlayerSubtitlesDrawerState createState() =>
      _GadgetspidyPlayerSubtitlesDrawerState();
}

class _GadgetspidyPlayerSubtitlesDrawerState
    extends State<GadgetspidyPlayerSubtitlesDrawer> {
  final RegExp htmlRegExp =
      // ignore: unnecessary_raw_strings
      RegExp(r"<[^>]*>", multiLine: true);
  late TextStyle _innerTextStyle;
  late TextStyle _outerTextStyle;

  VideoPlayerValue? _latestValue;
  GadgetspidyPlayerSubtitlesConfiguration? _configuration;
  bool _playerVisible = false;

  ///Stream used to detect if play controls are visible or not
  late StreamSubscription _visibilityStreamSubscription;

  @override
  void initState() {
    _visibilityStreamSubscription =
        widget.playerVisibilityStream.listen((state) {
      setState(() {
        _playerVisible = state;
      });
    });

    if (widget.gadgetspidyPlayerSubtitlesConfiguration != null) {
      _configuration = widget.gadgetspidyPlayerSubtitlesConfiguration;
    } else {
      _configuration = setupDefaultConfiguration();
    }

    widget.gadgetspidyPlayerController.videoPlayerController!
        .addListener(_updateState);

    _outerTextStyle = TextStyle(
        fontSize: _configuration!.fontSize,
        fontFamily: _configuration!.fontFamily,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _configuration!.outlineSize
          ..color = _configuration!.outlineColor);

    _innerTextStyle = TextStyle(
        fontFamily: _configuration!.fontFamily,
        color: _configuration!.fontColor,
        fontSize: _configuration!.fontSize);

    super.initState();
  }

  @override
  void dispose() {
    widget.gadgetspidyPlayerController.videoPlayerController!
        .removeListener(_updateState);
    _visibilityStreamSubscription.cancel();
    super.dispose();
  }

  ///Called when player state has changed, i.e. new player position, etc.
  void _updateState() {
    if (mounted) {
      setState(() {
        _latestValue =
            widget.gadgetspidyPlayerController.videoPlayerController!.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final GadgetspidyPlayerSubtitle? subtitle = _getSubtitleAtCurrentPosition();
    widget.gadgetspidyPlayerController.renderedSubtitle = subtitle;
    final List<String> subtitles = subtitle?.texts ?? [];
    final List<Widget> textWidgets =
        subtitles.map((text) => _buildSubtitleTextWidget(text)).toList();

    return Container(
      height: double.infinity,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: _playerVisible
                ? _configuration!.bottomPadding + 30
                : _configuration!.bottomPadding,
            left: _configuration!.leftPadding,
            right: _configuration!.rightPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: textWidgets,
        ),
      ),
    );
  }

  GadgetspidyPlayerSubtitle? _getSubtitleAtCurrentPosition() {
    if (_latestValue == null) {
      return null;
    }

    final Duration position = _latestValue!.position;
    for (final GadgetspidyPlayerSubtitle subtitle
        in widget.gadgetspidyPlayerController.subtitlesLines) {
      if (subtitle.start! <= position && subtitle.end! >= position) {
        return subtitle;
      }
    }
    return null;
  }

  Widget _buildSubtitleTextWidget(String subtitleText) {
    return Row(children: [
      Expanded(
        child: Align(
          alignment: _configuration!.alignment,
          child: _getTextWithStroke(subtitleText),
        ),
      ),
    ]);
  }

  Widget _getTextWithStroke(String subtitleText) {
    return Container(
      color: _configuration!.backgroundColor,
      child: Stack(
        children: [
          if (_configuration!.outlineEnabled)
            _buildHtmlWidget(subtitleText, _outerTextStyle)
          else
            const SizedBox(),
          _buildHtmlWidget(subtitleText, _innerTextStyle)
        ],
      ),
    );
  }

  Widget _buildHtmlWidget(String text, TextStyle textStyle) {
    return HtmlWidget(
      text,
      textStyle: textStyle,
    );
  }

  GadgetspidyPlayerSubtitlesConfiguration setupDefaultConfiguration() {
    return const GadgetspidyPlayerSubtitlesConfiguration();
  }
}
