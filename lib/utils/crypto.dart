import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

const String _key =
    'MAGINCIAN71KEYMONDONGOSUPERPEDOS'; // Clave de 32 caracteres (256 bits)

/// Utilidad para operaciones de cifrado/hashing
class CryptoUtils {
  // Constructor privado para evitar instanciación
  CryptoUtils._();

  /// Devuelve el hash SHA-256 de la contraseña
  static String makeHash(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Cifra un texto con AES-256-CBC y devuelve Base64
  static Map<String, String> encryptString(String plain) {
    final key = Key.fromUtf8(_key);
    final iv = IV.fromSecureRandom(16); // Mejor usar IV aleatorio seguro
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);

    return {'cipherText': encrypted.base64, 'iv': iv.base64};
  }

  static String decryptString(String cipherText, String ivBase64) {
    final key = Key.fromUtf8(_key);
    final iv = IV.fromBase64(ivBase64); // Asegurar base64 correcto
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt64(cipherText, iv: iv);
  }
}
