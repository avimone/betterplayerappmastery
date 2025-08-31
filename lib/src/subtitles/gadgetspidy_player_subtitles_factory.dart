import 'dart:convert';
import 'dart:io';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';
import 'package:gadgetspidy_player/src/core/gadgetspidy_player_utils.dart';
import 'gadgetspidy_player_subtitle.dart';

class GadgetspidyPlayerSubtitlesFactory {
  static Future<List<GadgetspidyPlayerSubtitle>> parseSubtitles(
      GadgetspidyPlayerSubtitlesSource source) async {
    switch (source.type) {
      case GadgetspidyPlayerSubtitlesSourceType.file:
        return _parseSubtitlesFromFile(source);
      case GadgetspidyPlayerSubtitlesSourceType.network:
        return _parseSubtitlesFromNetwork(source);
      case GadgetspidyPlayerSubtitlesSourceType.memory:
        return _parseSubtitlesFromMemory(source);
      default:
        return [];
    }
  }

  static Future<List<GadgetspidyPlayerSubtitle>> _parseSubtitlesFromFile(
      GadgetspidyPlayerSubtitlesSource source) async {
    try {
      final List<GadgetspidyPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final file = File(url!);
        if (file.existsSync()) {
          final String fileContent = await file.readAsString();
          final subtitlesCache = _parseString(fileContent);
          subtitles.addAll(subtitlesCache);
        } else {
          GadgetspidyPlayerUtils.log("$url doesn't exist!");
        }
      }
      return subtitles;
    } catch (exception) {
      GadgetspidyPlayerUtils.log(
          "Failed to read subtitles from file: $exception");
    }
    return [];
  }

  static Future<List<GadgetspidyPlayerSubtitle>> _parseSubtitlesFromNetwork(
      GadgetspidyPlayerSubtitlesSource source) async {
    try {
      final client = HttpClient();
      final List<GadgetspidyPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final request = await client.getUrl(Uri.parse(url!));
        source.headers?.keys.forEach((key) {
          final value = source.headers![key];
          if (value != null) {
            request.headers.add(key, value);
          }
        });
        final response = await request.close();
        final data = await response.transform(const Utf8Decoder()).join();
        final cacheList = _parseString(data);
        subtitles.addAll(cacheList);
      }
      client.close();

      GadgetspidyPlayerUtils.log("Parsed total subtitles: ${subtitles.length}");
      return subtitles;
    } catch (exception) {
      GadgetspidyPlayerUtils.log(
          "Failed to read subtitles from network: $exception");
    }
    return [];
  }

  static List<GadgetspidyPlayerSubtitle> _parseSubtitlesFromMemory(
      GadgetspidyPlayerSubtitlesSource source) {
    try {
      return _parseString(source.content!);
    } catch (exception) {
      GadgetspidyPlayerUtils.log(
          "Failed to read subtitles from memory: $exception");
    }
    return [];
  }

  static List<GadgetspidyPlayerSubtitle> _parseString(String value) {
    List<String> components = value.split('\r\n\r\n');
    if (components.length == 1) {
      components = value.split('\n\n');
    }

    // Skip parsing files with no cues
    if (components.length == 1) {
      return [];
    }

    final List<GadgetspidyPlayerSubtitle> subtitlesObj = [];

    final bool isWebVTT = components.contains("WEBVTT");
    for (final component in components) {
      if (component.isEmpty) {
        continue;
      }
      final subtitle = GadgetspidyPlayerSubtitle(component, isWebVTT);
      if (subtitle.start != null &&
          subtitle.end != null &&
          subtitle.texts != null) {
        subtitlesObj.add(subtitle);
      }
    }

    return subtitlesObj;
  }
}
