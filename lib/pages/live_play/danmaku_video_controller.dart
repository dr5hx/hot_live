import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barrage/flutter_barrage.dart';
import 'package:hot_live/api/danmaku/danmaku_stream.dart';
import 'package:hot_live/generated/l10n.dart';
import 'package:hot_live/provider/settings_provider.dart';
import 'package:hot_live/widgets/custom_icons.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock/wakelock.dart';

class DanmakuText extends StatelessWidget {
  const DanmakuText({Key? key, required this.message}) : super(key: key);

  final String message;

  @override
  Widget build(BuildContext context) {
    SettingsProvider settings = Provider.of<SettingsProvider>(context);

    return Text(
      message,
      maxLines: 1,
      style: TextStyle(
        fontSize: settings.danmakuFontSize,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      ),
    );
  }
}

class DanmakuVideoController extends StatefulWidget {
  final DanmakuStream danmakuStream;
  final String title;

  const DanmakuVideoController({
    Key? key,
    required this.danmakuStream,
    this.title = '',
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _DanmakuVideoControllerState();
  }
}

class _DanmakuVideoControllerState extends State<DanmakuVideoController>
    with SingleTickerProviderStateMixin {
  late VideoPlayerValue _latestValue;

  final barHeight = 56.0;
  final marginSize = 5.0;

  double? _latestVolume;

  bool _hideStuff = true;
  bool _hideDanmaku = false;
  bool _lockStuff = false;
  bool _displayTapped = false;
  bool _displayDanmakuSetting = false;
  bool _displayBufferingIndicator = false;

  Timer? _initTimer;
  Timer? _hideTimer;
  Timer? _bufferingDisplayTimer;
  Timer? _showAfterExpandCollapseTimer;

  // 滑动调节控制
  bool _dragingBV = false;
  double? updatePrevDx;
  double? updatePrevDy;
  int? updatePosX;
  bool? isDargVerLeft;
  double? updateDargVarVal;
  VolumeController volumeController = VolumeController()..showSystemUI = false;
  ScreenBrightness brightnessController = ScreenBrightness();

  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  final BarrageWallController barrageWallController = BarrageWallController();
  late final SettingsProvider settings = Provider.of<SettingsProvider>(context);

  // We know that _chewieController is set in didChangeDependencies
  VideoPlayerController get controller => _controller!;
  ChewieController get chewieController => _chewieController!;

  @override
  void initState() {
    widget.danmakuStream.listen((info) {
      barrageWallController
          .send([Bullet(child: DanmakuText(message: info.msg))]);
    });
    super.initState();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    _controller = chewieController.videoPlayerController;
    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          _buildRefreshButton();
    }

    List<Widget> ws = [];
    if (!_hideDanmaku) {
      ws.add(_buildDanmakuView());
    }
    if (_lockStuff && chewieController.isFullScreen) {
      ws.add(_buidLockStateButton());
    } else {
      ws.add(_displayBufferingIndicator
          ? const Center(child: CircularProgressIndicator())
          : _buildHitArea());
      if (chewieController.isFullScreen) {
        ws.add(_buidLockStateButton());
        ws.add(_buildActionBar());
      }
      ws.add(_buildBottomBar());
    }

    return MouseRegion(
      onHover: (_) => _cancelAndRestartTimer(),
      child: GestureDetector(
        onTap: _cancelAndRestartTimer,
        child: AbsorbPointer(
          absorbing: _hideStuff,
          child: Stack(children: ws),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => controller.initialize().then((value) => controller.play()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, right: 10),
          decoration: const BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 42.0,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buidLockStateButton() {
    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 0.8,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(right: 20.0),
          child: IconButton(
            iconSize: 28,
            onPressed: () {
              setState(() {
                _lockStuff = !_lockStuff;
                Wakelock.toggle(enable: _lockStuff);
              });
            },
            icon:
                Icon(_lockStuff ? Icons.lock_rounded : Icons.lock_open_rounded),
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Danmaku widget
  Widget _buildDanmakuView() {
    double danmukuHeight = (chewieController.isFullScreen
            ? MediaQuery.of(context).size.height
            : (MediaQuery.of(context).size.width / 16 * 9)) *
        settings.danmakuArea;

    return Positioned(
      top: 4,
      width: MediaQuery.of(context).size.width,
      height: danmukuHeight,
      child: AnimatedOpacity(
        opacity: !_hideDanmaku ? settings.danmakuOpacity : 0.0,
        duration: const Duration(milliseconds: 300),
        child: BarrageWall(
          width: MediaQuery.of(context).size.width,
          height: danmukuHeight,
          speed: settings.danmakuSpeed.toInt(),
          controller: barrageWallController,
          massiveMode: false,
          safeBottomHeight: settings.danmakuFontSize.toInt(),
          child: Container(),
        ),
      ),
    );
  }

  // Center hit and controller widgets
  Widget _buildHitArea() {
    Widget centerArea = Container();
    if (_displayDanmakuSetting) {
      centerArea = _buildDanmakuSettingView();
    } else if (_dragingBV) {
      centerArea = _buildDargVolumeAndBrightness();
    } else if (!_latestValue.isPlaying) {
      centerArea = _buildCenterPlayButton();
    }

    return GestureDetector(
      onTap: () {
        if (_displayDanmakuSetting) {
          setState(() {
            _displayDanmakuSetting = false;
          });
        } else if (_latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              _hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();
          setState(() {
            _hideStuff = true;
          });
        }
      },
      onDoubleTap: _playPause,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        color: Colors.transparent,
        child: centerArea,
      ),
    );
  }

  Widget _buildCenterPlayButton() {
    return Container(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: !_latestValue.isPlaying ? 0.7 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: _playPause,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, right: 10),
            decoration: const BoxDecoration(
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black54, blurRadius: 20),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 42.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDargVolumeAndBrightness() {
    IconData iconData = Icons.volume_up;

    if (_dragingBV) {
      if (isDargVerLeft!) {
        iconData = updateDargVarVal! <= 0
            ? Icons.brightness_low
            : updateDargVarVal! < 0.5
                ? Icons.brightness_medium
                : Icons.brightness_high;
      } else {
        iconData = updateDargVarVal! <= 0
            ? Icons.volume_mute
            : updateDargVarVal! < 0.5
                ? Icons.volume_down
                : Icons.volume_up;
      }
    }

    return Container(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: _dragingBV ? 0.8 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Card(
          color: Colors.black,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(iconData, color: Colors.white),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      height: 20,
                      child: LinearProgressIndicator(
                        value: updateDargVarVal,
                        backgroundColor: Colors.white38,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).indicatorColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDanmakuSettingView() {
    SettingsProvider settings = Provider.of<SettingsProvider>(context);

    const TextStyle label = TextStyle(color: Colors.white);
    const TextStyle digit = TextStyle(color: Colors.white);

    return Container(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: _displayDanmakuSetting ? 0.8 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Card(
          color: Colors.black,
          child: Container(
            width: 350,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Text(
                    S.of(context).settings_danmaku_area,
                    style: label,
                  ),
                  title: Slider(
                    value: settings.danmakuArea,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => settings.danmakuArea = val,
                  ),
                  trailing: Text(
                    (settings.danmakuArea * 100).toInt().toString() + '%',
                    style: digit,
                  ),
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Text(
                    S.of(context).settings_danmaku_opacity,
                    style: label,
                  ),
                  title: Slider(
                    value: settings.danmakuOpacity,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => settings.danmakuOpacity = val,
                  ),
                  trailing: Text(
                    (settings.danmakuOpacity * 100).toInt().toString() + '%',
                    style: digit,
                  ),
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Text(
                    S.of(context).settings_danmaku_speed,
                    style: label,
                  ),
                  title: Slider(
                    value: settings.danmakuSpeed,
                    min: 1.0,
                    max: 20.0,
                    onChanged: (val) => settings.danmakuSpeed = val,
                  ),
                  trailing: Text(
                    settings.danmakuSpeed.toInt().toString(),
                    style: digit,
                  ),
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Text(
                    S.of(context).settings_danmaku_fontsize,
                    style: label,
                  ),
                  title: Slider(
                    value: settings.danmakuFontSize,
                    min: 10.0,
                    max: 30.0,
                    onChanged: (val) => settings.danmakuFontSize = val,
                  ),
                  trailing: Text(
                    settings.danmakuFontSize.toInt().toString(),
                    style: digit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Action bar widgets
  Widget _buildActionBar() {
    return Positioned(
      top: 0,
      height: barHeight,
      width: MediaQuery.of(context).size.width,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromRGBO(0, 0, 0, 0.02), Colors.black]),
          ),
          child: Row(
            children: <Widget>[
              _buildBackButton(),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              _buildBatteryInfo(),
              _buildTimeInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTimeInfo() {
    // get system time and format
    final dateTime = DateTime.now();
    var hour = dateTime.hour.toString();
    if (hour.length < 2) hour = '0$hour';
    var minute = dateTime.minute.toString();
    if (minute.length < 2) minute = '0$minute';

    return Container(
      height: barHeight,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Text(
        '$hour:$minute',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildBatteryInfo() {
    final batteryLevel = settings.batteryLevel;
    return Container(
      height: barHeight,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 4.0),
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: SizedBox(
              width: 20,
              height: 10,
              child: LinearProgressIndicator(
                value: batteryLevel / 100.0,
                backgroundColor: Colors.white38,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).indicatorColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$batteryLevel%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Bottom bar widgets
  Widget _buildBottomBar() {
    double screenWidth = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: 0,
      height: barHeight,
      width: MediaQuery.of(context).size.width,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.fromRGBO(0, 0, 0, 0.02), Colors.black]),
          ),
          child: Row(
            children: <Widget>[
              _buildPlayPauseButton(),
              _buildMuteButton(),
              _buildDanmakuHideButton(),
              if (chewieController.isFullScreen) _buildDanmakuSettingButton(),
              if (chewieController.isFullScreen || screenWidth < 640)
                const Spacer(),
              if (chewieController.allowFullScreen) _buildExpandButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          controller.value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDanmakuHideButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _hideDanmaku = !_hideDanmaku;
        });
      },
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          _hideDanmaku ? CustomIcons.danmaku_close : CustomIcons.danmaku_open,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDanmakuSettingButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _displayDanmakuSetting = !_displayDanmakuSetting;
        });
      },
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: const Icon(
          CustomIcons.danmaku_setting,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Icon(
          chewieController.isFullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // Callback functions
  Future<void> _initialize() async {
    controller.addListener(_updateState);

    _updateState();

    if ((controller.value.isPlaying) || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          _hideStuff = false;
        });
      });
    }
  }

  void _onVerticalDragStart(detills) async {
    double clientW = MediaQuery.of(context).size.width;
    double curTouchPosX = detills.globalPosition.dx;

    setState(() {
      // 更新位置
      updatePrevDy = detills.globalPosition.dy;
      // 是否左边
      isDargVerLeft = (curTouchPosX > (clientW / 2)) ? false : true;
    });
    // 大于 右边 音量 ， 小于 左边 亮度
    if (!isDargVerLeft!) {
      // 音量
      await volumeController.getVolume().then((double v) {
        _dragingBV = true;
        setState(() {
          updateDargVarVal = v;
        });
      });
    } else {
      // 亮度
      await brightnessController.current.then((double v) {
        _dragingBV = true;
        setState(() {
          updateDargVarVal = v;
        });
      });
    }
  }

  void _onVerticalDragUpdate(detills) {
    if (!_dragingBV) return;
    double curDragDy = detills.globalPosition.dy;
    // 确定当前是前进或者后退
    int cdy = curDragDy.toInt();
    int pdy = updatePrevDy!.toInt();
    bool isBefore = cdy < pdy;
    // + -, 不满足, 上下滑动合法滑动值，> 3
    if (isBefore && pdy - cdy < 3 || !isBefore && cdy - pdy < 3) return;
    // 区间
    double dragRange =
        isBefore ? updateDargVarVal! + 0.03 : updateDargVarVal! - 0.03;
    // 是否溢出
    if (dragRange > 1) {
      dragRange = 1.0;
    }
    if (dragRange < 0) {
      dragRange = 0.0;
    }
    setState(() {
      updatePrevDy = curDragDy;
      _dragingBV = true;
      updateDargVarVal = dragRange;
      // 音量
      if (!isDargVerLeft!) {
        volumeController.setVolume(dragRange);
      } else {
        brightnessController.setScreenBrightness(dragRange);
      }
    });
  }

  void _onVerticalDragEnd(detills) {
    setState(() {
      _dragingBV = false;
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      _hideStuff = false;
      _displayTapped = true;
    });
  }

  void _onExpandCollapse() {
    setState(() {
      _hideStuff = true;
      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer =
          Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _cancelAndRestartTimer();
        });
      });
    });
  }

  void _playPause() {
    bool isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        _hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero);
          }
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _hideStuff = true;
      });
    });
  }

  void _bufferingTimerTimeout() {
    _displayBufferingIndicator = true;
    if (mounted) {
      setState(() {});
    }
  }

  void _updateState() {
    if (!mounted) return;

    // display the progress bar indicator only after the buffering delay if it has been set
    if (chewieController.progressIndicatorDelay != null) {
      if (controller.value.isBuffering) {
        _bufferingDisplayTimer ??= Timer(
          chewieController.progressIndicatorDelay!,
          _bufferingTimerTimeout,
        );
      } else {
        _bufferingDisplayTimer?.cancel();
        _bufferingDisplayTimer = null;
        _displayBufferingIndicator = false;
      }
    } else {
      _displayBufferingIndicator = controller.value.isBuffering;
    }

    setState(() {
      _latestValue = controller.value;
    });
  }
}