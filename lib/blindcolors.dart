import 'package:flutter/material.dart';

class BlindColors {
  final Color smallBlind;
  final Color bigBlind;
  final int bigCount;

  BlindColors({required this.smallBlind, required this.bigBlind, required this.bigCount});

  String getSmallCount() {
    return bigCount == 1 ? "1" : (bigCount / 2).toString();
  }

  String getBigCount() {
    return bigCount.toString();
  }
}

Color invertColor(Color color) {
  return Color.fromRGBO(
    255 - color.red,
    255 - color.green,
    255 - color.blue,
    color.opacity,
  );
}

Widget buildBlindIcon(Color color, String text) {
  return Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.circle, color: color, size: 100.0),
      Text(text, style: TextStyle(color: invertColor(color), fontWeight: FontWeight.bold, fontSize: 24)),
    ],
  );
}