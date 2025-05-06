import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

/// Utilidad para operaciones de cifrado/hashing
class CryptoUtilities {
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _keyPair;
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? get keyPair {
    if (_keyPair == null) {
      // Generar un nuevo par de claves si no existe
      _keyPair = generateRSAKeyPair();
    }
    return _keyPair;
  }

  // Constructor privado para evitar instanciación
  CryptoUtilities._();

  /// Devuelve el hash SHA-256 de la contraseña
  static String makeHash(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Encrypter getEncrypter({
    RSAPublicKey? publicKey,
    RSAPrivateKey? privateKey,
  }) {
    return Encrypter(
      RSA(
        publicKey: publicKey,
        privateKey: privateKey,
        encoding: RSAEncoding.OAEP,
        digest: RSADigest.SHA256,
      ),
    );
  }

  /// Cifra un texto con AES-256-CBC y devuelve Base64
  static String encryptString(String plain, {RSAPublicKey? publicKey}) {
    if (publicKey == null) {
      publicKey = keyPair!.publicKey;
    }
    final encrypter = getEncrypter(publicKey: publicKey);
    return encrypter.encrypt(plain).base64;
  }

  static String decryptString(String cipherText) {
    final encrypter = getEncrypter(
      publicKey: keyPair!.publicKey,
      privateKey: keyPair!.privateKey,
    );
    return encrypter.decrypt64(cipherText);
  }
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair({
  int bitLength = 2048,
}) {
  // Generador de números aleatorios seguro
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  // Parámetros para la generación de claves RSA
  final keyGen =
      RSAKeyGenerator()..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
          secureRandom,
        ),
      );

  // Generar el par de claves
  final pair = keyGen.generateKeyPair();
  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
    pair.publicKey as RSAPublicKey,
    pair.privateKey as RSAPrivateKey,
  );
}
