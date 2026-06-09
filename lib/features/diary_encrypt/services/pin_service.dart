import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinService {
  PinService._();

  static String hashPin(String pin, {String? salt}) {
    final actualSalt = salt ?? _generateSalt();
    final bytes = utf8.encode(actualSalt + pin);
    final digest = sha256.convert(bytes);
    return '$actualSalt:${digest.toString()}';
  }

  static bool verifyPin(String input, String storedHash) {
    if (storedHash.isEmpty) return false;

    // Support new salted format: salt:hash
    final parts = storedHash.split(':');
    String computedHash;
    if (parts.length == 2) {
      computedHash = hashPin(input, salt: parts[0]);
    } else {
      // Legacy format: plain SHA-256 hash (backward compatibility)
      final bytes = utf8.encode(input);
      computedHash = sha256.convert(bytes).toString();
    }

    // Constant-time comparison to prevent timing attacks
    if (computedHash.length != storedHash.length) return false;
    int result = 0;
    for (int i = 0; i < computedHash.length; i++) {
      result |= computedHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  static bool isValidPin(String pin) {
    return pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }
}
