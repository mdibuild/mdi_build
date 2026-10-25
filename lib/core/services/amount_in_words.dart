/// Montants en toutes lettres (français, orthographe traditionnelle) pour
/// la mention « Arrêtée la présente facture à la somme de … ».
library;

const _units = [
  'zéro',
  'un',
  'deux',
  'trois',
  'quatre',
  'cinq',
  'six',
  'sept',
  'huit',
  'neuf',
  'dix',
  'onze',
  'douze',
  'treize',
  'quatorze',
  'quinze',
  'seize',
];
const _tens = [
  '',
  '',
  'vingt',
  'trente',
  'quarante',
  'cinquante',
  'soixante',
];

/// 0 à 99. [finalPlural] : « quatre-vingts » quand rien ne suit.
String _below100(int n, {required bool finalPlural}) {
  if (n <= 16) {
    return _units[n];
  }
  if (n < 20) {
    return 'dix-${_units[n - 10]}';
  }
  if (n < 70) {
    final t = n ~/ 10;
    final u = n % 10;
    if (u == 0) {
      return _tens[t];
    }
    return u == 1 ? '${_tens[t]} et un' : '${_tens[t]}-${_units[u]}';
  }
  if (n < 80) {
    final r = n - 60; // 10..19
    return r == 11
        ? 'soixante et onze'
        : 'soixante-${_below100(r, finalPlural: false)}';
  }
  final r = n - 80; // 0..19
  if (r == 0) {
    return finalPlural ? 'quatre-vingts' : 'quatre-vingt';
  }
  return 'quatre-vingt-${_below100(r, finalPlural: false)}';
}

/// 0 à 999 (0 renvoie une chaîne vide).
String _below1000(int n, {required bool finalPlural}) {
  if (n == 0) {
    return '';
  }
  final h = n ~/ 100;
  final rest = n % 100;
  final parts = <String>[];
  if (h > 0) {
    if (h == 1) {
      parts.add('cent');
    } else {
      parts.add('${_units[h]} ${rest == 0 && finalPlural ? 'cents' : 'cent'}');
    }
  }
  if (rest > 0) {
    parts.add(_below100(rest, finalPlural: finalPlural));
  }
  return parts.join(' ');
}

/// Nombre entier positif en lettres.
String integerInWords(int n) {
  if (n < 0) {
    return 'moins ${integerInWords(-n)}';
  }
  if (n == 0) {
    return 'zéro';
  }
  final parts = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n ~/ 1000000) % 1000;
  final milliers = (n ~/ 1000) % 1000;
  final reste = n % 1000;

  if (milliards > 0) {
    parts.add('${_below1000(milliards, finalPlural: true)} '
        '${milliards > 1 ? 'milliards' : 'milliard'}');
  }
  if (millions > 0) {
    parts.add('${_below1000(millions, finalPlural: true)} '
        '${millions > 1 ? 'millions' : 'million'}');
  }
  if (milliers > 0) {
    // « mille » est invariable et ne prend pas « un » devant.
    parts.add(milliers == 1
        ? 'mille'
        : '${_below1000(milliers, finalPlural: false)} mille');
  }
  if (reste > 0) {
    parts.add(_below1000(reste, finalPlural: true));
  }
  return parts.join(' ');
}

/// Montant en dinars algériens et centimes, ex. :
/// 1 250 080,50 → « un million deux cent cinquante mille quatre-vingts
/// dinars algériens et cinquante centimes ».
String amountInWordsDzd(double amount) {
  final cents = (amount.abs() * 100).round();
  final dinars = cents ~/ 100;
  final centimes = cents % 100;
  final buffer = StringBuffer(integerInWords(dinars))
    // « un million de dinars » (million et milliard sont des noms).
    ..write(dinars >= 1000000 && dinars % 1000000 == 0 ? ' de' : '')
    ..write(dinars > 1 ? ' dinars algériens' : ' dinar algérien');
  if (centimes > 0) {
    buffer
      ..write(' et ')
      ..write(integerInWords(centimes))
      ..write(centimes > 1 ? ' centimes' : ' centime');
  }
  final text = buffer.toString();
  return text[0].toUpperCase() + text.substring(1);
}
