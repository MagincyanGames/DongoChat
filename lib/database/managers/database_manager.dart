import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/managers/cached_data.dart';
import 'package:dongo_chat/models/sizeable.dart';

abstract class DatabaseManager<T extends Sizeable> implements Sizeable{
  final DatabaseService _databaseService;
  final _cache = CachedData();

  int _maxRetryAttempts = 3;
  Duration _retryDelay = const Duration(seconds: 1);

  DatabaseManager(this._databaseService);

  String get collectionName;
  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T item);

  Future<DbCollection> getCollectionWithRetry() async {
    int attempts = 0;
    late DbCollection collection;

    while (attempts < _maxRetryAttempts) {
      try {
        if (!_databaseService.isConnected) {
          await _databaseService.connectToDatabase();
        }

        collection = _databaseService.db.collection(collectionName);

        // Hacer un ping simple para verificar que la conexión está activa
        await collection.find().take(1).toList();
        return collection;
      } catch (e) {
        attempts++;
        print("Intento $attempts fallido: $e");

        if (attempts >= _maxRetryAttempts) {
          throw Exception(
            'No se pudo establecer conexión con la base de datos después de $attempts intentos',
          );
        }

        // Esperar antes de reintentar
        await Future.delayed(_retryDelay);

        // Forzar reconexión para el próximo intento
        await _databaseService.closeConnection();
      }
    }

    throw Exception(
      'No se pudo obtener la colección después de $attempts intentos',
    );
  }

  Future<List<T>> find([Map<String, dynamic>? filter]) async {
    final collection = await getCollectionWithRetry();
    final documents = await collection.find(filter ?? {}).toList();
    return documents.map((doc) => fromMap(doc)).toList();
  }

  Future<T?> findById(ObjectId? id) async {
    if (id == null) {
      return null;
    }

    final T? cached = _cache.getCached(id) as T?;
    if (cached != null) {
      return cached;
    }

    final collection = await getCollectionWithRetry();

    final document = await collection.findOne(where.id(id));

    if (document != null) {
    } else {
    }

    T? result = document != null ? fromMap(document) : null;

    if (result != null) {
      _cache.storeCached(id, result);
    }
    return result;
  }

  Future<String> add(T item) async {
    final collection = await getCollectionWithRetry();
    final result = await collection.insertOne(toMap(item));

    if (result.isSuccess) {
      return result.id.toString();
    }
    throw Exception('Error al añadir documento: ${result.writeError?.errmsg}');
  }

  Future<bool> update(ObjectId id, T item) async {
    final collection = await getCollectionWithRetry();
    final modifier = ModifierBuilder();
    final map = toMap(item);

    map.forEach((key, value) {
      modifier.set(key, value);
    });

    final result = await collection.updateOne(where.id(id), modifier);

    return result.isSuccess;
  }

  Future<bool> delete(String id) async {
    final collection = await getCollectionWithRetry();
    final result = await collection.deleteOne(where.id(ObjectId.parse(id)));
    return result.isSuccess;
  }

  // Método para operaciones de agregación CORREGIDO
  Future<List<Map<String, dynamic>>> aggregate(
    List<Map<String, dynamic>> pipeline,
  ) async {
    try {
      final collection = await getCollectionWithRetry();
      final result = await collection.aggregate(pipeline);
      // result is a Map, so extract the firstBatch list:
      final batch = result['cursor']['firstBatch'] as List;
      return batch.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error en aggregate: $e');
      rethrow;
    }
  }

  // Método para contar documentos
  Future<int> count([Map<String, dynamic>? filter]) async {
    final collection = await getCollectionWithRetry();
    return await collection.count(filter ?? {});
  }
  
  @override
  int get size => _cache.size;

}
