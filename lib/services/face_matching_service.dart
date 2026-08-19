import 'dart:math';

class FaceMatchingService {
  FaceMatchingService._();

  static double cosineSimilarity(
    List<double> a,
    List<double> b,
  ) {
    if (a.length != b.length) {
      throw Exception('Embedding lengths do not match.');
    }

    double dotProduct = 0;
    double magnitudeA = 0;
    double magnitudeB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    if (magnitudeA == 0 || magnitudeB == 0) {
      return 0;
    }

    return dotProduct /
        (sqrt(magnitudeA) * sqrt(magnitudeB));
  }

  static bool isMatch(
    List<double> registeredEmbedding,
    List<double> capturedEmbedding, {
    double threshold = 0.70,
  }) {
    final similarity = cosineSimilarity(
      registeredEmbedding,
      capturedEmbedding,
    );

    return similarity >= threshold;
  }
}