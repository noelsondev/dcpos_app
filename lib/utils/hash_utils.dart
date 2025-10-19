// /lib/utils/hash_utils.dart

/// Genera un hash int de 64 bits (como el que Isar necesita) a partir de una cadena (String).
/// Fuente: https://isar.dev/es/recipes/external_ids.html
int fastHash(String string) {
  var hash = 0xcbf29ce484222325; // Número primo de 64 bits FNV

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
