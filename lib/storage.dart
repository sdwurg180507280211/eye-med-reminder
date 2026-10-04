import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class PatientStore {
  final FlutterSecureStorage storage;
  List<Patient> patients = [];
  PatientStore({this.storage = const FlutterSecureStorage()});
  Future<void> load() async {
    final raw = await storage.read(key: 'patients_v1');
    if (raw != null) {
      patients = Patient.decode(raw);
    }
  }

  Future<void> save() => storage.write(
    key: 'patients_v1',
    value: jsonEncode(patients.map((p) => p.toJson()).toList()),
  );
  Future<String> derive(String pin, String salt) async {
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 100000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(pin)),
          nonce: base64Decode(salt),
        );
    return base64Encode(await key.extractBytes());
  }

  Future<Patient?> login(String name, String pin) async {
    for (final p in patients.where((p) => p.name == name)) {
      if (await derive(pin, p.salt) == p.hash) {
        return p;
      }
    }
    return null;
  }

  Future<Patient> create(String name, String pin) async {
    if (await login(name, pin) != null) {
      throw StateError('该档案已存在，请返回登录');
    }
    final salt = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final p = Patient(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      salt: salt,
      hash: await derive(pin, salt),
      plans: [],
    );
    patients.add(p);
    try {
      await save();
    } catch (_) {
      patients.remove(p);
      rethrow;
    }
    return p;
  }
}
