/// Parses pipe-separated recipe steps from CSV `instructions` fields.
List<String> splitRecipeInstructions(dynamic raw) {
  if (raw == null) return [];
  final s = raw.toString().trim();
  if (s.isEmpty) return [];
  return s
      .split(RegExp(r'\s*\|\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
