import 'dart:convert';

// 커스텀 퀴즈 문제 모델
class CustomQuizQuestion {
  final String id;
  final String? imagePath; // 이미지 퀴즈용
  final String? audioPath; // 음성 퀴즈용
  final String? questionText; // 텍스트 퀴즈용
  final String answer; // 정답
  final bool isCorrect; // O/X 퀴즈용 (true = O, false = X)
  // 이미지 위치 및 크기 정보
  final double? imageTop;
  final double? imageLeft;
  final double? imageWidth;
  final double? imageHeight;
  // 텍스트 퀴즈용 글씨 크기
  final double? questionFontSize;
  final double? answerFontSize;

  CustomQuizQuestion({
    required this.id,
    this.imagePath,
    this.audioPath,
    this.questionText,
    required this.answer,
    this.isCorrect = true,
    this.imageTop,
    this.imageLeft,
    this.imageWidth,
    this.imageHeight,
    this.questionFontSize,
    this.answerFontSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'questionText': questionText,
      'answer': answer,
      'isCorrect': isCorrect,
      'imageTop': imageTop,
      'imageLeft': imageLeft,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'questionFontSize': questionFontSize,
      'answerFontSize': answerFontSize,
    };
  }

  factory CustomQuizQuestion.fromJson(Map<String, dynamic> json) {
    return CustomQuizQuestion(
      id: json['id'] ?? '',
      imagePath: json['imagePath'],
      audioPath: json['audioPath'],
      questionText: json['questionText'],
      answer: json['answer'] ?? '',
      isCorrect: json['isCorrect'] ?? true,
      imageTop: json['imageTop'] != null ? (json['imageTop'] as num).toDouble() : null,
      imageLeft: json['imageLeft'] != null ? (json['imageLeft'] as num).toDouble() : null,
      imageWidth: json['imageWidth'] != null ? (json['imageWidth'] as num).toDouble() : null,
      imageHeight: json['imageHeight'] != null ? (json['imageHeight'] as num).toDouble() : null,
      questionFontSize: json['questionFontSize'] != null ? (json['questionFontSize'] as num).toDouble() : null,
      answerFontSize: json['answerFontSize'] != null ? (json['answerFontSize'] as num).toDouble() : null,
    );
  }
}

// 커스텀 퀴즈 모델
class CustomQuiz {
  final String id;
  final String quizType; // 'image', 'text', 'voice'
  final String title;
  final String? category; // 이미지/텍스트 퀴즈용 카테고리
  final String? subCategory; // 텍스트 퀴즈의 초성 서브카테고리
  final List<CustomQuizQuestion> questions;
  final DateTime createdAt;

  CustomQuiz({
    required this.id,
    required this.quizType,
    required this.title,
    this.category,
    this.subCategory,
    required this.questions,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quizType': quizType,
      'title': title,
      'category': category,
      'subCategory': subCategory,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomQuiz.fromJson(Map<String, dynamic> json) {
    return CustomQuiz(
      id: json['id'] ?? '',
      quizType: json['quizType'] ?? '',
      title: json['title'] ?? '',
      category: json['category'],
      subCategory: json['subCategory'],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => CustomQuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

