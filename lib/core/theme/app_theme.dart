import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's colours, read with `context.sb`. Two themes, each with a light
/// and a dark version:
///
/// * Ink (the default): near-black ink on a soft grey page, white cards and
///   one quiet blue accent.
/// * Espresso: a cream canvas, espresso text and buttons, caramel accents.
///
/// Layouts, type and spacing are the same in every palette; only colour
/// changes. People's faces take their tint from the palette too.
@immutable
class SbPalette extends ThemeExtension<SbPalette> {
  const SbPalette({
    required this.canvas,
    required this.surface,
    required this.fill,
    required this.track,
    required this.text,
    required this.text2,
    required this.text3,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.honey,
    required this.oweBg,
    required this.oweFg,
    required this.late,
    required this.lateDot,
    required this.goodBg,
    required this.goodFg,
    required this.hairline,
    required this.shadow,
    required this.accentTint,
    required this.meBg,
    required this.meFg,
    required this.faces,
    required this.tintCool,
    required this.tintWarm,
    required this.tintGreen,
    required this.tintRed,
    required this.tintGold,
  });

  /// Page background.
  final Color canvas;

  /// Cards, sheets, the bottom bar.
  final Color surface;

  /// Dividers and quiet fills (secondary buttons, inactive chips).
  final Color fill;

  /// Progress tracks, switch tracks, input outlines.
  final Color track;

  final Color text;
  final Color text2;

  /// Only for large text: too light for body copy.
  final Color text3;

  /// Main buttons, the selected tab, switches.
  final Color primary;
  final Color onPrimary;

  /// Small highlights: the person's name, the "Now" line, links.
  final Color accent;

  /// Icons and letters on espresso.
  final Color honey;

  /// "You owe" tags.
  final Color oweBg;
  final Color oweFg;

  /// Late items.
  final Color late;
  final Color lateDot;

  /// Done, settled, moving.
  final Color goodBg;
  final Color goodFg;

  /// Card outline (dark mode only; light cards use a soft shadow).
  final Color hairline;
  final Color shadow;

  /// Behind accent-coloured chips ("2 calls to wrap up").
  final Color accentTint;

  /// Your own face (the profile button).
  final Color meBg;
  final Color meFg;

  /// People's faces; a person always gets the same one ([faceFor]).
  final List<SbTint> faces;

  /// Icon tiles: blue-grey, warm, green, red and gold.
  final SbTint tintCool;
  final SbTint tintWarm;
  final SbTint tintGreen;
  final SbTint tintRed;
  final SbTint tintGold;

  /// The face tint for [name]: the same person always gets the same one.
  SbTint faceFor(String name) => faces[SbTint.hashOf(name) % faces.length];

