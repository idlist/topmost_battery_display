import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:patterns_canvas/patterns_canvas.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    _setupWindowManager(),
    _setupTrayManager(),
  ]);

  runApp(const MainApp());
}

Future<String> get _localPath async {
  final document = await getApplicationDocumentsDirectory();
  final path = '${document.path}/Topmost Battery Display';
  final directory = await Directory(path).create(recursive: true);

  return directory.path;
}

Future<void> _setupWindowManager() async {
  await windowManager.ensureInitialized();
}

Future<void> _setupTrayManager() async {
  await trayManager.setIcon(
    Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

enum ColorTheme {
  light,
  dark,
}

class _MainAppState extends State<MainApp> with WindowListener, TrayListener {
  Offset? _position;
  bool _show = true;
  bool _clickThrough = false;
  ColorTheme _colorTheme = ColorTheme.dark;

  Menu _generateMenu() {
    return Menu(
      items: [
        MenuItem.checkbox(
          checked: _show,
          key: 'show',
          label: 'Show widget',
        ),
        MenuItem.separator(),
        MenuItem.checkbox(
          checked: _clickThrough,
          key: 'click-through',
          label: 'Click-through',
        ),
        MenuItem.submenu(
          key: 'color-theme',
          label: 'Color theme',
          submenu: Menu(
            items: [
              MenuItem.checkbox(
                checked: _colorTheme == ColorTheme.dark,
                key: 'color-theme-dark',
                label: 'Dark',
              ),
              MenuItem.checkbox(
                checked: _colorTheme == ColorTheme.light,
                key: 'color-theme-light',
                label: 'Light',
              )
            ],
          ),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'open-directory',
          label: 'Open data folder',
        ),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
  }

  Future<File> get _configFile async {
    final path = await _localPath;
    return await File('$path/config.json').create();
  }

  Future<void> _loadConfig() async {
    final file = await _configFile;
    final jsonString = await file.readAsString();

    try {
      final data = jsonDecode(jsonString);

      setState(() {
        _position = Offset(data['dx'], data['dy']);
        _show = data['show'];
        _clickThrough = data['click-through'];
        _colorTheme = ColorTheme.values[data['color-theme']];
      });

      developer.log('loaded.', name: 'config.load');
    } catch (err) {
      _position = await windowManager.getPosition();
      _saveConfig(log: false);
      developer.log('created.', name: 'config.load');
    }
  }

  Future<void> _saveConfig({bool log = true}) async {
    final file = await _configFile;

    final data = <String, dynamic>{
      'dx': _position!.dx,
      'dy': _position!.dy,
      'show': _show,
      'click-through': _clickThrough,
      'color-theme': _colorTheme.index,
    };
    await file.writeAsString(jsonEncode(data));

    if (log) {
      developer.log('saved.', name: 'config.save');
    }
  }

  @override
  void initState() {
    super.initState();

    _loadConfig().then((value) {
      const windowOption = WindowOptions(
        title: 'Battery Display',
        size: Size(200, 40),
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        alwaysOnTop: true,
      );
      windowManager.setPosition(_position!);

      windowManager.waitUntilReadyToShow(windowOption, () async {
        await Future.wait([
          windowManager.setAsFrameless(),
          windowManager.setResizable(false),
          windowManager.setMaximizable(false),
        ]);

        if (_clickThrough) {
          await windowManager.setIgnoreMouseEvents(true);
        } else {
          await windowManager.setIgnoreMouseEvents(false);
        }

        if (_show) {
          await windowManager.show();
        }
      });
    });

    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);

    super.dispose();
  }

  @override
  void onWindowMoved() {
    windowManager.getPosition().then((position) {
      _position = position;
      _saveConfig();
    });
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.setContextMenu(_generateMenu()).then((value) {
      trayManager.popUpContextMenu();
    });
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'show':
        if (item.checked!) {
          _show = false;
          windowManager.hide();
        } else {
          _show = true;
          windowManager.show();
        }
        _saveConfig();

      case 'click-through':
        if (item.checked!) {
          setState(() {
            _clickThrough = false;
          });
          windowManager.setIgnoreMouseEvents(false);
        } else {
          setState(() {
            _clickThrough = true;
          });
          windowManager.setIgnoreMouseEvents(true);
        }
        _saveConfig();

      case 'color-theme-dark':
        if (!item.checked!) {
          setState(() {
            _colorTheme = ColorTheme.dark;
          });
        }
        _saveConfig();

      case 'color-theme-light':
        if (!item.checked!) {
          setState(() {
            _colorTheme = ColorTheme.light;
          });
        }
        _saveConfig();

      case 'open-directory':
        _openDirectory();

      case 'exit':
        _saveConfig().then((value) {
          exit(0);
        });

      default:
        break;
    }
  }

  Future<void> _openDirectory() async {
    final path = await _localPath;
    launchUrl(Uri(scheme: 'file', path: path));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'D-Din',
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomPaint(
          painter: _clickThrough ? null : NotClickthoughPainter(),
          child: Container(
            decoration: _clickThrough
                ? null
                : BoxDecoration(
                    border: Border.all(width: 1, color: Colors.black),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  windowManager.startDragging();
                },
                child: BatteryDisplay(
                  colorTheme: _colorTheme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotClickthoughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pattern = DiagonalStripesLight(
      bgColor: Colors.white30,
      fgColor: Colors.black54,
      featuresCount: 30,
    );
    final rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      const Radius.circular(8),
    );
    pattern.paintOnRRect(
      canvas,
      size,
      rrect,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class BatteryDisplay extends StatefulWidget {
  const BatteryDisplay({
    super.key,
    this.colorTheme = ColorTheme.dark,
  });

  final ColorTheme colorTheme;

  @override
  State<BatteryDisplay> createState() => _BatteryDisplayState();
}

class _BatteryDisplayState extends State<BatteryDisplay> {
  bool _hasBattery = true;
  int _percentage = 100;
  final Battery _battery = Battery();
  Timer? _batteryQueryTimer;

  Color _getBackgroundColor(ColorTheme colorMode) {
    return switch (colorMode) {
      ColorTheme.dark => const Color.fromRGBO(0, 0, 0, 0.5),
      ColorTheme.light => const Color.fromRGBO(255, 255, 255, 0.5)
    };
  }

  Color _getColor(ColorTheme colorMode) {
    return switch (colorMode) {
      ColorTheme.dark => Colors.white,
      ColorTheme.light => Colors.black,
    };
  }

  IconData _getBatteryIcon() {
    int stage = (_percentage / 100.0 * 8.0).floor();

    return switch (stage) {
      0 => Icons.battery_0_bar_rounded,
      1 => Icons.battery_1_bar_rounded,
      2 => Icons.battery_2_bar_rounded,
      3 => Icons.battery_3_bar_rounded,
      4 => Icons.battery_4_bar_rounded,
      5 => Icons.battery_5_bar_rounded,
      6 => Icons.battery_6_bar_rounded,
      _ => Icons.battery_full_rounded,
    };
  }

  Future<void> _getBatteryLevel() async {
    try {
      int percentage = await _battery.batteryLevel;

      setState(() {
        _percentage = percentage;
        _hasBattery = true;
      });
    } catch (err) {
      setState(() {
        _hasBattery = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _getBatteryLevel();
    _batteryQueryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        _getBatteryLevel();
      },
    );
  }

  @override
  void dispose() {
    _batteryQueryTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(Object context) {
    return Container(
      decoration: BoxDecoration(
        color: _getBackgroundColor(widget.colorTheme),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      height: 32,
      constraints: const BoxConstraints(minWidth: 80),
      child: UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        child: _hasBattery
            ? SizedBox(
                width: 54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Transform.rotate(
                      angle: math.pi / 2,
                      child: Icon(
                        _getBatteryIcon(),
                        color: _getColor(widget.colorTheme),
                      ),
                    ),
                    Text(
                      _percentage.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: _getColor(widget.colorTheme),
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    "No Battery",
                    style: TextStyle(color: _getColor(widget.colorTheme)),
                  ),
                ),
              ),
      ),
    );
  }
}
