import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 官方眼科药房药品资料库接口
abstract interface class DrugCatalog {
  Future<DrugInfo?> lookup(String name);
  Future<List<DrugInfo>> getAll();
}

/// 药品详细实体
class DrugInfo {
  final int id;
  final String name;
  final String genericName;
  final String brandName;
  final String spec;
  final String category;
  final String indication;
  final String dosage;
  final String manufacturer;
  final String imageUrl;
  final String manualUrl;

  const DrugInfo({
    required this.id,
    required this.name,
    required this.genericName,
    required this.brandName,
    required this.spec,
    required this.category,
    required this.indication,
    required this.dosage,
    required this.manufacturer,
    required this.imageUrl,
    required this.manualUrl,
  });

  String get description => '''
【用途分类】$category
【药品规格】$spec
【适应症】
$indication

【推荐用法用量】
$dosage

【生产厂家】$manufacturer
${manualUrl.isNotEmpty ? '\n【参考说明书资料】$manualUrl' : ''}''';

  factory DrugInfo.fromJson(Map<String, dynamic> json) => DrugInfo(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    genericName: json['generic_name'] as String? ?? '',
    brandName: json['brand_name'] as String? ?? '',
    spec: json['spec'] as String? ?? '',
    category: json['category'] as String? ?? '',
    indication: json['indication'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    manufacturer: json['manufacturer'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
    manualUrl: json['manual_url'] as String? ?? '',
  );
}

/// 基于 Excel 导出的本地眼科药品数据库 (assets/drug_catalog.json)
class LocalJsonDrugCatalog implements DrugCatalog {
  static List<DrugInfo>? _cache;

  Future<List<DrugInfo>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/drug_catalog.json');
      final list = json.decode(str) as List;
      _cache = list.map((e) => DrugInfo.fromJson(e as Map<String, dynamic>)).toList();
      return _cache!;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<DrugInfo>> getAll() async => _load();

  @override
  Future<DrugInfo?> lookup(String name) async {
    final list = await _load();
    if (list.isEmpty) return null;

    final clean = name.replaceAll(RegExp(r'[（\(][^）\)]+[）\)]'), '').trim();
    for (final item in list) {
      if (item.name == name) return item;
      if (item.genericName == clean || item.genericName == name) return item;
      if (item.brandName.isNotEmpty && (name.contains(item.brandName) || item.name.contains(name))) return item;
      if (name.contains(item.genericName) || item.genericName.contains(name)) return item;
    }
    return null;
  }
}

/// 兼容旧命名的适配器，直接接入本地 Excel 资料库
class UnconnectedDrugCatalog implements DrugCatalog {
  final _delegate = LocalJsonDrugCatalog();

  @override
  Future<DrugInfo?> lookup(String exactName) async => _delegate.lookup(exactName);

  @override
  Future<List<DrugInfo>> getAll() async => _delegate.getAll();
}
