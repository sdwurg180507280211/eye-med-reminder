// Run from the repository root:
// flutter test --no-pub tool/generate_app_icons.dart
// Uses the existing vector painter, with no downloaded art or image dependency.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_med_reminder/design_system.dart';
import 'package:eye_med_reminder/dog_avatar.dart';

const _iconDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate opaque dog app icons at all declared platform sizes', () async {
    final catalog =
        jsonDecode(File('$_iconDirectory/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    final targets = <String, int>{};
    for (final entry in catalog['images'] as List) {
      final image = entry as Map<String, dynamic>;
      final filename = image['filename'] as String?;
      if (filename == null) continue;
      final dimensions = (image['size'] as String)
          .split('x')
          .map(double.parse)
          .toList();
      final scale = double.parse(
        (image['scale'] as String).replaceAll('x', ''),
      );
      expect(dimensions[0], dimensions[1], reason: 'App icons must be square');
      final pixels = (dimensions.first * scale).round();
      final path = '$_iconDirectory/$filename';
      if (targets.containsKey(path)) expect(targets[path], pixels);
      targets[path] = pixels;
    }
    for (final density in <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      targets['android/app/src/main/res/mipmap-${density.key}/ic_launcher.png'] =
          density.value;
    }

    final rendered = <int, Uint8List>{};
    for (final target in targets.entries) {
      final pixels = target.value;
      final png = rendered[pixels] ??= await _drawIcon(pixels);
      // Verify dimensions, bit depth and RGB-only IHDR before saving.
      final header = ByteData.sublistView(png);
      expect(header.getUint32(16), pixels);
      expect(header.getUint32(20), pixels);
      expect(png[24], 8);
      expect(
        png[25],
        2,
        reason: 'Color type 2 is RGB without an alpha channel',
      );
      File(target.key).writeAsBytesSync(png, flush: true);
    }
    // ignore: avoid_print
    print(
      'Generated ${targets.length} opaque RGB app icons; iOS dimensions follow Contents.json.',
    );
  });
}

Future<Uint8List> _drawIcon(int pixels) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(eyeMedBackground, ui.BlendMode.src);
  final dogSize = pixels * 0.82;
  final inset = (pixels - dogSize) / 2;
  canvas.save();
  canvas.translate(inset, inset);
  DogPainter(0).paint(canvas, ui.Size.square(dogSize));
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final rgba = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    // Strip alpha only after checking every rasterized pixel is opaque.
    for (var alpha = 3; alpha < rgba.length; alpha += 4) {
      if (rgba[alpha] != 255) {
        throw StateError('Unexpected transparency in $pixels px icon');
      }
    }
    return _encodeRgbPng(pixels, rgba);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Uint8List _encodeRgbPng(int pixels, Uint8List rgba) {
  final rows = Uint8List(pixels * (1 + pixels * 3));
  var read = 0;
  var write = 0;
  for (var row = 0; row < pixels; row++) {
    rows[write++] = 0; // PNG filter: none, for a lossless RGB scanline.
    for (var column = 0; column < pixels; column++) {
      rows[write++] = rgba[read++];
      rows[write++] = rgba[read++];
      rows[write++] = rgba[read++];
      read++;
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, pixels)
    ..setUint32(4, pixels)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final png = BytesBuilder(copy: false)
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
    ..add(
      _chunk('IDAT', Uint8List.fromList(ZLibEncoder(level: 9).convert(rows))),
    )
    ..add(_chunk('IEND', Uint8List(0)));
  return png.takeBytes();
}

Uint8List _chunk(String name, Uint8List data) {
  final type = ascii.encode(name);
  final bytes = Uint8List(12 + data.length);
  final header = ByteData.sublistView(bytes)..setUint32(0, data.length);
  bytes.setRange(4, 8, type);
  bytes.setRange(8, 8 + data.length, data);
  var crc = 0xffffffff;
  for (var index = 4; index < bytes.length - 4; index++) {
    crc = _crcTable[(crc ^ bytes[index]) & 0xff] ^ (crc >> 8);
  }
  header.setUint32(bytes.length - 4, (crc ^ 0xffffffff) & 0xffffffff);
  return bytes;
}

final _crcTable = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = value & 1 == 1 ? 0xedb88320 ^ (value >> 1) : value >> 1;
  }
  return value;
});
