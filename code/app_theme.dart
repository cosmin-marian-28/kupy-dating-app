import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static final ValueNotifier<bool> isDark = ValueNotifier(false);
  static final ValueNotifier<bool> isDrinkBuddy = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool('dark_mode') ?? false;
  }

  static Future<void> toggle() async {
    isDark.value = !isDark.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark.value);
  }

  // ── Pink (light) — unchanged, exactly as before ──
  static const _pinkBg = Color(0xFFFFF0F5);
  static const _pinkPrimary = Color(0xFFFF4081);
  static const _pinkAccent = Color(0xFFFF80AB);
  static const _pinkText = Color(0xFF880E4F);
  static const _pinkCard = Colors.white;
  static const _pinkStroke = Color(0xFFFF80AB);
  static const _pinkGradient1 = Color(0xFFFF4081);
  static const _pinkGradient2 = Color(0xFFFF80AB);
  static const _pinkStrokeHard = Color(0xFFE91E63);

  // ── Dark — deep red/black, mirrors pink mode with red tones ──
  static const _darkBg = Color(0xFF1A0A0A);
  static const _darkPrimary = Color(0xFFFF6B6B);
  static const _darkAccent = Color(0xFFCC4444);
  static const _darkText = Color(0xFFFFCDD2);
  static const _darkCard = Color(0xFF2A1010);
  static const _darkStroke = Color(0xFF8B1A1A);
  static const _darkGradient1 = Color(0xFF7F0000);
  static const _darkGradient2 = Color(0xFFB71C1C);
  static const _darkStrokeHard = Color(0xFFE53935);

  // ── Amber / Drink Buddy (light) ──
  static const _amberBg = Color(0xFFFFF8E1);
  static const _amberPrimary = Color(0xFFFF8F00);
  static const _amberAccent = Color(0xFFFFCA28);
  static const _amberText = Color(0xFF5D4037);
  static const _amberCard = Colors.white;
  static const _amberStroke = Color(0xFFFFCA28);
  static const _amberGradient1 = Color(0xFFFF8F00);
  static const _amberGradient2 = Color(0xFFFFCA28);
  static const _amberStrokeHard = Color(0xFFF57C00);

  // ── Amber / Drink Buddy (dark) ──
  static const _amberDarkBg = Color(0xFF1A1400);
  static const _amberDarkPrimary = Color(0xFFFFB74D);
  static const _amberDarkAccent = Color(0xFFCC8800);
  static const _amberDarkText = Color(0xFFFFE0B2);
  static const _amberDarkCard = Color(0xFF2A2000);
  static const _amberDarkStroke = Color(0xFF8B6914);
  static const _amberDarkGradient1 = Color(0xFF7F5500);
  static const _amberDarkGradient2 = Color(0xFFB77B00);
  static const _amberDarkStrokeHard = Color(0xFFF57C00);

  static Color get bg {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkBg : _amberBg;
    return isDark.value ? _darkBg : _pinkBg;
  }
  static Color get primary {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkPrimary : _amberPrimary;
    return isDark.value ? _darkPrimary : _pinkPrimary;
  }
  static Color get accent {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkAccent : _amberAccent;
    return isDark.value ? _darkAccent : _pinkAccent;
  }
  static Color get text {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkText : _amberText;
    return isDark.value ? _darkText : _pinkText;
  }
  static Color get card {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkCard : _amberCard;
    return isDark.value ? _darkCard : _pinkCard;
  }
  static Color get stroke {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkStroke : _amberStroke;
    return isDark.value ? _darkStroke : _pinkStroke;
  }
  static Color get gradient1 {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkGradient1 : _amberGradient1;
    return isDark.value ? _darkGradient1 : _pinkGradient1;
  }
  static Color get gradient2 {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkGradient2 : _amberGradient2;
    return isDark.value ? _darkGradient2 : _pinkGradient2;
  }
  static Color get strokeHard {
    if (isDrinkBuddy.value) return isDark.value ? _amberDarkStrokeHard : _amberStrokeHard;
    return isDark.value ? _darkStrokeHard : _pinkStrokeHard;
  }
  static Color get subtleText {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFFFCC80) : _amberAccent.withValues(alpha: 0.7);
    return isDark.value ? const Color(0xFFEF9A9A) : _pinkAccent.withValues(alpha: 0.7);
  }
  static Color get pillShadow {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF4A3500).withValues(alpha: 0.5) : _amberAccent.withValues(alpha: 0.2);
    return isDark.value ? const Color(0xFF4A0000).withValues(alpha: 0.5) : _pinkAccent.withValues(alpha: 0.2);
  }
  static Color get barBg {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF2A2000) : Colors.white;
    return isDark.value ? const Color(0xFF2A1010) : Colors.white;
  }

  /// The icon/heart color used in buttons, icons, etc.
  static Color get iconColor {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFFFB74D) : _amberPrimary;
    return isDark.value ? const Color(0xFFFF5252) : _pinkPrimary;
  }

  /// Active tab gradient for bottom bar and title pills
  static List<Color> get activeGradient {
    if (isDrinkBuddy.value) {
      return isDark.value
        ? [_amberDarkGradient1, _amberDarkGradient2]
        : [_amberGradient1, _amberGradient2];
    }
    return isDark.value
        ? [const Color(0xFF7F0000), const Color(0xFFB71C1C)]
        : [_pinkGradient1, _pinkGradient2];
  }

  /// Avatar circle border
  static Color get avatarBorder {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFF57C00) : _amberAccent;
    return isDark.value ? const Color(0xFFE53935) : _pinkAccent;
  }
  static Color get avatarGlow {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0x33F57C00) : const Color(0x33FFCA28);
    return isDark.value ? const Color(0x33E53935) : const Color(0x33FF80AB);
  }

  /// Snackbar background
  static Color get snackbar {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF8B6914) : _amberPrimary;
    return isDark.value ? const Color(0xFF8B1A1A) : _pinkPrimary;
  }

  /// Avatar container background (behind images)
  static Color get avatarBg {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF2A2000) : const Color(0xFF3A3020);
    return isDark.value ? const Color(0xFF2A1010) : const Color(0xFFFFE0EC);
  }

  /// Placeholder icon color
  static Color get placeholder {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF7A6020) : _amberAccent.withValues(alpha: 0.5);
    return isDark.value ? const Color(0xFF7A2020) : const Color(0xFFFF80AB).withValues(alpha: 0.5);
  }

  /// Faded accent for empty states, subtitles
  static Color get fadedAccent {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFFFCC80) : const Color(0xFFFFCA28);
    return isDark.value ? const Color(0xFFEF9A9A) : const Color(0xFFFF80AB);
  }

  /// Heart animation colors
  static Color get heartBright {
    if (isDrinkBuddy.value) return const Color(0xFFFF8F00);
    return isDark.value ? const Color(0xFFFF1744) : const Color(0xFFFF1744);
  }
  static Color get heartSoft {
    if (isDrinkBuddy.value) return const Color(0xFFFFCA28);
    return isDark.value ? const Color(0xFFEF5350) : const Color(0xFFFF80AB);
  }
  static Color get heartGlow {
    if (isDrinkBuddy.value) return const Color(0x66FF8F00);
    return isDark.value ? const Color(0x66FF1744) : const Color(0x66FF1744);
  }

  /// Bomb target glow
  static Color get bombGlow {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFF57C00).withValues(alpha: 0.5) : _amberPrimary.withValues(alpha: 0.5);
    return isDark.value ? const Color(0xFFE53935).withValues(alpha: 0.5) : const Color(0xFFFF4081).withValues(alpha: 0.5);
  }

  /// Chip unselected text
  static Color get chipText {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFFFB74D) : _amberPrimary;
    return isDark.value ? const Color(0xFFFF6B6B) : _pinkPrimary;
  }

  /// Chip unselected fill
  static Color get chipFill {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFF2A2000) : Colors.white;
    return isDark.value ? const Color(0xFF2A1010) : Colors.white;
  }

  /// Brand title color (Komit logo text)
  static Color get brand {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFFFB74D) : const Color(0xFFFF8F00);
    return isDark.value ? const Color(0xFFFF5252) : const Color(0xFFFF0080);
  }
  static Color get brandShadow {
    if (isDrinkBuddy.value) return isDark.value ? const Color(0xFFF57C00).withValues(alpha: 0.3) : _amberAccent.withValues(alpha: 0.5);
    return isDark.value ? const Color(0xFFE53935).withValues(alpha: 0.3) : const Color(0xFFFF80AB).withValues(alpha: 0.5);
  }
}