import 'package:cloud_firestore/cloud_firestore.dart';

enum ResourceCategory { brandAssets, videoIdeas, contentTemplates }

extension ResourceCategoryExtension on ResourceCategory {
  String get label {
    switch (this) {
      case ResourceCategory.brandAssets:
        return 'Brand Assets';
      case ResourceCategory.videoIdeas:
        return 'Video Ideas';
      case ResourceCategory.contentTemplates:
        return 'Content Templates';
    }
  }

  String get key {
    switch (this) {
      case ResourceCategory.brandAssets:
        return 'brand-assets';
      case ResourceCategory.videoIdeas:
        return 'video-ideas';
      case ResourceCategory.contentTemplates:
        return 'content-templates';
    }
  }
}

class CreatorResource {
  final String id;
  final String category;
  final String title;
  final String description;
  final String? downloadUrl;
  final String? externalUrl;
  final List<String> tags;
  final int order;
  final DateTime createdAt;
  final String? emoji;

  const CreatorResource({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.downloadUrl,
    this.externalUrl,
    this.tags = const [],
    this.order = 0,
    required this.createdAt,
    this.emoji,
  });

  factory CreatorResource.fromMap(Map<String, dynamic> map, String id) {
    return CreatorResource(
      id: id,
      category: map['category'] ?? 'brand-assets',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      downloadUrl: map['downloadUrl'],
      externalUrl: map['externalUrl'],
      tags: List<String>.from(map['tags'] ?? []),
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emoji: map['emoji'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'title': title,
      'description': description,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (externalUrl != null) 'externalUrl': externalUrl,
      'tags': tags,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      if (emoji != null) 'emoji': emoji,
    };
  }
}
