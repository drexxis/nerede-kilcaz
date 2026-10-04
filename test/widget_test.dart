import 'package:flutter_test/flutter_test.dart';

import 'package:neredekilacagim/utils.dart';

void main() {
  test('normalizeText Turkce karakterleri ascii\'ye indirir', () {
    expect(normalizeText('İzmir'), 'izmir');
    expect(normalizeText('ÇEŞME'), 'cesme');
    expect(normalizeText('Ğüneş'), 'gunes');
  });

  test('capTr basit buyuk harf yapar', () {
    expect(capTr('istanbul'), 'İstanbul');
  });
}