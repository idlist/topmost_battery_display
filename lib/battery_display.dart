import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';

import 'constants.dart';

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