  static const light = SbPalette(
    canvas: Color(0xFFF3ECE2),
    surface: Color(0xFFFFFCF7),
    fill: Color(0xFFEFE5D7),
    track: Color(0xFFE6D9C8),
    text: Color(0xFF26190F),
    text2: Color(0xFF6A5A4C),
    text3: Color(0xFF8C7A69),
    primary: Color(0xFF2B1D16),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF8A5A1F),
    honey: Color(0xFFE8B86A),
    oweBg: Color(0xFFF6DCD2),
    oweFg: Color(0xFF8E3320),
    late: Color(0xFFA33A22),
    lateDot: Color(0xFFC4472E),
    goodBg: Color(0xFFE0E9DA),
    goodFg: Color(0xFF3E5931),
    hairline: Color(0x00000000),
    shadow: Color(0x142B1D16),
    accentTint: Color(0xFFF4E6D2),
    meBg: Color(0xFFE8B86A),
    meFg: Color(0xFF2A1C15),
    faces: SbTint.espresso,
    tintCool: SbTint.slate,
    tintWarm: SbTint.mocha,
    tintGreen: SbTint.sage,
    tintRed: SbTint.cherry,
    tintGold: SbTint.gold,
  );

  static const dark = SbPalette(
    canvas: Color(0xFF17110D),
    surface: Color(0xFF221A14),
    fill: Color(0xFF2E241C),
    track: Color(0xFF3A2E25),
    text: Color(0xFFF3ECE2),
    text2: Color(0xFFBCAE9F),
    text3: Color(0xFF8E8071),
    primary: Color(0xFFF3ECE2),
    onPrimary: Color(0xFF26190F),
    accent: Color(0xFFE2B47A),
    honey: Color(0xFFE8B86A),
    oweBg: Color(0xFF3A2019),
    oweFg: Color(0xFFF2A58E),
    late: Color(0xFFF28B74),
    lateDot: Color(0xFFE06B50),
    goodBg: Color(0xFF24301F),
    goodFg: Color(0xFFA9C79A),
    hairline: Color(0x0DFFFFFF),
    shadow: Color(0x4D000000),
    accentTint: Color(0xFF3A2B1B),
    meBg: Color(0xFFE8B86A),
    meFg: Color(0xFF2A1C15),
    faces: SbTint.espresso,
    tintCool: SbTint.slate,
    tintWarm: SbTint.mocha,
    tintGreen: SbTint.sage,
    tintRed: SbTint.cherry,
    tintGold: SbTint.gold,
  );

  /// Espresso by name.
  static const espressoLight = light;
  static const espressoDark = dark;

  /// Ink, light: the default.
  static const inkLight = SbPalette(
    canvas: Color(0xFFF4F4F1),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFEBEBE7),
    track: Color(0xFFDADAD5),
    text: Color(0xFF18181B),
    text2: Color(0xFF5C5C63),
    text3: Color(0xFF77777F),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF3451C6),
    honey: Color(0xFF93A8FF),
    oweBg: Color(0xFFFBE7E2),
    oweFg: Color(0xFF9E2F19),
    late: Color(0xFFB4361E),
    lateDot: Color(0xFFC9432A),
    goodBg: Color(0xFFE3F0E6),
    goodFg: Color(0xFF2F6B3F),
    hairline: Color(0x00000000),
    shadow: Color(0x1418181B),
    accentTint: Color(0xFFE8ECFB),
    meBg: Color(0xFFE8ECFB),
    meFg: Color(0xFF3451C6),
    faces: SbTint.ink,
    tintCool: SbTint.inkSky,
    tintWarm: SbTint.inkSand,
    tintGreen: SbTint.inkSage,
    tintRed: SbTint.inkRose,
    tintGold: SbTint.inkGold,
  );

  /// Ink, dark.
  static const inkDark = SbPalette(
    canvas: Color(0xFF111113),
    surface: Color(0xFF1C1C20),
    fill: Color(0xFF2A2A30),
    track: Color(0xFF3A3A42),
    text: Color(0xFFF2F2F4),
    text2: Color(0xFFA9A9B2),
    text3: Color(0xFF7E7E88),
    primary: Color(0xFFF2F2F4),
    onPrimary: Color(0xFF18181B),
    accent: Color(0xFF93A8FF),
    honey: Color(0xFF3451C6),
    oweBg: Color(0xFF3B201B),
    oweFg: Color(0xFFFFB3A3),
    late: Color(0xFFFF8B73),
    lateDot: Color(0xFFF0705A),
    goodBg: Color(0xFF1E3325),
    goodFg: Color(0xFF9BD3A9),
    hairline: Color(0x0DFFFFFF),
    shadow: Color(0x4D000000),
    accentTint: Color(0xFF232A45),
    meBg: Color(0xFF232A45),
    meFg: Color(0xFF93A8FF),
    faces: SbTint.ink,
    tintCool: SbTint.inkSky,
    tintWarm: SbTint.inkSand,
    tintGreen: SbTint.inkSage,
    tintRed: SbTint.inkRose,
    tintGold: SbTint.inkGold,
  );

  @override
  SbPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? fill,
    Color? track,
    Color? text,
    Color? text2,
    Color? text3,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? honey,
    Color? oweBg,
    Color? oweFg,
    Color? late,
    Color? lateDot,
    Color? goodBg,
    Color? goodFg,
    Color? hairline,
    Color? shadow,
    Color? accentTint,
    Color? meBg,
    Color? meFg,
    List<SbTint>? faces,
    SbTint? tintCool,
    SbTint? tintWarm,
    SbTint? tintGreen,
    SbTint? tintRed,
    SbTint? tintGold,
  }) {
    return SbPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      fill: fill ?? this.fill,
      track: track ?? this.track,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      honey: honey ?? this.honey,
      oweBg: oweBg ?? this.oweBg,
      oweFg: oweFg ?? this.oweFg,
      late: late ?? this.late,
      lateDot: lateDot ?? this.lateDot,
      goodBg: goodBg ?? this.goodBg,
      goodFg: goodFg ?? this.goodFg,
      hairline: hairline ?? this.hairline,
      shadow: shadow ?? this.shadow,
      accentTint: accentTint ?? this.accentTint,
      meBg: meBg ?? this.meBg,
      meFg: meFg ?? this.meFg,
      faces: faces ?? this.faces,
      tintCool: tintCool ?? this.tintCool,
      tintWarm: tintWarm ?? this.tintWarm,
      tintGreen: tintGreen ?? this.tintGreen,
      tintRed: tintRed ?? this.tintRed,
      tintGold: tintGold ?? this.tintGold,
    );
  }

  @override
  SbPalette lerp(ThemeExtension<SbPalette>? other, double t) {
    if (other is! SbPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SbPalette(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      fill: l(fill, other.fill),
      track: l(track, other.track),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      honey: l(honey, other.honey),
      oweBg: l(oweBg, other.oweBg),
      oweFg: l(oweFg, other.oweFg),
      late: l(late, other.late),
      lateDot: l(lateDot, other.lateDot),
      goodBg: l(goodBg, other.goodBg),
      goodFg: l(goodFg, other.goodFg),
      hairline: l(hairline, other.hairline),
      shadow: l(shadow, other.shadow),
      accentTint: l(accentTint, other.accentTint),
      meBg: l(meBg, other.meBg),
      meFg: l(meFg, other.meFg),
      faces: t < 0.5 ? faces : other.faces,
      tintCool: SbTint.lerp(tintCool, other.tintCool, t),
      tintWarm: SbTint.lerp(tintWarm, other.tintWarm, t),
      tintGreen: SbTint.lerp(tintGreen, other.tintGreen, t),
      tintRed: SbTint.lerp(tintRed, other.tintRed, t),
      tintGold: SbTint.lerp(tintGold, other.tintGold, t),
    );
  }
}

