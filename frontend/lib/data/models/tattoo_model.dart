/// Data model for a tattoo design.
class TattooModel {
  final int id;
  final String name;
  final String imageUrl;
  final int? fileSize;
  final String? contentType;
  final DateTime createdAt;

  TattooModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.fileSize,
    this.contentType,
    required this.createdAt,
  });

  factory TattooModel.fromJson(Map<String, dynamic> json) {
    // Handle both upload response and full tattoo response formats
    return TattooModel(
      id: json['tattoo_id'] ?? json['id'],
      name: json['name'],
      imageUrl: json['image_url'],
      fileSize: json['file_size'],
      contentType: json['content_type'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'file_size': fileSize,
    'content_type': contentType,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'TattooModel(id: $id, name: $name)';
}
