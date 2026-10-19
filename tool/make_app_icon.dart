// Génère les images sources de l'icône de l'application à partir du logo :
//   dart run tool/make_app_icon.dart
// puis :
//   dart run flutter_launcher_icons
//
// - assets/icon/app_icon.png : logo dans un cadre doré à coins arrondis
//   (icône classique, web, Windows, iOS) ;
// - assets/icon/app_icon_foreground.png : logo seul, réduit dans la zone
//   sûre d'Android ; le fond doré de l'icône adaptative forme le cadre,
//   quelle que soit la forme imposée par le téléphone (rond, carré…).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _size = 1024;

// Dégradé doré (clair en haut à gauche, plus soutenu en bas à droite).
final _goldLight = img.ColorRgb8(0xF6, 0xD8, 0x6B);
final _goldDark = img.ColorRgb8(0xB8, 0x86, 0x0B);

void main() {
  final source = img.decodePng(File('assets/images/logo.png').readAsBytesSync());
  if (source == null) {
    stderr.writeln('Logo introuvable : assets/images/logo.png');
    exit(1);
  }
  Directory('assets/icon').createSync(recursive: true);

  // 1) Icône classique : cadre doré + logo.
  final framed = img.Image(width: _size, height: _size, numChannels: 4);
  _fillRoundedGold(framed, radius: 200);
  const inset = 64; // épaisseur du cadre doré
  final logo = img.copyResize(
    source,
    width: _size - 2 * inset,
    height: _size - 2 * inset,
    interpolation: img.Interpolation.cubic,
  );
  // Coins du logo arrondis dans la continuité du cadre (épaisseur dorée
  // régulière, y compris dans les angles).
  img.compositeImage(
    framed,
    _roundCorners(logo, radius: 200 - inset),
    dstX: inset,
    dstY: inset,
  );
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(framed));

  // 2) Premier plan de l'icône adaptative Android (zone sûre ≈ 66 %).
  final foreground = img.Image(width: _size, height: _size, numChannels: 4);
  const safe = 700; // carré inscrit dans le masque rond, après la marge Android
  final small = img.copyResize(
    source,
    width: safe,
    height: safe,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    foreground,
    _roundCorners(small, radius: 110),
    dstX: (_size - safe) ~/ 2,
    dstY: (_size - safe) ~/ 2,
  );
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('Icônes générées dans assets/icon/');
}

/// Remplit un carré à coins arrondis d'un dégradé doré (transparent hors
/// des coins, bord légèrement lissé).
void _fillRoundedGold(img.Image canvas, {required int radius}) {
  final w = canvas.width;
  final h = canvas.height;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Distance au coin arrondi le plus proche (0 à l'intérieur).
      final cx = x < radius ? radius : (x >= w - radius ? w - radius - 1 : x);
      final cy = y < radius ? radius : (y >= h - radius ? h - radius - 1 : y);
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      final alpha = (radius + 0.5 - d).clamp(0.0, 1.0);
      if (alpha <= 0) {
        continue;
      }
      final t = ((x + y) / (w + h - 2)).clamp(0.0, 1.0);
      final r = _goldLight.r + (_goldDark.r - _goldLight.r) * t;
      final g = _goldLight.g + (_goldDark.g - _goldLight.g) * t;
      final b = _goldLight.b + (_goldDark.b - _goldLight.b) * t;
      canvas.setPixelRgba(x, y, r.round(), g.round(), b.round(), (alpha * 255).round());
    }
  }
}

/// Copie de [source] avec des coins arrondis (transparents, bord lissé).
img.Image _roundCorners(img.Image source, {required int radius}) {
  final out = source.convert(numChannels: 4);
  final w = out.width;
  final h = out.height;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inCornerX = x < radius || x >= w - radius;
      final inCornerY = y < radius || y >= h - radius;
      if (!inCornerX || !inCornerY) {
        continue;
      }
      final cx = x < radius ? radius : w - radius - 1;
      final cy = y < radius ? radius : h - radius - 1;
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      final alpha = (radius + 0.5 - d).clamp(0.0, 1.0);
      final p = out.getPixel(x, y);
      out.setPixelRgba(x, y, p.r, p.g, p.b, (p.a * alpha).round());
    }
  }
  return out;
}
