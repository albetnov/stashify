import 'package:flutter/material.dart';

const _seed = Color(0xFF0B6B4F);

final lightScheme = ColorScheme.fromSeed(seedColor: _seed);

final darkScheme = ColorScheme.fromSeed(
  seedColor: _seed,
  brightness: Brightness.dark,
);

final lightTheme = ThemeData(colorScheme: lightScheme);
final darkTheme = ThemeData(colorScheme: darkScheme);
