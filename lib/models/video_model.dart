class Video {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final String publishedAt;
  final String description;
  final String category;
  final String videoUrl;
  final String? duration;

  Video({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    required this.description,
    required this.category,
    required this.videoUrl,
    this.duration,
  });

  // Create Video from JSON
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      channelTitle: json['channelTitle'] as String,
      publishedAt: json['publishedAt'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      videoUrl: json['videoUrl'] as String,
      duration: json['duration'] as String?,
    );
  }

  // Convert Video to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'publishedAt': publishedAt,
      'description': description,
      'category': category,
      'videoUrl': videoUrl,
      'duration': duration,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Video && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
