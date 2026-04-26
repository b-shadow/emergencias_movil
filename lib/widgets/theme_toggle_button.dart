import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: isDark ? 'Activar modo claro' : 'Activar modo oscuro',
          onPressed: AppThemeController.toggleTheme,
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
        );
      },
    );
  }
}
