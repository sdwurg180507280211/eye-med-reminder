/// Adapter boundary for the future Excel-backed drug database.
/// Never infer dosing from a catalog result.
abstract interface class DrugCatalog {
  Future<DrugInfo?> lookup(String exactName);
}

class DrugInfo {
  final String name, description;
  const DrugInfo(this.name, this.description);
}

class UnconnectedDrugCatalog implements DrugCatalog {
  @override
  Future<DrugInfo?> lookup(String exactName) async => null;
}
