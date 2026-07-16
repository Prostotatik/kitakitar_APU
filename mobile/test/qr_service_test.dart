import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitakitar_mobile/services/qr_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late QRService service;

  const centerId = 'center-1';
  const userId = 'user-1';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = QRService(firestore: firestore);
    // batch.update on /centers requires the doc to exist (same as production).
    await firestore.collection('centers').doc(centerId).set({
      'points': 0,
      'totalWeight': 0.0,
      'carbonFootprint': 0.0,
    });
  });

  Future<String> seedQr(Map<String, dynamic> draft,
      {bool used = false, String? center = centerId}) async {
    final ref = await firestore.collection('qr_codes').add({
      if (center != null) 'centerId': center,
      'transactionDraft': draft,
      'used': used,
    });
    return ref.id;
  }

  test('bin doc with stored co2 uses the new formula and writes all docs',
      () async {
    final qrId = await seedQr({
      'materials': [
        {
          'type': 'plastic',
          'weight': 0.5,
          'pricePerKg': 0.0,
          'isFree': true,
          'co2': 0.4,
        }
      ],
      'totalWeight': 0.5,
    });

    final result = await service.scanQRCode(qrId, userId);

    // 0.5×100×1.5 + 0.4×100 = 75 + 40 = 115
    expect(result['pointsUser'], 115);
    expect(result['co2Saved'], closeTo(0.4, 1e-9));
    expect(result['totalWeight'], closeTo(0.5, 1e-9));

    final qr = await firestore.collection('qr_codes').doc(qrId).get();
    expect(qr.data()!['used'], true);
    expect(qr.data()!['usedBy'], userId);

    final txSnap = await firestore.collection('transactions').get();
    expect(txSnap.docs, hasLength(1));
    final tx = txSnap.docs.first.data();
    expect(tx['userId'], userId);
    expect(tx['centerId'], centerId);
    expect(tx['pointsUser'], 115);
    expect(tx['qrCodeId'], qrId);
    // stored co2 passes through into the transaction's materials
    final mats = tx['materials'] as List;
    expect((mats.first as Map)['co2'], closeTo(0.4, 1e-9));

    final user = await firestore.collection('users').doc(userId).get();
    expect(user.data()!['points'], 115);
    expect(user.data()!['totalWeight'], closeTo(0.5, 1e-9));
    expect(user.data()!['carbonFootprint'], closeTo(0.4, 1e-9));
    expect((user.data()!['stats'] as Map)['plastic'], closeTo(0.5, 1e-9));

    final center = await firestore.collection('centers').doc(centerId).get();
    expect(center.data()!['points'], 115);
    expect(center.data()!['carbonFootprint'], closeTo(0.4, 1e-9));
  });

  test('center doc without co2 falls back via the slug map (spec example)',
      () async {
    final qrId = await seedQr({
      'materials': [
        {'type': 'paper', 'weight': 1.0, 'pricePerKg': 0.0, 'isFree': true}
      ],
      'totalWeight': 1.0,
    });

    final result = await service.scanQRCode(qrId, userId);

    // 1×100×1.5 + (1×0.65)×100 = 150 + 65 = 215
    expect(result['pointsUser'], 215);
    expect(result['co2Saved'], closeTo(0.65, 1e-9));

    // no stored co2 → transaction material has no co2 key
    final tx = (await firestore.collection('transactions').get()).docs.first;
    final mats = tx.data()['materials'] as List;
    expect((mats.first as Map).containsKey('co2'), false);
  });

  test('multi-material combined doc: per-item entries, total rounded once',
      () async {
    final qrId = await seedQr({
      'materials': [
        {'type': 'plastic', 'weight': 0.5, 'pricePerKg': 0.0, 'isFree': true, 'co2': 0.4},
        {'type': 'plastic', 'weight': 0.3, 'pricePerKg': 0.0, 'isFree': true, 'co2': 0.2},
        {'type': 'aluminum', 'weight': 0.015, 'pricePerKg': 0.0, 'isFree': true, 'co2': 0.01},
      ],
      'totalWeight': 0.815,
    });

    final result = await service.scanQRCode(qrId, userId);

    // (75+40) + (45+20) + (2.25+1.0) = 183.25 → 183
    expect(result['pointsUser'], 183);
    expect(result['co2Saved'], closeTo(0.61, 1e-9));

    final user = await firestore.collection('users').doc(userId).get();
    final stats = user.data()!['stats'] as Map;
    expect(stats['plastic'], closeTo(0.8, 1e-9));
    expect(stats['aluminum'], closeTo(0.015, 1e-9));
  });

  test('paid (isFree false) material gets ×1.0 base plus CO2 fallback',
      () async {
    final qrId = await seedQr({
      'materials': [
        {'type': 'metal', 'weight': 2.0, 'pricePerKg': 1.2, 'isFree': false}
      ],
      'totalWeight': 2.0,
    });

    final result = await service.scanQRCode(qrId, userId);

    // 2×100×1.0 + (2×0.85)×100 = 200 + 170 = 370
    expect(result['pointsUser'], 370);
    expect(result['co2Saved'], closeTo(1.7, 1e-9));
  });

  test('unknown slug falls back to the 0.5 default multiplier', () async {
    final qrId = await seedQr({
      'materials': [
        {'type': 'mystery', 'weight': 1.0, 'pricePerKg': 0.0, 'isFree': true}
      ],
      'totalWeight': 1.0,
    });

    final result = await service.scanQRCode(qrId, userId);

    // 150 + (1×0.5)×100 = 200
    expect(result['pointsUser'], 200);
    expect(result['co2Saved'], closeTo(0.5, 1e-9));
  });

  test('used QR is rejected and nothing is written', () async {
    final qrId = await seedQr({
      'materials': [
        {'type': 'paper', 'weight': 1.0, 'pricePerKg': 0.0, 'isFree': true}
      ],
      'totalWeight': 1.0,
    }, used: true);

    await expectLater(
      service.scanQRCode(qrId, userId),
      throwsA(predicate((e) => e.toString().contains('already been used'))),
    );
    expect((await firestore.collection('transactions').get()).docs, isEmpty);
    expect((await firestore.collection('users').doc(userId).get()).exists, false);
  });

  test('missing doc, missing centerId, and empty draft are rejected', () async {
    await expectLater(
      service.scanQRCode('does-not-exist', userId),
      throwsA(predicate((e) => e.toString().contains('QR code not found'))),
    );

    final noCenter = await seedQr({
      'materials': [
        {'type': 'paper', 'weight': 1.0, 'pricePerKg': 0.0, 'isFree': true}
      ],
      'totalWeight': 1.0,
    }, center: null);
    await expectLater(
      service.scanQRCode(noCenter, userId),
      throwsA(predicate((e) => e.toString().contains('Invalid QR code'))),
    );

    final emptyDraft = await seedQr({'materials': [], 'totalWeight': 0.0});
    await expectLater(
      service.scanQRCode(emptyDraft, userId),
      throwsA(predicate((e) => e.toString().contains('Invalid QR code data'))),
    );
  });

  test('stats, points and carbonFootprint accumulate across claims', () async {
    final binQr = await seedQr({
      'materials': [
        {'type': 'plastic', 'weight': 0.5, 'pricePerKg': 0.0, 'isFree': true, 'co2': 0.4}
      ],
      'totalWeight': 0.5,
    });
    final centerQr = await seedQr({
      'materials': [
        {'type': 'paper', 'weight': 1.0, 'pricePerKg': 0.0, 'isFree': true}
      ],
      'totalWeight': 1.0,
    });

    await service.scanQRCode(binQr, userId);
    await service.scanQRCode(centerQr, userId);

    final user = await firestore.collection('users').doc(userId).get();
    expect(user.data()!['points'], 115 + 215);
    expect(user.data()!['totalWeight'], closeTo(1.5, 1e-9));
    expect(user.data()!['carbonFootprint'], closeTo(1.05, 1e-9));
    final stats = user.data()!['stats'] as Map;
    expect(stats['plastic'], closeTo(0.5, 1e-9));
    expect(stats['paper'], closeTo(1.0, 1e-9));

    final center = await firestore.collection('centers').doc(centerId).get();
    expect(center.data()!['points'], 330);
  });
}
