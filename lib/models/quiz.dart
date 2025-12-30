import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'celebrity.dart';

class Quiz {
  final String id;
  final String title;
  final List<Celebrity> celebrities;
  final DateTime createdAt;

  Quiz({
    String? id,
    required this.title,
    required this.celebrities,
    DateTime? createdAt,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    createdAt = createdAt ?? DateTime.now();

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'celebrities': celebrities.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // JSON에서 객체 생성
  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String,
      celebrities: (json['celebrities'] as List)
          .map((c) => Celebrity.fromJson(c as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Quiz{title: $title, celebrities: ${celebrities.length}, createdAt: $createdAt}';
  }
} 