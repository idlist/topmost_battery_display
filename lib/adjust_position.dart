import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'constants.dart';

bool _inside(Offset point, Offset position, Size size) {
  return point.dx >= position.dx &&
      point.dx <= position.dx + size.width &&
      point.dy >= position.dy &&
      point.dy <= position.dy + size.height;
}

Future<Offset> getAdjustedPosition(Offset original) async {
  final primary = await screenRetriever.getPrimaryDisplay();
  final screens = await screenRetriever.getAllDisplays();

  for (var screen in screens) {
    if (_inside(original, screen.visiblePosition!, screen.visibleSize!)) {
      if (screen.name == primary.name) {
        return original;
      } else {
        final ratio = (screen.scaleFactor! / primary.scaleFactor!).toDouble();
        return original * ratio;
      }
    }
  }

  return defaultPosition;
}
