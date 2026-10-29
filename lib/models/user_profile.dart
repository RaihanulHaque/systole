import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Demographics the on-device model uses as inputs (age, sex, height, weight).
class UserProfile {
  final String name;
  final int age;
  final bool isMale;
  final double heightCm;
  final double weightKg;

  const UserProfile({
    this.name = '',
    this.age = 30,
    this.isMale = true,
    this.heightCm = 170,
    this.weightKg = 70,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    String? name,
    int? age,
    bool? isMale,
    double? heightCm,
    double? weightKg,
  }) => UserProfile(
    name: name ?? this.name,
    age: age ?? this.age,
    isMale: isMale ?? this.isMale,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'isMale': isMale,
    'heightCm': heightCm,
    'weightKg': weightKg,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String? ?? '',
    age: (j['age'] as num?)?.toInt() ?? 30,
    isMale: j['isMale'] as bool? ?? true,
    heightCm: (j['heightCm'] as num?)?.toDouble() ?? 170,
    weightKg: (j['weightKg'] as num?)?.toDouble() ?? 70,
  );

  static const _key = 'user_profile';

  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
