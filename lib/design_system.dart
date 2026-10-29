import 'package:flutter/material.dart';

const eyeMedBlue = Color(0xff1469d8);
const eyeMedInk = Color(0xff18324d);
const eyeMedMuted = Color(0xff52677e);
const eyeMedBackground = Color(0xfff0f6fc);
const eyeMedBorder = Color(0xffd7e4f0);

const titleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: eyeMedInk,
  height: 1.35,
);
const sectionStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: eyeMedInk,
  height: 1.4,
);

ThemeData eyeMedTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: eyeMedBlue,
    primary: eyeMedBlue,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: eyeMedInk,
    onSurfaceVariant: eyeMedMuted,
    outline: const Color(0xff7991a8),
    outlineVariant: eyeMedBorder,
    primaryContainer: const Color(0xffe4efff),
    onPrimaryContainer: const Color(0xff124c98),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: eyeMedBorder),
  );
  return base.copyWith(
    scaffoldBackgroundColor: eyeMedBackground,
    textTheme: base.textTheme
        .apply(bodyColor: eyeMedInk, displayColor: eyeMedInk)
        .copyWith(
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: eyeMedInk,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: eyeMedInk,
          ),
          titleLarge: titleStyle,
          titleMedium: sectionStyle,
          labelLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: eyeMedBackground,
      foregroundColor: eyeMedInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: eyeMedInk,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: eyeMedBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xfff8fbff),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: eyeMedBlue, width: 2),
      ),
      errorMaxLines: 4,
      helperMaxLines: 4,
      floatingLabelStyle: const TextStyle(color: eyeMedBlue),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: rounded,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: rounded,
        side: const BorderSide(color: eyeMedBorder),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xfff6f9fe),
      selectedColor: scheme.primaryContainer,
      labelStyle: const TextStyle(color: eyeMedInk, fontSize: 15),
      side: const BorderSide(color: eyeMedBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      showCheckmark: true,
      checkmarkColor: eyeMedBlue,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 13,
          color: states.contains(WidgetState.selected)
              ? eyeMedBlue
              : eyeMedMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: eyeMedBorder, space: 24),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: eyeMedInk,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

Widget panel(List<Widget> children) => Card(
  margin: const EdgeInsets.only(bottom: 16),
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (widget) => Padding(
              key: widget.key == null ? null : _PanelChildKey(widget.key!),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: widget,
            ),
          )
          .toList(),
    ),
  ),
);

// Keep keyed form fields alive when inline feedback is inserted before them.
class _PanelChildKey extends ValueKey<Key> {
  const _PanelChildKey(super.value);
}
