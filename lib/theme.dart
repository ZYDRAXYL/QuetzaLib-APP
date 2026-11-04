import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// QuetzaLib's brand seed: the emerald green of the quetzal in the app
/// icon, rather than Flutter's stock purple. Every color role in both the
/// light and dark theme is derived from it, so the library, the scanner,
/// and the settings screen all tint the same way.
const _seedColor = Color(0xFF1B7A3C);

/// Corner radii, kept in one place so a cover thumbnail, a shelf tile, and
/// a card don't each invent their own rounding.
abstract final class AppRadius {
  /// Cover/spine artwork and page thumbnails.
  static const double cover = 8;

  /// Cards, sheets, and other surfaces that group content.
  static const double surface = 18;

  /// Text fields and other input surfaces.
  static const double field = 14;

  /// Chips and small inline badges — softly rounded rather than fully
  /// pill-shaped, so a row of them reads as a set of tags instead of a
  /// row of buttons.
  static const double chip = 10;

  /// Rows and small square-ish tiles: list tiles, the leading icon block
  /// of a tile, and menu surfaces.
  static const double tile = 12;

  /// Buttons and other pill-shaped controls.
  static const double pill = 999;
}

/// A soft drop shadow for book artwork, so a cover reads as a physical
/// object sitting on the shelf instead of a flat rectangle pasted onto the
/// background. Tuned per brightness: shadows all but disappear on a dark
/// surface, so the dark variant leans harder on opacity.
List<BoxShadow> coverShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

/// The color pair a single reading status renders with: [foreground] on
/// [container] for chips and avatars, and [onScrim] for the shelf views'
/// status badge, which sits on a dark scrim over cover artwork rather than
/// on a themed surface.
@immutable
class StatusColors {
  const StatusColors({
    required this.foreground,
    required this.container,
    required this.onScrim,
  });

  final Color foreground;
  final Color container;
  final Color onScrim;

  static StatusColors lerp(StatusColors a, StatusColors b, double t) {
    return StatusColors(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      onScrim: Color.lerp(a.onScrim, b.onScrim, t)!,
    );
  }
}

/// The semantic colors for reading statuses, carried on the theme so the
/// status chip, the stamp timeline, and the shelf badge all read the same
/// palette — and so it can differ between light and dark without any
/// widget having to check the brightness itself.
///
/// These are deliberately *not* `ColorScheme` roles: "finished" needs to be
/// green and "dropped" red regardless of the brand seed, the same way an
/// error color is semantic rather than decorative. Every foreground/container
/// pair below clears WCAG AA (4.5:1) in its own brightness.
@immutable
class StatusPalette extends ThemeExtension<StatusPalette> {
  const StatusPalette({
    required this.notStarted,
    required this.reading,
    required this.finished,
    required this.dropped,
    required this.paused,
  });

  final StatusColors notStarted;
  final StatusColors reading;
  final StatusColors finished;
  final StatusColors dropped;
  final StatusColors paused;

  static const light = StatusPalette(
    notStarted: StatusColors(
      foreground: Color(0xFF46505A),
      container: Color(0xFFE6E9EC),
      onScrim: Color(0xFFC3C9CE),
    ),
    reading: StatusColors(
      foreground: Color(0xFF8A5000),
      container: Color(0xFFFFE9C7),
      onScrim: Color(0xFFFFCC80),
    ),
    finished: StatusColors(
      foreground: Color(0xFF1B5E20),
      container: Color(0xFFD7F0D5),
      onScrim: Color(0xFFA5D6A7),
    ),
    dropped: StatusColors(
      foreground: Color(0xFF9F2A24),
      container: Color(0xFFFFE0DD),
      onScrim: Color(0xFFF2B8B5),
    ),
    paused: StatusColors(
      foreground: Color(0xFF16497A),
      container: Color(0xFFD9E7FB),
      onScrim: Color(0xFFAECBFA),
    ),
  );

  static const dark = StatusPalette(
    notStarted: StatusColors(
      foreground: Color(0xFFC3C9CE),
      container: Color(0xFF34393E),
      onScrim: Color(0xFFC3C9CE),
    ),
    reading: StatusColors(
      foreground: Color(0xFFFFCC80),
      container: Color(0xFF4A3413),
      onScrim: Color(0xFFFFCC80),
    ),
    finished: StatusColors(
      foreground: Color(0xFFA5D6A7),
      container: Color(0xFF1E3A21),
      onScrim: Color(0xFFA5D6A7),
    ),
    dropped: StatusColors(
      foreground: Color(0xFFF2B8B5),
      container: Color(0xFF4E2320),
      onScrim: Color(0xFFF2B8B5),
    ),
    paused: StatusColors(
      foreground: Color(0xFFAECBFA),
      container: Color(0xFF1B3350),
      onScrim: Color(0xFFAECBFA),
    ),
  );

