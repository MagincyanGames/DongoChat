import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/sizeable.dart';

class Data<T extends Sizeable> {
  final T data;
  int times;

  Data({required this.data, this.times = 50});
}

class CachedData<T extends Sizeable> implements Sizeable {
  final Map<ObjectId, Data<T>> _cache = {};

  bool containsCached(ObjectId id) => _cache.containsKey(id);

  T? getCached(ObjectId id) {
    print("Caching:$id");
    if (containsCached(id) && _cache[id]!.times > 0) {
      print("Caching 1");
      _cache[id]!.times--;
      return _cache[id]!.data;
    }
    print("Caching none");

    return null;
  }

  void storeCached(ObjectId id, T? data) {
    if (data == null) return;
    _cache[id] = Data(data: data);
  }

  @override
  
  int get size {
    int totalSize = 0;

    // Sumar el tamaño de cada objeto almacenado en la caché
    _cache.forEach((key, data) {
      totalSize +=
          data
              .data
              .size; // Accede al `size` del tipo `T` (cada objeto en caché)
    });

    return totalSize;
  }
}
