import 'dart:async';
import 'package:flutter/material.dart';
import '../models/celebrity.dart';
import '../services/celebrity_service.dart';

enum QuizState {
  loading,
  showingImage,
  showingName,
  finished,
}

class QuizProvider with ChangeNotifier {
  final CelebrityService _celebrityService = CelebrityService();
  
  List<Celebrity> _celebrities = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  QuizState _state = QuizState.loading;
  Timer? _timer;
  
  // 타이머 시작 시간 추적
  DateTime? _timerStartTime;
  
  // Getters
  QuizState get state => _state;
  Celebrity? get currentCelebrity => 
      _celebrities.isNotEmpty && _currentIndex < _celebrities.length 
          ? _celebrities[_currentIndex] 
          : null;
  int get currentIndex => _currentIndex;
  int get totalCelebrities => _celebrities.length;
  int get correctAnswers => _correctAnswers;
  bool get isLastCelebrity => _currentIndex == _celebrities.length - 1;
  
  // 경과 시간 계산 (초 단위)
  int get elapsedTimeInSeconds {
    if (_timerStartTime == null || _state != QuizState.showingImage) {
      return 3; // 타이머가 없거나 이미지를 보여주는 상태가 아닌 경우 최대값 반환
    }
    
    final now = DateTime.now();
    final elapsedMilliseconds = now.difference(_timerStartTime!).inMilliseconds;
    final elapsedSeconds = (elapsedMilliseconds / 1000).floor();
    
    // 0~3초 범위로 제한
    return elapsedSeconds > 3 ? 3 : elapsedSeconds;
  }
  
  // 남은 시간 계산 (초 단위)
  int get remainingTimeInSeconds => 3 - elapsedTimeInSeconds;

  // Initialize the quiz with default celebrities
  Future<void> initQuiz() async {
    _state = QuizState.loading;
    notifyListeners();
    
    _celebrities = await _celebrityService.getQuizCelebrities();
    _currentIndex = 0;
    _correctAnswers = 0;
    
    _state = QuizState.showingImage;
    _timerStartTime = DateTime.now(); // 타이머 시작 시간 설정
    notifyListeners();
    
    // Start the timer to reveal the name after 3 seconds
    _startNameRevealTimer();
  }
  
  // Initialize the quiz with custom celebrities
  void initCustomQuiz(List<Celebrity> customCelebrities) {
    _state = QuizState.loading;
    notifyListeners();
    
    // 사용자가 제공한 인물 목록을 섞어서 사용
    _celebrities = List.from(customCelebrities);
    _celebrities.shuffle();
    
    _currentIndex = 0;
    _correctAnswers = 0;
    
    _state = QuizState.showingImage;
    _timerStartTime = DateTime.now(); // 타이머 시작 시간 설정
    notifyListeners();
    
    // Start the timer to reveal the name after 3 seconds
    _startNameRevealTimer();
  }

  // Start the timer to reveal the name
  void _startNameRevealTimer() {
    _timer?.cancel();
    _timerStartTime = DateTime.now(); // 타이머 시작 시간 갱신
    
    _timer = Timer(const Duration(seconds: 3), () {
      if (_state == QuizState.showingImage) {
        _state = QuizState.showingName;
        notifyListeners();
      }
    });
  }

  // Record the user's answer and move to the next celebrity
  void recordAnswer(bool isCorrect) {
    if (_state != QuizState.showingName) return;
    
    if (isCorrect) {
      _correctAnswers++;
    }

    if (isLastCelebrity) {
      _state = QuizState.finished;
    } else {
      _currentIndex++;
      _state = QuizState.showingImage;
      _timerStartTime = DateTime.now(); // 타이머 시작 시간 갱신
      _startNameRevealTimer();
    }
    
    notifyListeners();
  }

  // Restart the quiz
  void restartQuiz() {
    initQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
} 