  /// The palette in effect for [context], falling back to [light] if the
  /// extension somehow isn't installed (a bare `MaterialApp` in a test).
  static StatusPalette of(BuildContext context) =>
      Theme.of(context).extension<StatusPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  StatusPalette copyWith({
    StatusColors? notStarted,
    StatusColors? reading,
    StatusColors? finished,
    StatusColors? dropped,
    StatusColors? paused,
  }) {
    return StatusPalette(
      notStarted: notStarted ?? this.notStarted,
      reading: reading ?? this.reading,
      finished: finished ?? this.finished,
      dropped: dropped ?? this.dropped,
      paused: paused ?? this.paused,
    );
  }

  @override
  StatusPalette lerp(ThemeExtension<StatusPalette>? other, double t) {
    if (other is! StatusPalette) return this;
    return StatusPalette(
      notStarted: StatusColors.lerp(notStarted, other.notStarted, t),
      reading: StatusColors.lerp(reading, other.reading, t),
      finished: StatusColors.lerp(finished, other.finished, t),
      dropped: StatusColors.lerp(dropped, other.dropped, t),
      paused: StatusColors.lerp(paused, other.paused, t),
    );
  }
}

/// Builds the app theme for [brightness]. `main.dart` builds both and lets
/// `ThemeMode.system` pick, so the app follows the device's dark mode.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = _buildColorScheme(brightness);
  final textTheme = _buildTextTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,

    // The app bar stays flush with the content underneath it — no tint or
    // shadow on scroll. What separates the bar from the list is the title's
    // weight, not a line: screen titles are set a step larger and bolder
    // than a section title so the hierarchy is carried by type.
    appBarTheme: AppBarThemeData(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.secondaryContainer,
      elevation: 3,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        );
      }),
    ),

    // Cards separate themselves from the page by their fill, not by an
    // outline: a screen made of stacked cards reads as soft blocks rather
    // than as a stack of framed boxes. `Clip.antiAlias` means a card can
    // hold an image, an `InkWell` ripple, or a divider right up to its own
    // rounded edge without any of them squaring off the corner.
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
    ),

    // Filled rather than outlined: a form of six fields reads as a stack of
    // soft blocks instead of six competing rectangles of border.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none,
      ),
      // No border at rest — the fill alone says "this is a field". The
      // focus and error rings stay, since those carry state a fill can't.
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    ),

    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(textTheme)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(textTheme)),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: textTheme.titleLarge,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      textStyle: textTheme.bodyMedium,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
      space: 1,
      thickness: 1,
    ),

    tabBarTheme: TabBarThemeData(
      dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.7),
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),

    extensions: [isDark ? StatusPalette.dark : StatusPalette.light],
  );
}

/// The seeded Material 3 scheme, with the icon's gold mapped onto the
/// `tertiary` role so it's available as a brand accent that doesn't
/// compete with the green primary.
ColorScheme _buildColorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  if (brightness == Brightness.dark) {
    return base.copyWith(
      tertiary: const Color(0xFFEFC24B),
      onTertiary: const Color(0xFF3F2E00),
      tertiaryContainer: const Color(0xFF5B4300),
      onTertiaryContainer: const Color(0xFFFFDF9A),
    );
  }
  return base.copyWith(
    tertiary: const Color(0xFF7A5900),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFFFE08C),
    onTertiaryContainer: const Color(0xFF261A00),
  );
}

/// Tightens the default Material scale a little: headings and titles get
/// negative tracking and more weight so a book title reads as a heading,
/// and secondary/meta text is toned to `onSurfaceVariant` at the source
/// rather than every screen re-coloring `bodySmall` itself.
TextTheme _buildTextTheme(ColorScheme colorScheme) {
  final base = Typography.material2021(colorScheme: colorScheme)
      .black
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
        // The web build has no system Thai font; without a bundled fallback
        // it fetches Noto Sans Thai from a CDN and Thai disappears offline.
        // Set here, not on ThemeData, because the app bar and button themes
        // below take their styles straight from this text theme.
        fontFamilyFallback: kIsWeb ? const ['NotoSansThai'] : null,
      );
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    bodySmall: base.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
  );
}

ButtonStyle _buttonStyle(TextTheme textTheme) {
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
    ),
  );
}
