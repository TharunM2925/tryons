/// Data model for a saved try-on result.
class TryOnResultModel {
  final int id;
  final int tattooId;
  final String resultImageUrl;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final double opacity;
  final String? notes;
  final DateTime createdAt;

  TryOnResultModel({
    required this.id,
    required this.tattooId,
    required this.resultImageUrl,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.rotation,
    required this.opacity,
    this.notes,
    required this.createdAt,
  });

  factory TryOnResultModel.fromJson(Map<String, dynamic> json) {
    return TryOnResultModel(
      id: json['id'],
      tattooId: json['tattoo_id'],
      resultImageUrl: json['result_image_url'],
      positionX: (json['position_x'] as num).toDouble(),
      positionY: (json['position_y'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
