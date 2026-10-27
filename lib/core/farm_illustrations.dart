import 'dart:convert';

import 'package:flutter/material.dart';

import 'photo_view.dart';
import 'theme.dart';

/// Presentation aliases only. Pass the species record's code/name, never an
/// animal/pen code or a database ID. Unknown species deliberately stay neutral.
enum FarmSpeciesArt {
  cow('cow', 'Bò'),
  pig('pig', 'Heo'),
  goat('goat', 'Dê'),
  chicken('chicken', 'Gà'),
  buffalo('buffalo', 'Trâu'),
  sheep('sheep', 'Cừu'),
  duck('duck', 'Vịt'),
  muscovy('muscovy', 'Ngan'),
  goose('goose', 'Ngỗng'),
  fish('fish', 'Cá'),
  shrimp('shrimp', 'Tôm'),
  rabbit('rabbit', 'Thỏ');

  const FarmSpeciesArt(this.filename, this.label);
  final String filename;
  final String label;
  String get asset => 'assets/illustrations/$filename.png';

  static FarmSpeciesArt? fromSpecies({String? code, String? name}) {
    FarmSpeciesArt? match(String? value) =>
        switch (value?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')) {
          'bo' || 'bò' || 'bò sữa' || 'bò thịt' || 'cow' || 'cattle' => cow,
          'he' || 'heo' || 'lợn' || 'lon' || 'pig' => pig,
          'de' || 'dê' || 'goat' => goat,
          'ga' || 'gà' || 'chicken' => chicken,
          'tr' || 'trau' || 'trâu' || 'buffalo' || 'water buffalo' => buffalo,
          'cu' || 'cuu' || 'cừu' || 'sheep' => sheep,
          'vi' || 'vit' || 'vịt' || 'duck' => duck,
          'ng' ||
          'ngan' ||
          'vịt xiêm' ||
          'vit xiem' ||
          'muscovy' ||
          'muscovy duck' => muscovy,
          'no' || 'ngong' || 'ngỗng' || 'goose' => goose,
          'ca' || 'cá' || 'fish' => fish,
          'to' || 'tom' || 'tôm' || 'shrimp' || 'prawn' => shrimp,
          'th' || 'tho' || 'thỏ' || 'rabbit' => rabbit,
          _ => null,
        };
    return match(code) ?? match(name);
  }
}

/// A sticker for a known species, or a barn for an unknown species or
/// failed asset. Set decorative when an adjacent text already names the species.
class FarmSpeciesIllustration extends StatelessWidget {
  const FarmSpeciesIllustration({
    super.key,
    this.speciesCode,
    this.speciesName,
    this.size = 64,
    this.decorative = false,
    this.semanticLabel,
    this.fallbackWidget,
  }) : assert(size > 0 && size < double.infinity);

  final String? speciesCode;
  final String? speciesName;
  final double size;
  final bool decorative;
  final String? semanticLabel;
  final Widget? fallbackWidget;

  @override
  Widget build(BuildContext context) {
    final art = FarmSpeciesArt.fromSpecies(
      code: speciesCode,
      name: speciesName,
    );
    return ExcludeSemantics(
      excluding: decorative,
      child: Semantics(
        image: true,
        label: semanticLabel ?? art?.label ?? 'Vật nuôi',
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: art == null
              ? fallbackWidget ?? _unknownSpeciesArt(size)
              : Image.asset(
                  art.asset,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  cacheWidth: 384,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      fallbackWidget ?? _unknownSpeciesArt(size),
                ),
        ),
      ),
    );
  }
}

Widget _unknownSpeciesArt(double size) =>
    FarmPenIllustration(size: size, decorative: true);

/// Reuses the existing base64 photo renderer. A valid uploaded photo always wins;
/// only an empty/malformed/undecodable photo falls back to the species sticker.
/// If the species has no sticker, use the same barn fallback as pen cards.
class FarmAnimalImage extends StatelessWidget {
  const FarmAnimalImage({
    super.key,
    required this.photoData,
    this.speciesCode,
    this.speciesName,
    this.size = 64,
    this.semanticLabel = 'Ảnh vật nuôi',
  }) : assert(size > 0 && size < double.infinity);

