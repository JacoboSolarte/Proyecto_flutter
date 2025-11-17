class ImageAnalysis {
  final String id;
  final String? userId;
  final String? imageName;
  final String? mimeType;
  final String? imageUrl;
  final String? model;
  final String? notes;
  final String? rawText;
  final DateTime? createdAt;

  ImageAnalysis({
    required this.id,
    this.userId,
    this.imageName,
    this.mimeType,
    this.imageUrl,
    this.model,
    this.notes,
    this.rawText,
    this.createdAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory ImageAnalysis.fromMap(Map<String, dynamic> map) {
    return ImageAnalysis(
      id: map['id']?.toString() ?? '',
      userId: map['created_by']?.toString(),
      imageName: map['image_name']?.toString(),
      mimeType: map['mime_type']?.toString(),
      imageUrl: map['image_url']?.toString(),
      model: map['model']?.toString(),
      notes: map['notes']?.toString(),
      rawText: map['raw_text']?.toString(),
      createdAt: _parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'created_by': userId,
      if (imageName != null) 'image_name': imageName,
      if (mimeType != null) 'mime_type': mimeType,
      if (imageUrl != null) 'image_url': imageUrl,
      if (model != null) 'model': model,
      if (notes != null) 'notes': notes,
      if (rawText != null) 'raw_text': rawText,
    };
  }
}