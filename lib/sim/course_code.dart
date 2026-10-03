/// 6-character course codes (Crockford base32, 30 bits) ⇄ generator seeds.
/// The Daily is just today's code. No server: the code IS the course.
library;

const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// 30 bits total: top 3 = generator version (1..7), low 27 = seed.
/// An issued code must reproduce the same course forever, so the version
/// selects a frozen chunk pool + generator rules (see generator.dart).
const int kCodeBits = 30;
const int kVersionBits = 3;
const int kSeedBits = kCodeBits - kVersionBits; // 27
const int kSeedMask = (1 << kSeedBits) - 1;
const int kCodeMask = (1 << kCodeBits) - 1;

int packCode(int version, int seed) => ((version & 7) << kSeedBits) | (seed & kSeedMask);
int codeVersion(int packed) => (packed >> kSeedBits) & 7;
int codeSeed(int packed) => packed & kSeedMask;

/// [packed] is a 30-bit value from [packCode].
String seedToCode(int packed) {
  var v = packed & kCodeMask;
  final out = List<String>.filled(6, '0');
  for (var i = 5; i >= 0; i--) {
    out[i] = _alphabet[v & 31];
    v >>= 5;
  }
  return out.join();
}

/// Returns null if [code] is not a valid 6-char code. Tolerates lowercase and
/// the usual confusions (O→0, I/L→1, U→V).
int? codeToSeed(String code) {
  var s = code.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
  s = s.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1').replaceAll('U', 'V');
  if (s.length != 6) return null;
  var v = 0;
  for (final ch in s.split('')) {
    final i = _alphabet.indexOf(ch);
    if (i < 0) return null;
    v = (v << 5) | i;
  }
  return v;
}

/// Pretty form for humans: "7KQ-2MX".
String prettyCode(String code) => '${code.substring(0, 3)}-${code.substring(3)}';