  final String photoData;
  final String? speciesCode;
  final String? speciesName;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => PhotoView(
    data: photoData,
    size: size,
    label: semanticLabel,
    fallbackWidget: FarmSpeciesIllustration(
      speciesCode: speciesCode,
      speciesName: speciesName,
      size: size,
      decorative: true,
    ),
  );
}

/// Pens may hold several species. This widget intentionally accepts no pen code
/// and uses the residents resolved by the repository for every farm.
class FarmPenIllustration extends StatelessWidget {
  const FarmPenIllustration({
    super.key,
    this.size = 64,
    this.decorative = false,
    this.speciesNames = const [],
    this.iconKey = 'auto',
    this.iconData = '',
  }) : assert(size > 0 && size < double.infinity);

  static const asset = 'assets/illustrations/barn.png';
  final double size;
  final bool decorative;
  final List<String> speciesNames;
  final String iconKey, iconData;

  @override
  Widget build(BuildContext context) {
    if (iconKey == 'custom' && iconData.isNotEmpty) {
      try {
        return ExcludeSemantics(
          excluding: decorative,
          child: Semantics(
            image: true,
            label: 'Icon chuồng',
            child: SizedBox.square(
              dimension: size,
              child: Image.memory(
                base64Decode(iconData.split(',').last),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _automatic(),
              ),
            ),
          ),
        );
      } on FormatException {
        return _automatic();
      }
    }
    if (iconKey == 'barn') return _barn();
    final selected = FarmSpeciesArt.values
        .where((art) => art.filename == iconKey)
        .firstOrNull;
    if (selected != null) {
      return FarmSpeciesIllustration(
        speciesName: selected.label,
        size: size,
        decorative: decorative,
      );
    }
    return _automatic();
  }

  Widget _automatic() {
    final names = speciesNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (names.length == 1 &&
        FarmSpeciesArt.fromSpecies(name: names.single) != null) {
      return FarmSpeciesIllustration(
        speciesName: names.single,
        size: size,
        decorative: decorative,
        fallbackWidget: _barn(),
      );
    }
    return _barn();
  }

  Widget _barn() => ExcludeSemantics(
    excluding: decorative,
    child: Semantics(
      label: 'Chuồng trại',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          cacheWidth: 192,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => ColoredBox(
            color: FarmColors.peach,
            child: Center(
              child: Icon(
                Icons.home_work_outlined,
                size: size * .55,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Decorative art only. Place real text/actions outside this widget. Contain
/// preserves every animal at all widths; the source ratio is 3:1.
class FarmWelcomeBanner extends StatelessWidget {
  const FarmWelcomeBanner({super.key, this.showCow = true});
  final bool showCow;

  static const asset = 'assets/illustrations/farm-banner.png';

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            cacheWidth: 1200,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: FarmColors.mint,
              child: Center(
                child: Icon(Icons.landscape_outlined, color: forest),
              ),
            ),
          ),
          if (showCow)
            Align(
              alignment: Alignment.bottomRight,
              child: LayoutBuilder(
                builder: (_, constraints) => FarmSpeciesIllustration(
                  speciesName: 'Bò',
                  size: constraints.maxHeight * .96,
                  decorative: true,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class FarmAuthHero extends StatelessWidget {
  const FarmAuthHero({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 1.2,
      child: LayoutBuilder(
        builder: (_, c) => Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Positioned.fill(
              child: Image(
                image: AssetImage(FarmWelcomeBanner.asset),
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: FarmSpeciesIllustration(
                speciesName: 'Heo',
                size: c.maxWidth * .35,
                decorative: true,
              ),
            ),
            Positioned(
              bottom: 0,
              child: FarmSpeciesIllustration(
                speciesName: 'Bò',
                size: c.maxWidth * .56,
                decorative: true,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FarmSpeciesIllustration(
                speciesName: 'Dê',
                size: c.maxWidth * .34,
                decorative: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
