import 'dart:io';
import 'dart:developer' as developer;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:patterns_canvas/patterns_canvas.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constants.dart';
import 'battery_display.dart';
import 'adjust_position.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  launchAtStartup.setup(
    appName: 'Topmost Battery Display',
    appPath: Platform.resolvedExecutable,
  );

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

  await trayManager.setToolTip("Topmost Battery Display");
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WindowListener, TrayListener {
  Offset? _position;
  bool _show = true;
  bool _clickThrough = false;
  ColorTheme _colorTheme = ColorTheme.dark;
  late String _version;
  bool _launchAtStartup = false;

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
        _position = Offset(
          (data['dx'] as num).toDouble(),
          (data['dy'] as num).toDouble(),
        );
        _show = data['show'];
        _clickThrough = data['click-through'];
        _colorTheme = ColorTheme.values[data['color-theme']];
        _launchAtStartup = data['launch-at-startup'];
      });

      developer.log('loaded.', name: 'config.load');
    } catch (err) {
      _position = await windowManager.getPosition();
      _saveConfig(log: false);
      developer.log('created.', name: 'config.load');
    }
  }

  Future<void> _saveConfig({bool log = true}) async {
    _position = await windowManager.getPosition();
    final file = await _configFile;

    final data = <String, dynamic>{
      'dx': _position!.dx,
      'dy': _position!.dy,
      'show': _show,
      'click-through': _clickThrough,
      'color-theme': _colorTheme.index,
      'launch-at-startup': _launchAtStartup,
    };
    await file.writeAsString(jsonEncode(data));

    if (log) {
      developer.log('saved.', name: 'config.save');
    }
  }

  @override
  void initState() {
    super.initState();

    PackageInfo.fromPlatform().then((info) {
      _version = info.version;
    });

    _loadConfig().then((value) {
      const windowOption = WindowOptions(
        title: 'Battery Display',
        size: Size(200, 40),
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        alwaysOnTop: true,
      );
      getAdjustedPosition(_position!).then((position) {
        windowManager.setPosition(position);
      });

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

  Menu _generateMenu() {
    return Menu(
      items: [
        MenuItem.checkbox(
          checked: _show,
          key: 'show',
          label: 'Show Widget',
        ),
        MenuItem.checkbox(
          checked: _launchAtStartup,
          key: 'launch-at-startup',
          label: 'Launch At Startup',
        ),
        MenuItem.separator(),
        MenuItem.checkbox(
          checked: _clickThrough,
          key: 'click-through',
          label: 'Click-through',
        ),
        MenuItem.submenu(
          key: 'color-theme',
          label: 'Color Theme',
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
        MenuItem.submenu(
          key: 'advanced',
          label: 'Advanced Options',
          submenu: Menu(
            items: [
              MenuItem(
                key: 'open-directory',
                label: 'Open Data Folder',
              ),
              MenuItem(
                key: 'reset-position',
                label: 'Reset Position',
              ),
            ],
          ),
        ),
        MenuItem.separator(),
        MenuItem(
          disabled: true,
          label: 'Topmost Battery Display $_version',
        ),
        MenuItem(
          key: 'github-repo',
          label: 'GitHub Repository',
        ),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
  }

  Future<void> _openMenu() async {
    await trayManager.setContextMenu(_generateMenu());
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() {
    _openMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    _openMenu();
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

      case 'launch-at-startup':
        if (item.checked!) {
          _launchAtStartup = false;
          launchAtStartup.disable();
        } else {
          _launchAtStartup = true;
          launchAtStartup.enable();
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

      case 'reset-position':
        windowManager.setPosition(defaultPosition).then((value) {
          _saveConfig();
        });

      case 'github-repo':
        launchUrl(Uri(
          scheme: 'https',
          path: 'github.com/idlist/topmost_battery_display',
        ));

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
