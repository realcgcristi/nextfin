import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../storage/app_storage.dart';
import '../storage/providers.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (Ref ref) => ThemeModeController(ref.watch(appStorageProvider)),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._storage) : super(_storage.loadThemeMode());

  final AppStorage _storage;

  Future<void> update(ThemeMode value) async {
    state = value;
    await _storage.saveThemeMode(value);
  }
}

final clientSettingsProvider =
    StateNotifierProvider<ClientSettingsController, ClientSettings>(
      (Ref ref) => ClientSettingsController(ref.watch(appStorageProvider)),
    );

class ClientSettingsController extends StateNotifier<ClientSettings> {
  ClientSettingsController(this._storage)
    : super(_storage.loadClientSettings());

  final AppStorage _storage;

  Future<void> update(ClientSettings value) async {
    state = value;
    await _storage.saveClientSettings(value);
  }
}

@immutable
class ThemeMood extends ThemeExtension<ThemeMood> {
  const ThemeMood({
    required this.appBackgroundTop,
    required this.appBackgroundBottom,
    required this.appGlow,
    required this.navSurface,
    required this.navBorder,
    required this.heroStart,
    required this.heroEnd,
    required this.cardTint,
    required this.previewTop,
    required this.previewBottom,
  });

  final Color appBackgroundTop;
  final Color appBackgroundBottom;
  final Color appGlow;
  final Color navSurface;
  final Color navBorder;
  final Color heroStart;
  final Color heroEnd;
  final Color cardTint;
  final Color previewTop;
  final Color previewBottom;

  @override
  ThemeExtension<ThemeMood> copyWith({
    Color? appBackgroundTop,
    Color? appBackgroundBottom,
    Color? appGlow,
    Color? navSurface,
    Color? navBorder,
    Color? heroStart,
    Color? heroEnd,
    Color? cardTint,
    Color? previewTop,
    Color? previewBottom,
  }) {
    return ThemeMood(
      appBackgroundTop: appBackgroundTop ?? this.appBackgroundTop,
      appBackgroundBottom: appBackgroundBottom ?? this.appBackgroundBottom,
      appGlow: appGlow ?? this.appGlow,
      navSurface: navSurface ?? this.navSurface,
      navBorder: navBorder ?? this.navBorder,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      cardTint: cardTint ?? this.cardTint,
      previewTop: previewTop ?? this.previewTop,
      previewBottom: previewBottom ?? this.previewBottom,
    );
  }

