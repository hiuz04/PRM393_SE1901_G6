import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  const PasswordHasher._();

  static String hash(String password) {
    final normalized = password.trim();
    return sha256.convert(utf8.encode('cine-x:v1:$normalized')).toString();
  }

  static bool verify(String password, String passwordHash) {
    return hash(password) == passwordHash;
  }
}
