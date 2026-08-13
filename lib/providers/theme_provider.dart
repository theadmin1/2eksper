import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AppThemeProvider extends ChangeNotifier {
  Map<String, dynamic> _theme = const {
    'renk_marka': '#0f172a',
    'renk_vurgu': '#0ea5e9',
    'renk_arkaplan': '#f0f9ff',
    'renk_yuzey': '#ffffff',
    'renk_metin': '#0f172a',
    'kose_yaricap': 20,
  };
  bool _loaded = false;
  ThemeMode _themeMode = ThemeMode.system;
  Map<String, dynamic> get values => _theme;
  ThemeMode get themeMode => _themeMode;

  AppThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString('app_theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', mode.name);
  }

  Future<void> toggleBrightness(Brightness current) => setThemeMode(
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );

  Color color(String key, Color fallback) {
    final raw = '${_theme[key] ?? ''}'.replaceFirst('#', '');
    final value = int.tryParse(raw, radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);
  ThemeData get materialTheme => lightTheme;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final brand = color('renk_marka', const Color(0xFF0F172A));
    final accent = color('renk_vurgu', const Color(0xFF0EA5E9));
    final primary = brand;
    final surface =
        isDark ? const Color(0xFF1E293B) : color('renk_yuzey', Colors.white);
    final background = isDark
        ? const Color(0xFF0F172A)
        : color('renk_arkaplan', const Color(0xFFF0F9FF));
    final text = isDark
        ? const Color(0xFFF8FAFC)
        : color('renk_metin', const Color(0xFF0F172A));
    final border = isDark
        ? const Color(0xFF334155)
        : color('renk_kenar', const Color(0xFFE0F2FE));
    final error = color('renk_hata', const Color(0xFFEF4444));
    final chrome = isDark ? const Color(0xFF0F172A) : brand;
    final radius = ((_theme['kose_yaricap'] as num?)?.toDouble() ?? 20)
        .clamp(0, 24)
        .toDouble();
    final fontSize =
        ((_theme['font_boyut'] as num?)?.toDouble() ?? 14).clamp(12, 17);
    final letterSpacing =
        ((_theme['harf_araligi'] as num?)?.toDouble() ?? 0) / 1000;
    final headingWeight =
        ((_theme['baslik_kalinlik'] as num?)?.toInt() ?? 800).clamp(600, 900);
    final bodyFont = '${_theme['font_govde'] ?? 'Inter'}';
    final headingFont = '${_theme['font_baslik'] ?? 'Plus Jakarta Sans'}';
    TextTheme textTheme = ThemeData(brightness: brightness).textTheme;
    if (bodyFont != 'Sistem Yazı Tipi') {
      textTheme = GoogleFonts.getTextTheme(bodyFont, textTheme);
    }
    textTheme = textTheme
        .apply(
            bodyColor: text,
            displayColor: text,
            fontSizeFactor: fontSize / 14,
            letterSpacingFactor: 1 + letterSpacing)
        .copyWith(
          titleLarge:
              _heading(textTheme.titleLarge, headingFont, headingWeight),
          titleMedium:
              _heading(textTheme.titleMedium, headingFont, headingWeight),
          headlineSmall:
              _heading(textTheme.headlineSmall, headingFont, headingWeight),
          headlineMedium:
              _heading(textTheme.headlineMedium, headingFont, headingWeight),
        );
    final density = switch ('${_theme['yogunluk'] ?? 'normal'}') {
      'sik' => VisualDensity.compact,
      'ferah' => VisualDensity.comfortable,
      _ => VisualDensity.standard,
    };
    final cardElevation = switch ('${_theme['golge'] ?? 'hafif'}') {
      'yok' => 0.0,
      'belirgin' => 5.0,
      _ => 1.5,
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF38BDF8),
      onSecondary: chrome,
      surface: surface,
      onSurface: text,
      error: error,
      outline: border,
      outlineVariant: border.withValues(alpha: .7),
    );
    final modernRadius = radius.clamp(18.0, 24.0);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      visualDensity: density,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: chrome,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: text.withValues(alpha: .62)),
        hintStyle: TextStyle(color: text.withValues(alpha: .42)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(modernRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(modernRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(modernRadius),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(modernRadius),
          borderSide: BorderSide(color: error),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shadowColor: primary.withValues(alpha: .12),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(modernRadius),
          side: BorderSide(color: border.withValues(alpha: .75)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: const Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(modernRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 52),
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(modernRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 50),
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(modernRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: chrome.withValues(alpha: .85),
        shadowColor: chrome.withValues(alpha: .2),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF38BDF8).withValues(alpha: .16),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF38BDF8)
                : Colors.white.withValues(alpha: .58),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF38BDF8)
                : Colors.white.withValues(alpha: .58),
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        dividerColor: Colors.transparent,
        labelColor: accent,
        unselectedLabelColor: Colors.white.withValues(alpha: .66),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(modernRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF24344A) : brand,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: chrome,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? chrome : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: isDark ? .25 : .14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  TextStyle? _heading(TextStyle? base, String font, int weight) {
    if (base == null) return null;
    final style =
        base.copyWith(fontWeight: FontWeight.values[(weight ~/ 100) - 1]);
    return font == 'Sistem Yazı Tipi'
        ? style
        : GoogleFonts.getFont(font,
            textStyle: style, fontWeight: style.fontWeight);
  }

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final res = await ApiService.get('tema.php');
      if (res['status'] == true) {
        final responseData = ApiData.map(res['data']);
        final serverTheme = ApiData.map(responseData['tema']);
        if (serverTheme.isNotEmpty) _theme = {..._theme, ...serverTheme};
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void apply(Map<String, dynamic> value) {
    _theme = Map<String, dynamic>.from(value);
    _loaded = true;
    notifyListeners();
  }
}