extension SbThemeContext on BuildContext {
  /// The app's colours for the current theme and brightness.
  SbPalette get sb => Theme.of(this).extension<SbPalette>() ?? SbPalette.inkLight;
}

/// Soft tints for faces and icon tiles. The same in light and dark mode; each
/// palette has its own set ([SbPalette.faces]).
@immutable
class SbTint {
  const SbTint(this.bg, this.fg);
  final Color bg;
  final Color fg;

  static const mocha = SbTint(Color(0xFFEADFD6), Color(0xFF6B4430));
  static const cherry = SbTint(Color(0xFFF7DDD3), Color(0xFF8E3321));
  static const sage = SbTint(Color(0xFFE1EADB), Color(0xFF3F5A32));
  static const rose = SbTint(Color(0xFFF5DCD3), Color(0xFF8A3A26));
  static const slate = SbTint(Color(0xFFE2E6EC), Color(0xFF3C4E66));
  static const neutral = SbTint(Color(0xFFEAE1D4), Color(0xFF4A3B30));

  static const gold = SbTint(Color(0xFFF4E3C4), Color(0xFF7A4B0F));

  static const espresso = [mocha, cherry, sage, rose, slate, neutral];

  // Ink: cooler, greyer tints that sit on white and on near-black.
  static const inkSky = SbTint(Color(0xFFE1E8F5), Color(0xFF2F4C82));
  static const inkRose = SbTint(Color(0xFFF6E1DC), Color(0xFF8A3324));
  static const inkSage = SbTint(Color(0xFFE2ECE3), Color(0xFF2F5B38));
  static const inkSand = SbTint(Color(0xFFEFE6D6), Color(0xFF6B4F22));
  static const inkLilac = SbTint(Color(0xFFECE4F3), Color(0xFF5B3B7A));
  static const inkStone = SbTint(Color(0xFFE9E8E4), Color(0xFF4A4A50));
  static const inkGold = SbTint(Color(0xFFF6EAD6), Color(0xFF7A4A00));

