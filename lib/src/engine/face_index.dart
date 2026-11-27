/// Face grouping is not in this build.
///
/// A later change can cluster photos with MediaPipe or OpenCV YuNet detection
/// and AdaFace embeddings (MIT). InsightFace official buffalo and antelope
/// packs are not acceptable here: their pretrained weights are not licensed
/// for this app.
abstract interface class FaceIndex {
  Future<void> open();

  Future<void> addPhoto(String photoId);

  Future<List<List<String>>> clusters();

  Future<void> close();
}
