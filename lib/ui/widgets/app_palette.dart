import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';

/// One live palette for ambient light and decorative actions. Semantic status
/// colors (arrears, paid, water and electricity) keep their meaning.
class AppPaletteScope extends InheritedNotifier<AppConfig> {
  AppPaletteScope({super.key, required super.child})
      : super(notifier: AppConfig.instance);
}

class AppPalette {
  const AppPalette(this.ambient, this.actions);
  final List<Color> ambient;
  final List<Color> actions;

  static AppPalette of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppPaletteScope>();
    return forStyle(AppConfig.instance.backgroundStyle);
  }

  static AppPalette forStyle(String style) => switch (style) {
        'ocean' => const AppPalette(
            [Color(0xFF36C5F0), Color(0xFF235CCC), Color(0xFF6BE6DB)],
            [Color(0xFF17749A), Color(0xFF285FB4), Color(0xFF147A74)]),
        'sunset' => const AppPalette(
            [Color(0xFFFFAE6B), Color(0xFFCC60A5), Color(0xFFFF8C99)],
            [Color(0xFFAD5524), Color(0xFFA34B7B), Color(0xFFB84565)]),
        'jade' => const AppPalette(
            [Color(0xFF4EC7A3), Color(0xFF468A9B), Color(0xFFB9E3A8)],
            [Color(0xFF207B61), Color(0xFF286B79), Color(0xFF4C7337)]),
        'none' => const AppPalette(
            [Color(0xFF6080AB), Color(0xFF667894), Color(0xFF8797AF)],
            [Color(0xFF3767AE), Color(0xFF465D86), Color(0xFF4D617F)]),
        _ => const AppPalette(
            [Color(0xFF4C8DFF), Color(0xFF8A6BFF), Color(0xFFFF7EB6)],
            [Color(0xFF2E68CD), Color(0xFF6851C7), Color(0xFFBA4279)]),
      };

  LinearGradient get gradient => LinearGradient(
      begin: Alignment.centerLeft, end: Alignment.centerRight, colors: actions);

  Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(actions.first, Colors.white, .42)!
          : actions.first;
}
