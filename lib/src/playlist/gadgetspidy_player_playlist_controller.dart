import 'dart:async';
import 'package:gadgetspidy_player/gadgetspidy_player.dart';

///Controller used to manage playlist player.
class GadgetspidyPlayerPlaylistController {
  ///List of data sources set for playlist.
  final List<GadgetspidyPlayerDataSource> _gadgetspidyPlayerDataSourceList;

  //General configuration of Gadgetspidy Player
  final GadgetspidyPlayerConfiguration gadgetspidyPlayerConfiguration;

  ///Playlist configuration of Gadgetspidy Player
  final GadgetspidyPlayerPlaylistConfiguration
      gadgetspidyPlayerPlaylistConfiguration;

  ///GadgetspidyPlayerController instance
  GadgetspidyPlayerController? _gadgetspidyPlayerController;

  ///Currently playing data source index
  int _currentDataSourceIndex = 0;

  ///Next video change listener subscription
  StreamSubscription? _nextVideoTimeStreamSubscription;

  ///Flag that determines whenever player is changing video
  bool _changingToNextVideo = false;

  GadgetspidyPlayerPlaylistController(
    this._gadgetspidyPlayerDataSourceList, {
    this.gadgetspidyPlayerConfiguration =
        const GadgetspidyPlayerConfiguration(),
    this.gadgetspidyPlayerPlaylistConfiguration =
        const GadgetspidyPlayerPlaylistConfiguration(),
  }) : assert(_gadgetspidyPlayerDataSourceList.isNotEmpty,
            "Gadgetspidy Player data source list can't be empty") {
    _setup();
  }

  ///Initialize controller and listeners.
  void _setup() {
    _gadgetspidyPlayerController ??= GadgetspidyPlayerController(
      gadgetspidyPlayerConfiguration,
      gadgetspidyPlayerPlaylistConfiguration:
          gadgetspidyPlayerPlaylistConfiguration,
    );

    var initialStartIndex =
        gadgetspidyPlayerPlaylistConfiguration.initialStartIndex;
    if (initialStartIndex >= _gadgetspidyPlayerDataSourceList.length) {
      initialStartIndex = 0;
    }

    _currentDataSourceIndex = initialStartIndex;
    setupDataSource(_currentDataSourceIndex);
    _gadgetspidyPlayerController!.addEventsListener(_handleEvent);
    _nextVideoTimeStreamSubscription =
        _gadgetspidyPlayerController!.nextVideoTimeStream.listen((time) {
      if (time != null && time == 0) {
        _onVideoChange();
      }
    });
  }

  /// Setup new data source list. Pauses currently played video and init new data
  /// source list. Previous data source list will be removed.
  void setupDataSourceList(List<GadgetspidyPlayerDataSource> dataSourceList) {
    _gadgetspidyPlayerController?.pause();
    _gadgetspidyPlayerDataSourceList.clear();
    _gadgetspidyPlayerDataSourceList.addAll(dataSourceList);
    _setup();
  }

  ///Handle video change signal from GadgetspidyPlayerController. Setup new data
  ///source based on configuration.
  void _onVideoChange() {
    if (_changingToNextVideo) {
      return;
    }
    final int nextDataSourceId = _getNextDataSourceIndex();
    if (nextDataSourceId == -1) {
      return;
    }
    if (_gadgetspidyPlayerController!.isFullScreen) {
      _gadgetspidyPlayerController!.exitFullScreen();
    }
    _changingToNextVideo = true;
    setupDataSource(nextDataSourceId);

    _changingToNextVideo = false;
  }

  ///Handle GadgetspidyPlayerEvent from GadgetspidyPlayerController. Used to control
  ///startup of next video timer.
  void _handleEvent(GadgetspidyPlayerEvent gadgetspidyPlayerEvent) {
    if (gadgetspidyPlayerEvent.gadgetspidyPlayerEventType ==
        GadgetspidyPlayerEventType.finished) {
      if (_getNextDataSourceIndex() != -1) {
        _gadgetspidyPlayerController!.startNextVideoTimer();
      }
    }
  }

  ///Setup data source with index based on [_gadgetspidyPlayerDataSourceList] provided
  ///in constructor. Index must
  void setupDataSource(int index) {
    assert(
        index >= 0 && index < _gadgetspidyPlayerDataSourceList.length,
        "Index must be greater than 0 and less than size of data source "
        "list - 1");
    if (index <= _dataSourceLength) {
      _currentDataSourceIndex = index;
      _gadgetspidyPlayerController!
          .setupDataSource(_gadgetspidyPlayerDataSourceList[index]);
    }
  }

  ///Get index of next data source. If current index is less than
  ///[_gadgetspidyPlayerDataSourceList] size then next element will be picked, otherwise
  ///if loops is enabled then first element of [_gadgetspidyPlayerDataSourceList] will
  ///be picked, otherwise -1 will be returned, indicating that player should
  ///stop changing videos.
  int _getNextDataSourceIndex() {
    final currentIndex = _currentDataSourceIndex;
    if (currentIndex + 1 < _dataSourceLength) {
      return currentIndex + 1;
    } else {
      if (gadgetspidyPlayerPlaylistConfiguration.loopVideos) {
        return 0;
      } else {
        return -1;
      }
    }
  }

  ///Get index of currently played source, based on [_gadgetspidyPlayerDataSourceList]
  int get currentDataSourceIndex => _currentDataSourceIndex;

  ///Get size of [_gadgetspidyPlayerDataSourceList]
  int get _dataSourceLength => _gadgetspidyPlayerDataSourceList.length;

  ///Get GadgetspidyPlayerController instance
  GadgetspidyPlayerController? get gadgetspidyPlayerController =>
      _gadgetspidyPlayerController;

  ///Cleanup GadgetspidyPlayerPlaylistController
  void dispose() {
    _nextVideoTimeStreamSubscription?.cancel();
  }
}
