/// Model data precision and quantization format.
enum TensorQuantization {
  int8('int8', 'Signed 8-bit Integer (Optimized for MCU)'),
  uint8('uint8', 'Unsigned 8-bit Integer'),
  float32('float32', '32-bit Floating Point (Requires FPU)');

  const TensorQuantization(this.identifier, this.description);

  final String identifier;
  final String description;
}

/// Metadata and memory requirements for an on-device Edge AI / TinyML model.
final class TFLiteModelDescriptor {
  const TFLiteModelDescriptor({
    required this.name,
    required this.assetPath,
    required this.inputShape,
    required this.outputShape,
    this.quantization = TensorQuantization.int8,
    this.tensorArenaSizeKb = 64,
    this.labels = const <String>[],
  });

  final String name;
  final String assetPath;
  final List<int> inputShape;
  final List<int> outputShape;
  final TensorQuantization quantization;
  final int tensorArenaSizeKb;
  final List<String> labels;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'assetPath': assetPath,
        'inputShape': inputShape,
        'outputShape': outputShape,
        'quantization': quantization.identifier,
        'tensorArenaSizeKb': tensorArenaSizeKb,
        'labels': labels,
      };
}

/// A classified label output or bounding box confidence score.
final class ClassificationResult {
  const ClassificationResult({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}