  @override
  ThemeExtension<ThemeMood> lerp(
    covariant ThemeExtension<ThemeMood>? other,
    double t,
  ) {
    if (other is! ThemeMood) return this;
    return ThemeMood(
      appBackgroundTop:
          Color.lerp(appBackgroundTop, other.appBackgroundTop, t)!,
      appBackgroundBottom:
          Color.lerp(appBackgroundBottom, other.appBackgroundBottom, t)!,
      appGlow: Color.lerp(appGlow, other.appGlow, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      navBorder: Color.lerp(navBorder, other.navBorder, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      cardTint: Color.lerp(cardTint, other.cardTint, t)!,
      previewTop: Color.lerp(previewTop, other.previewTop, t)!,
      previewBottom: Color.lerp(previewBottom, other.previewBottom, t)!,
    );
  }
}

class ThemePaletteDefinition {
  const ThemePaletteDefinition({
    required this.id,
    required this.name,
    required this.lightSeed,
    required this.darkSeed,
    required this.lightMood,
    required this.darkMood,
  });

  final AppThemePalette id;
  final String name;
  final Color lightSeed;
  final Color darkSeed;
  final ThemeMood lightMood;
  final ThemeMood darkMood;
}

const List<ThemePaletteDefinition> themePalettes = <ThemePaletteDefinition>[
  ThemePaletteDefinition(
    id: AppThemePalette.nextfin,
    name: 'Nextfin Violet',
    lightSeed: Color(0xFF6C63FF),
    darkSeed: Color(0xFF8C86FF),
    lightMood: ThemeMood(
      appBackgroundTop: Color(0xFFF8F3FF),
      appBackgroundBottom: Color(0xFFE7EAFF),
      appGlow: Color(0x336C63FF),
      navSurface: Color(0xEEF6F1FF),
      navBorder: Color(0xFFD8D0F3),
      heroStart: Color(0xFFE8DEFF),
      heroEnd: Color(0xFFDDE7FF),
      cardTint: Color(0xFFF4EEFF),
      previewTop: Color(0xFFF2EBFF),
      previewBottom: Color(0xFFDCE6FF),
    ),
    darkMood: ThemeMood(
      appBackgroundTop: Color(0xFF0E1020),
      appBackgroundBottom: Color(0xFF15192B),
      appGlow: Color(0x447D74FF),
      navSurface: Color(0xEE171A2E),
      navBorder: Color(0xFF3A4264),
      heroStart: Color(0xFF241E43),
      heroEnd: Color(0xFF17253B),
      cardTint: Color(0xFF1A2134),
      previewTop: Color(0xFF1E1B3B),
      previewBottom: Color(0xFF18253A),
    ),
  ),
  ThemePaletteDefinition(
    id: AppThemePalette.arctic,
    name: 'Arctic Blue',
    lightSeed: Color(0xFF1D9BF0),
    darkSeed: Color(0xFF57C8FF),
    lightMood: ThemeMood(
      appBackgroundTop: Color(0xFFF0FBFF),
      appBackgroundBottom: Color(0xFFE0F1FF),
      appGlow: Color(0x3326A6FF),
      navSurface: Color(0xEEF0FAFF),
      navBorder: Color(0xFFC9DDEF),
      heroStart: Color(0xFFD8F1FF),
      heroEnd: Color(0xFFD9E8FF),
      cardTint: Color(0xFFEDF8FF),
      previewTop: Color(0xFFE4F7FF),
      previewBottom: Color(0xFFD8EFFF),
    ),
    darkMood: ThemeMood(
      appBackgroundTop: Color(0xFF08131B),
      appBackgroundBottom: Color(0xFF0E1D28),
      appGlow: Color(0x334DD4FF),
      navSurface: Color(0xEE10212B),
      navBorder: Color(0xFF2E4B59),
      heroStart: Color(0xFF143548),
      heroEnd: Color(0xFF173143),
      cardTint: Color(0xFF122632),
      previewTop: Color(0xFF103446),
      previewBottom: Color(0xFF132B39),
    ),
  ),
  ThemePaletteDefinition(
    id: AppThemePalette.emerald,
    name: 'Emerald Night',
    lightSeed: Color(0xFF0D9B74),
    darkSeed: Color(0xFF34D3A2),
    lightMood: ThemeMood(
      appBackgroundTop: Color(0xFFF1FFF8),
      appBackgroundBottom: Color(0xFFE2F4EA),
      appGlow: Color(0x3328B884),
      navSurface: Color(0xEEF2FBF6),
      navBorder: Color(0xFFCFE3D6),
      heroStart: Color(0xFFD9F5E7),
      heroEnd: Color(0xFFDCEFE8),
      cardTint: Color(0xFFEFFAF4),
      previewTop: Color(0xFFE2F7EE),
      previewBottom: Color(0xFFD7F0E4),
    ),
    darkMood: ThemeMood(
      appBackgroundTop: Color(0xFF081814),
      appBackgroundBottom: Color(0xFF0D201A),
      appGlow: Color(0x3339D2A4),
      navSurface: Color(0xEE11251D),
      navBorder: Color(0xFF2C4B3E),
      heroStart: Color(0xFF183C30),
      heroEnd: Color(0xFF123127),
      cardTint: Color(0xFF132820),
      previewTop: Color(0xFF16372C),
      previewBottom: Color(0xFF132A22),
    ),
  ),
  ThemePaletteDefinition(
    id: AppThemePalette.rose,
    name: 'Rose Signal',
    lightSeed: Color(0xFFCC4A80),
    darkSeed: Color(0xFFFF7CAD),
    lightMood: ThemeMood(
      appBackgroundTop: Color(0xFFFFF2F7),
      appBackgroundBottom: Color(0xFFF9E4EE),
      appGlow: Color(0x33FF6BA5),
      navSurface: Color(0xEEFDF2F6),
      navBorder: Color(0xFFE7CDD9),
      heroStart: Color(0xFFFFDCE8),
      heroEnd: Color(0xFFF7E0F1),
      cardTint: Color(0xFFFFF0F5),
      previewTop: Color(0xFFFFE5EF),
      previewBottom: Color(0xFFF8DCEB),
    ),
    darkMood: ThemeMood(
      appBackgroundTop: Color(0xFF1A0C14),
      appBackgroundBottom: Color(0xFF24111C),
      appGlow: Color(0x44FF6DA3),
      navSurface: Color(0xEE2A1521),
      navBorder: Color(0xFF5A3045),
      heroStart: Color(0xFF442032),
      heroEnd: Color(0xFF35203E),
      cardTint: Color(0xFF2A1722),
      previewTop: Color(0xFF3B1C2D),
      previewBottom: Color(0xFF311B2A),
    ),
  ),
  ThemePaletteDefinition(
    id: AppThemePalette.cinema,
    name: 'Cinema Amber',
    lightSeed: Color(0xFFE08A1E),
    darkSeed: Color(0xFFFFB347),
    lightMood: ThemeMood(
      appBackgroundTop: Color(0xFFFFF6ED),
      appBackgroundBottom: Color(0xFFF7E9D7),
      appGlow: Color(0x33FFAF4A),
      navSurface: Color(0xEEFDF5EE),
      navBorder: Color(0xFFE6D2BB),
      heroStart: Color(0xFFFFE4BF),
      heroEnd: Color(0xFFF7E0C8),
      cardTint: Color(0xFFFFF5EA),
      previewTop: Color(0xFFFFEACC),
      previewBottom: Color(0xFFF5DFC3),
    ),
    darkMood: ThemeMood(
      appBackgroundTop: Color(0xFF1A1208),
      appBackgroundBottom: Color(0xFF23180B),
      appGlow: Color(0x33FFB24A),
      navSurface: Color(0xEE281D11),
      navBorder: Color(0xFF5A4127),
      heroStart: Color(0xFF47321A),
      heroEnd: Color(0xFF352617),
      cardTint: Color(0xFF2A1F13),
      previewTop: Color(0xFF3D2A16),
      previewBottom: Color(0xFF312113),
    ),
  ),
];

ThemePaletteDefinition paletteFor(AppThemePalette palette) {
  return themePalettes.firstWhere(
    (ThemePaletteDefinition item) => item.id == palette,
    orElse: () => themePalettes.first,
  );
}

ThemeMood themeMoodOf(BuildContext context) =>
    Theme.of(context).extension<ThemeMood>()!;

ThemeData buildNextfinTheme(
  Brightness brightness, {
  required AppThemePalette palette,
  required LayoutDensity density,
}) {
  final isDark = brightness == Brightness.dark;
  final selection = paletteFor(palette);
  final mood = isDark ? selection.darkMood : selection.lightMood;
  final seed = isDark ? selection.darkSeed : selection.lightSeed;
  final base = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: seed,
    surface: mood.appBackgroundTop,
  );
  final body = GoogleFonts.dmSansTextTheme().apply(
    bodyColor: base.onSurface,
    displayColor: base.onSurface,
  );
  final display = GoogleFonts.soraTextTheme().apply(
    bodyColor: base.onSurface,
    displayColor: base.onSurface,
  );
  final textTheme = body.copyWith(
    displayLarge: display.displayLarge,
    displayMedium: display.displayMedium,
    displaySmall: display.displaySmall,
    headlineLarge: display.headlineLarge,
    headlineMedium: display.headlineMedium,
    headlineSmall: display.headlineSmall,
    titleLarge: display.titleLarge,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
  final panel = Color.alphaBlend(
    seed.withValues(alpha: isDark ? 0.14 : 0.08),
    mood.cardTint,
  );
  final raised = Color.alphaBlend(
    seed.withValues(alpha: isDark ? 0.24 : 0.16),
    mood.heroStart,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: <ThemeExtension<dynamic>>[mood],
    colorScheme: base.copyWith(
      surface: mood.appBackgroundTop,
      surfaceContainerLowest: mood.appBackgroundBottom,
      surfaceContainerLow: panel,
      surfaceContainer: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.18 : 0.12),
        mood.cardTint,
      ),
      surfaceContainerHigh: raised,
      surfaceContainerHighest: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.3 : 0.22),
        mood.heroEnd,
      ),
      outlineVariant: mood.navBorder,
      shadow: Colors.black,
      primaryContainer: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.44 : 0.3),
        mood.heroStart,
      ),
      tertiaryContainer: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.24 : 0.18),
        mood.heroEnd,
      ),
    ),
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -2.8,
        height: 0.86,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
        height: 0.88,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        height: 0.9,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.42),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.38),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    scaffoldBackgroundColor: mood.appBackgroundTop,
    visualDensity:
        density == LayoutDensity.compact
            ? const VisualDensity(horizontal: -0.8, vertical: -0.8)
            : VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _FastFadePageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: _FastFadePageTransitionsBuilder(),
        TargetPlatform.windows: _FastFadePageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 72,
      indicatorColor: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.38 : 0.28),
        base.primaryContainer,
      ),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          fontSize: 11.5,
        ),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color:
              selected
                  ? base.onPrimaryContainer
                  : base.onSurfaceVariant.withValues(alpha: 0.84),
          size: selected ? 22 : 20,
        );
      }),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: base.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: base.onSurface,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: base.surfaceContainerLow.withValues(alpha: 0.84),
      shape: shape,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.18 : 0.11),
        base.surfaceContainer,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: base.outlineVariant.withValues(alpha: 0.55)),
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: base.surfaceContainerLow.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: base.surfaceContainerLow.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    dividerTheme: DividerThemeData(
      color: base.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        side: BorderSide(color: base.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: base.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: base.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: base.primary, width: 1.6),
      ),
      filled: true,
      fillColor: Color.alphaBlend(
        seed.withValues(alpha: isDark ? 0.14 : 0.08),
        base.surface,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      prefixIconColor: base.onSurfaceVariant,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: base.onSurfaceVariant.withValues(alpha: 0.9),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      iconColor: base.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: base.primary,
      linearTrackColor: base.outlineVariant.withValues(alpha: 0.35),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      activeTrackColor: base.primary,
      inactiveTrackColor: base.outlineVariant.withValues(alpha: 0.34),
    ),
  );
}

class _FastFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FastFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.9, curve: Curves.easeOutCubic),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.015, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
