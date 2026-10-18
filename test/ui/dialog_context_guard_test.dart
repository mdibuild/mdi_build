import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre l'écran noir constaté à la suppression d'un projet :
/// dans `showDialog`, le navigateur doit être obtenu avec le contexte de la
/// boîte de dialogue, jamais avec celui de la page (sinon, dans la coque de
/// navigation, c'est la page elle-même qui est retirée).
void main() {
  test('aucune boîte de dialogue ne se ferme avec le contexte de la page', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final dialogStart = RegExp(r'\bshowDialog(<[^>]*>)?\(');
    final builder = RegExp(r'builder:\s*\((\w+)\)\s*(=>|\{)');
    final pagePop = RegExp(r'Navigator\.of\(context\)|Navigator\.pop\(context');

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final m in dialogStart.allMatches(source)) {
        // Isole l'appel showDialog(...) par comptage des parenthèses.
        var depth = 0;
        var end = m.end - 1;
        for (var i = m.end - 1; i < source.length; i++) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        final call = source.substring(m.start, end);
        final b = builder.firstMatch(call);
        if (b == null || b.group(1) == 'context') {
          continue;
        }
        if (pagePop.hasMatch(call)) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
