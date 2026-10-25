/// Lecture d'un nombre saisi à la française : « 2,5 », « 1 250,75 »,
/// « 1.250,75 » ou « 2.5 ». Renvoie null si la saisie n'est pas un nombre
/// (au lieu de la transformer silencieusement en 0).
double? parseDecimal(String input) {
  var text = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
  if (text.isEmpty) {
    return null;
  }
  final hasComma = text.contains(',');
  final hasDot = text.contains('.');
  if (hasComma && hasDot) {
    // Le dernier séparateur est la virgule décimale ; l'autre groupe les
    // milliers.
    if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (hasComma) {
    text = text.replaceAll(',', '.');
  }
  return double.tryParse(text);
}

/// Nombre affiché sans décimales inutiles : 2 → « 2 », 2.5 → « 2,5 ».
String formatDecimal(double value, {int maxDecimals = 3}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  var text = value.toStringAsFixed(maxDecimals);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return text.replaceAll('.', ',');
}
