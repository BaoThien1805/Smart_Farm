import 'package:flutter/material.dart';

abstract final class FarmColors {
  static const cream = Color(0xFFFFFCF5);
  static const cocoa = Color(0xFF3A261C);
  static const teal = Color(0xFF187360);
  static const muted = Color(0xFF716257);
  static const border = Color(0xFFF0EAE1);
  static const mint = Color(0xFFE0F5E9);
  static const peach = Color(0xFFFFE8CD);
  static const lavender = Color(0xFFEAE0FF);
  static const sky = Color(0xFFE1F2FF);
  static const amber = Color(0xFFFFF0C7);
  static const danger = Color(0xFFAF302C);
  static const dangerSurface = Color(0xFFFFE9E5);
  static const warning = Color(0xFF805000);
  static const info = Color(0xFF235D82);
  static const purple = Color(0xFF63418F);
  static const blue = Color(0xFF087DCE);
  static const lilac = Color(0xFF7946D5);
  static const coral = Color(0xFFDF7952);
  static const gold = Color(0xFFE59A00);
}

abstract final class FarmSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class FarmRadii {
  static const field = 12.0;
  static const card = 16.0;
  static const dialog = 24.0;
  static const pill = 100.0;
}

// Keep the existing public names for pages that already use this theme.
const forest = FarmColors.teal;
const canvas = FarmColors.cream;
const ink = FarmColors.cocoa;
const muted = FarmColors.muted;
const line = FarmColors.border;

ThemeData farmTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: forest,
        brightness: Brightness.light,
      ).copyWith(
        primary: forest,
        onPrimary: Colors.white,
        primaryContainer: FarmColors.mint,
        onPrimaryContainer: forest,
        secondary: forest,
        secondaryContainer: FarmColors.mint,
        onSecondaryContainer: forest,
        tertiaryContainer: FarmColors.lavender,
        onTertiaryContainer: FarmColors.purple,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: canvas,
        surfaceContainer: canvas,
        surfaceContainerHigh: FarmColors.mint,
        surfaceContainerHighest: FarmColors.mint,
        outline: muted,
        outlineVariant: line,
        error: FarmColors.danger,
        onError: Colors.white,
        errorContainer: FarmColors.dangerSurface,
        onErrorContainer: FarmColors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    // Bundled from Flutter's material_fonts, with its Apache license in assets/.
    fontFamily: 'FarmRoboto',
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: canvas,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 24),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: forest,
      selectedColor: forest,
      selectedTileColor: FarmColors.mint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: FarmColors.mint,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      iconTheme: WidgetStateProperty.fromMap({
        WidgetState.selected: IconThemeData(color: forest),
        WidgetState.any: IconThemeData(color: Color(0xFF77767D)),
      }),
      labelTextStyle: WidgetStateProperty.fromMap({
        WidgetState.selected: TextStyle(
          fontSize: 11,
          color: forest,
          fontWeight: FontWeight.w600,
        ),
        WidgetState.any: TextStyle(fontSize: 11, color: Color(0xFF666770)),
      }),
      surfaceTintColor: Colors.transparent,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: FarmColors.mint,
      selectedIconTheme: IconThemeData(color: forest),
      selectedLabelTextStyle: TextStyle(
        color: forest,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: muted),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FarmRadii.dialog),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: forest,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontFamily: 'FarmRoboto',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? muted
              : states.contains(WidgetState.selected)
              ? Colors.white
              : ink,
        ),
      ),
      side: const BorderSide(color: line),
      padding: const EdgeInsets.symmetric(
        horizontal: FarmSpacing.sm,
        vertical: FarmSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FarmRadii.pill),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: muted),
      floatingLabelStyle: const TextStyle(color: forest),
      hintStyle: const TextStyle(color: muted),
      helperStyle: const TextStyle(color: muted, height: 1.4),
      errorStyle: const TextStyle(color: FarmColors.danger, height: 1.4),
      errorMaxLines: 4,
      contentPadding: const EdgeInsets.all(FarmSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
        borderSide: const BorderSide(color: forest, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
        borderSide: const BorderSide(color: FarmColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmRadii.field),
        borderSide: const BorderSide(color: FarmColors.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: FarmSpacing.xl,
          vertical: FarmSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FarmRadii.field),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: forest),
        padding: const EdgeInsets.symmetric(
          horizontal: FarmSpacing.lg,
          vertical: FarmSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FarmRadii.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Color(0x0F3A261C),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FarmRadii.card),
        side: const BorderSide(color: line),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'FarmRound',
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FarmRadii.dialog),
        ),
      ),
    ),
  );
}

class FeedbackBox extends StatelessWidget {
  final String message;
  final bool isError;
  const FeedbackBox(this.message, {super.key, this.isError = true});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? FarmColors.dangerSurface : FarmColors.mint,
        borderRadius: BorderRadius.circular(FarmRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? FarmColors.danger : forest,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: isError ? FarmColors.danger : forest),
            ),
          ),
        ],
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  final bool light;
  const Brand({super.key, this.light = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: .12) : FarmColors.mint,
          borderRadius: BorderRadius.circular(FarmRadii.field),
        ),
        child: Icon(
          Icons.spa_outlined,
          color: light ? Colors.white : forest,
          size: 26,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          'smartfarm',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: light ? Colors.white : forest,
          ),
        ),
      ),
    ],
  );
}
