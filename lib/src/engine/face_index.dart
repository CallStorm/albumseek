import '../faces/face_cluster.dart';
import '../faces/face_pipeline.dart';
import '../index/photo_database.dart';

/// Groups photos by face.
///
/// Detection is OpenCV YuNet (MIT). Embeddings are AdaFace IR-18 (MIT, from
/// the official AdaFace project). InsightFace buffalo and antelope packs are
/// not used.
abstract interface class FaceIndex {
  Future<void> open();

  Future<void> addPhoto(String photoId, List<LocatedFace> faces);

  Future<List<List<String>>> clusters();

  Future<void> close();
}

/// Persists YuNet boxes and AdaFace vectors, assigning each new face to a
/// person without recomputing embeddings that are already stored.
class SqliteFaceIndex implements FaceIndex {
  SqliteFaceIndex(this._db);

  final SqlitePhotoIndex _db;
  FaceRoster? _roster;

  @override
  Future<void> open() async {
    _roster = FaceRoster.fromSamples([
      for (final sample in _db.faceSamples())
        FaceSample(personId: sample.personId, embedding: sample.embedding),
    ]);
  }

  bool alreadyIndexed(String photoId) => _db.facesDone(photoId);

  @override
  Future<void> addPhoto(String photoId, List<LocatedFace> faces) async {
    final roster = _roster ?? FaceRoster();
    _roster = roster;
    for (final face in faces) {
      if (face.embedding.length < 8) {
        continue;
      }
      final personId = roster.add(face.embedding);
      _db.insertFace(
        photoId: photoId,
        x: face.x,
        y: face.y,
        width: face.width,
        height: face.height,
        embedding: face.embedding,
        personId: personId,
      );
    }
    _db.markFacesDone(photoId);
  }

  @override
  Future<List<List<String>>> clusters() async {
    return _db.peopleClusters();
  }

  @override
  Future<void> close() async {
    _roster = null;
  }
}
