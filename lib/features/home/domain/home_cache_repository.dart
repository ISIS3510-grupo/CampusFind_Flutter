import 'home_cache_snapshot.dart';

abstract interface class HomeCacheRepository {
  Future<HomeCacheSnapshot?> load(String uid);
  Future<void> save(String uid, HomeCacheSnapshot snapshot);
  Future<void> clear(String uid);
}
