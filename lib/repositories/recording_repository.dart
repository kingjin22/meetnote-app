import '../models/recording.dart';

abstract class RecordingRepository {
  Future<List<Recording>> list();
  Future<void> add(Recording recording);
  Future<void> deleteById(String id);
}