  static const ink = [inkSky, inkRose, inkSage, inkSand, inkLilac, inkStone];

  /// Espresso's set, for code that has no palette at hand.
  static const all = espresso;

  /// A stable hash of a name, so a person keeps their tint.
  static int hashOf(String name) {
    var hash = 0;
    for (final unit in name.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static SbTint forName(String name) => all[hashOf(name) % all.length];

  static SbTint lerp(SbTint a, SbTint b, double t) => SbTint(Color.lerp(a.bg, b.bg, t)!, Color.lerp(a.fg, b.fg, t)!);
}

class AppFonts {
  /// Text: Inter, with Noto Sans Ethiopic for Amharic.
  static const body = 'Inter';
  static const bodyFallback = ['NotoEthiopic'];

  /// Headlines and big numbers: Bricolage Grotesque, with Menbere for Amharic.
  static const display = 'Bricolage';
  static const displayFallback = ['Menbere', 'NotoEthiopic'];
}

/// Espresso light colours for screens not yet moved to [SbPalette].
class AppColors {
  static const primary = Color(0xFF2B1D16); // Espresso
  static const primaryLight = Color(0xFF8A5A1F); // Caramel
  static const primaryDark = Color(0xFF1A110C);

  static const background = Color(0xFFF3ECE2); // Cream
  static const surface = Color(0xFFFFFCF7);
  static const surfaceElevated = Color(0xFFEFE5D7);
  static const error = Color(0xFFA33A22);
  static const success = Color(0xFF3E5931);

  static const textPrimary = Color(0xFF26190F);
  static const textSecondary = Color(0xFF6A5A4C);
  static const textTertiary = Color(0xFF8C7A69);

  static const divider = Color(0xFFEFE5D7);
  static const border = Color(0xFFE6D9C8);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

class AppRadius {
  /// Tags and small chips.
  static const double sm = 10.0;

  /// Inputs.
  static const double md = 18.0;

  /// Cards.
  static const double lg = 24.0;

  /// Sheets and dialogs.
  static const double xl = 28.0;
  static const double pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get button => BorderRadius.circular(pill);
  static BorderRadius get input => BorderRadius.circular(md);
  static BorderRadius get chip => BorderRadius.circular(sm);
}

class AppTheme {
  /// See-through status and navigation bars, so the canvas runs edge to edge
  /// as on the boards (older Android versions otherwise draw a grey band).
  static SystemUiOverlayStyle systemBars(Brightness brightness) {
    final light = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: brightness,
      systemNavigationBarColor: const Color(0x00000000),
      systemNavigationBarDividerColor: const Color(0x00000000),
      systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  /// Espresso, as on the "Espresso · final" boards.
  static ThemeData get lightTheme => _build(SbPalette.light, Brightness.light);
  static ThemeData get darkTheme => _build(SbPalette.dark, Brightness.dark);

  /// The chosen theme, light.
  static ThemeData light(AppThemeName name) =>
      _build(name == AppThemeName.espresso ? SbPalette.espressoLight : SbPalette.inkLight, Brightness.light);

  /// The chosen theme, dark.
  static ThemeData dark(AppThemeName name) =>
      _build(name == AppThemeName.espresso ? SbPalette.espressoDark : SbPalette.inkDark, Brightness.dark);

  static TextStyle _display(SbPalette p, double size, double lineHeight, double letterSpacing) => TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.w800,
    letterSpacing: letterSpacing,
    color: p.text,
  );

  static TextStyle _body(
    SbPalette p,
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    // Material's defaults add up to 0.5 px of tracking; Inter needs none.
    letterSpacing: 0,
    color: color ?? p.text,
  );

  static TextTheme _textTheme(SbPalette p) => TextTheme(
    displayLarge: _display(p, 52, 58, -2),
    displayMedium: _display(p, 44, 48, -1.6),
    displaySmall: _display(p, 36, 40, -1.2),
    headlineLarge: _display(p, 34, 40, -1.1),
    headlineMedium: _display(p, 30, 34, -0.9),
    headlineSmall: _display(p, 24, 30, -0.5),
    titleLarge: _body(p, 20, 26, weight: FontWeight.w700),
    titleMedium: _body(p, 17, 22, weight: FontWeight.w700),
    titleSmall: _body(p, 15, 20, weight: FontWeight.w600),
    bodyLarge: _body(p, 16, 24),
    bodyMedium: _body(p, 15, 22),
    bodySmall: _body(p, 13, 18, color: p.text2),
    labelLarge: _body(p, 15, 20, weight: FontWeight.w600),
    labelMedium: _body(p, 13, 18, weight: FontWeight.w700, color: p.text2),
    labelSmall: _body(p, 12, 16, weight: FontWeight.w600, color: p.text2),
  );

  static ThemeData _build(SbPalette p, Brightness brightness) {
    final text = _textTheme(p);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.fill,
      onPrimaryContainer: p.text,
      secondary: p.accent,
      onSecondary: p.onPrimary,
      secondaryContainer: p.fill,
      onSecondaryContainer: p.text,
      tertiary: p.honey,
      onTertiary: const Color(0xFF2A1C15),
      error: p.late,
      onError: const Color(0xFFFFFFFF),
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.text2,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.fill,
      surfaceContainerHighest: p.fill,
      outline: p.track,
      outlineVariant: p.fill,
      inverseSurface: p.primary,
      onInverseSurface: p.onPrimary,
      inversePrimary: p.honey,
      surfaceTint: const Color(0x00000000),
    );
    final buttonText = _body(p, 15, 20, weight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.bodyFallback,
      textTheme: text,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      extensions: [p],
      appBarTheme: AppBarTheme(
        systemOverlayStyle: AppTheme.systemBars(brightness),
        backgroundColor: p.canvas,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _body(p, 20, 26, weight: FontWeight.w700),
        iconTheme: IconThemeData(color: p.text),
      ),
      iconTheme: IconThemeData(color: p.text),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: p.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.track),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: p.track),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: p.track),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: p.late),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: p.late, width: 2),
        ),
        hintStyle: _body(p, 16, 22, color: p.text3),
        labelStyle: _body(p, 15, 20, color: p.text2),
      ),
      dividerTheme: DividerThemeData(color: p.fill, space: 1, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: p.fill,
        selectedColor: p.primary,
        labelStyle: _body(p, 13, 18, weight: FontWeight.w600),
        secondaryLabelStyle: _body(p, 13, 18, weight: FontWeight.w600, color: p.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.surface),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.track),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : const Color(0x00000000),
        ),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.track, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.track,
        circularTrackColor: p.track,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.primary,
        contentTextStyle: _body(p, 15, 20, color: p.onPrimary),
        actionTextColor: p.honey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.track,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: _body(p, 20, 26, weight: FontWeight.w700),
        contentTextStyle: _body(p, 15, 22, color: p.text2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        highlightElevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: buttonText,
      ),
      listTileTheme: ListTileThemeData(iconColor: p.text2, textColor: p.text),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.text2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

/// The two themes you can pick in Settings.
enum AppThemeName {
  ink,
  espresso
  ;

  static AppThemeName fromName(String? name) =>
      AppThemeName.values.firstWhere((t) => t.name == name, orElse: () => AppThemeName.ink);
}
