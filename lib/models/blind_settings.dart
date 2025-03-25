import 'dart:convert';

class BlindSettings {
  final List<int> intervals;
  
  const BlindSettings({
    required this.intervals,
  });

  factory BlindSettings.defaultSettings() {
    return const BlindSettings(
      intervals: [45, 45, 30, 30, 15, 15],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervals': intervals,
    };
  }

  factory BlindSettings.fromJson(Map<String, dynamic> json) {
    return BlindSettings(
      intervals: List<int>.from(json['intervals']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BlindSettings.fromJsonString(String jsonString) {
    return BlindSettings.fromJson(jsonDecode(jsonString));
  }

  BlindSettings copyWith({
    List<int>? intervals,
  }) {
    return BlindSettings(
      intervals: intervals ?? this.intervals,
    );
  }
}
