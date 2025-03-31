import 'dart:convert';
import 'package:flutter/material.dart';

class ChipLevel {
  final Color smallBlindColor;
  final Color bigBlindColor;
  final int bigBlindMultiplier;

  const ChipLevel({
    required this.smallBlindColor,
    required this.bigBlindColor,
    required this.bigBlindMultiplier,
  });

  Map<String, dynamic> toJson() {
    return {
      'smallBlindColor': smallBlindColor.value,
      'bigBlindColor': bigBlindColor.value,
      'bigBlindMultiplier': bigBlindMultiplier,
    };
  }

  factory ChipLevel.fromJson(Map<String, dynamic> json) {
    return ChipLevel(
      smallBlindColor: Color(json['smallBlindColor']),
      bigBlindColor: Color(json['bigBlindColor']),
      bigBlindMultiplier: json['bigBlindMultiplier'],
    );
  }

  ChipLevel copyWith({
    Color? smallBlindColor,
    Color? bigBlindColor,
    int? bigBlindMultiplier,
  }) {
    return ChipLevel(
      smallBlindColor: smallBlindColor ?? this.smallBlindColor,
      bigBlindColor: bigBlindColor ?? this.bigBlindColor,
      bigBlindMultiplier: bigBlindMultiplier ?? this.bigBlindMultiplier,
    );
  }
}

class BlindSettings {
  final List<int> intervals;
  final List<ChipLevel> chipLevels;
  final double volume;

  const BlindSettings({
    required this.intervals,
    required this.chipLevels,
    this.volume = 1.0,
  });

  factory BlindSettings.defaultSettings() {
    return const BlindSettings(
      intervals: [45, 45, 30, 30, 15, 15, 5],
      chipLevels: [
        ChipLevel(
          smallBlindColor: Colors.blue,
          bigBlindColor: Colors.white,
          bigBlindMultiplier: 1,
        ),
        ChipLevel(
          smallBlindColor: Colors.white,
          bigBlindColor: Colors.black,
          bigBlindMultiplier: 1,
        ),
        ChipLevel(
          smallBlindColor: Colors.black,
          bigBlindColor: Colors.red,
          bigBlindMultiplier: 1,
        ),
        ChipLevel(
          smallBlindColor: Colors.red,
          bigBlindColor: Colors.green,
          bigBlindMultiplier: 1,
        ),
        ChipLevel(
          smallBlindColor: Colors.green,
          bigBlindColor: Colors.green,
          bigBlindMultiplier: 2,
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervals': intervals,
      'chipLevels': chipLevels.map((level) => level.toJson()).toList(),
      'volume': volume,
    };
  }

  factory BlindSettings.fromJson(Map<String, dynamic> json) {
    return BlindSettings(
      intervals: List<int>.from(json['intervals']),
      chipLevels: (json['chipLevels'] as List)
          .map((level) => ChipLevel.fromJson(level))
          .toList(),
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BlindSettings.fromJsonString(String jsonString) {
    return BlindSettings.fromJson(jsonDecode(jsonString));
  }

  BlindSettings copyWith({
    List<int>? intervals,
    List<ChipLevel>? chipLevels,
    double? volume,
  }) {
    return BlindSettings(
      intervals: intervals ?? this.intervals,
      chipLevels: chipLevels ?? this.chipLevels,
      volume: volume ?? this.volume,
    );
  }
}
