import 'package:flutter/material.dart';

class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void toggleTheme() {
    themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
