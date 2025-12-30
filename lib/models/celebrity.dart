class Celebrity {
  final String id;
  final String name;
  final String imagePath; // 로컬 이미지 경로 (예: 'assets/images/iu.jpg')

  Celebrity({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  factory Celebrity.fromJson(Map<String, dynamic> json) {
    return Celebrity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imagePath: json['imagePath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
    };
  }
} 