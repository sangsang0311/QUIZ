import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'result_screen.dart';
import '../models/custom_quiz.dart';
import '../data/text_quiz_data.dart';
import '../utils/sound_manager.dart';

// 텍스트 문제 데이터 모델
class TextQuestion {
  final String questionText; // 문제 텍스트
  final String answer; // 정답
  final bool correctAnswer; // 정답 여부 (true = O, false = X)

  TextQuestion({
    required this.questionText,
    required this.answer,
    required this.correctAnswer,
  });
}

class TextQuizGameScreen extends StatefulWidget {
  final String category;
  final String? subCategory; // 초성 퀴즈용 서브 카테고리
  final int questionCount;
  final int countdownSeconds; // 카운트다운 시간 (0 = 없음, 3, 5)
  final CustomQuiz? customQuiz; // 커스텀 퀴즈

  const TextQuizGameScreen({
    super.key,
    required this.category,
    this.subCategory,
    required this.questionCount,
    this.countdownSeconds = 3, // 기본값 3초
    this.customQuiz,
  });

  @override
  State<TextQuizGameScreen> createState() => _TextQuizGameScreenState();
}

class _TextQuizGameScreenState extends State<TextQuizGameScreen>
    with TickerProviderStateMixin {
  List<TextQuestion> _questions = [];
  int currentQuestionIndex = 0;
  int countdown = 3;
  bool showButtons = false;
  bool showRevealButton = false; // 정답공개 버튼 표시 여부
  bool showAnswer = false; // 정답 표시 여부
  bool? selectedAnswer; // true = O, false = X, null = 선택 안함
  bool showNextButton = false;
  int correctAnswers = 0;
  List<bool> _questionAnswered = []; // 각 문제의 정답 체크 여부
  double? _questionContainerWidth; // 문제 컨테이너 너비 저장
  double? _questionContainerHeight; // 문제 컨테이너 높이 저장
  final GlobalKey _questionContainerKey = GlobalKey(); // 문제 컨테이너 위치 추적용
  final GlobalKey _countdownButtonAreaKey = GlobalKey(); // 카운트다운/정답공개 버튼 영역 위치 추적용
  final GlobalKey _questionTextKey = GlobalKey(); // 문제 텍스트 위치 추적용
  bool _isLandscapeMode = false; // 화면 모드 (false = 세로모드, true = 가로모드)
  
  late AnimationController _countdownController;
  late AnimationController _questionController;
  late AnimationController _buttonController;
  late AnimationController _answerTextController; // 정답 텍스트 애니메이션용
  late Animation<double> _countdownAnimation;
  late Animation<double> _questionAnimation;
  late Animation<double> _buttonAnimation;
  
  // 리스너 변수 (메모리 누수 방지)
  VoidCallback? _countdownListener;
  AnimationStatusListener? _countdownStatusListener;

  @override
  void initState() {
    super.initState();
    _loadScreenMode();
    
    // 카운트다운 애니메이션 (선택한 시간에 맞게 설정)
    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.countdownSeconds > 0 ? widget.countdownSeconds : 1),
    );
    
    _countdownAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _countdownController,
        curve: Curves.linear,
      ),
    )..addListener(() {
        // 애니메이션 값이 범위를 벗어나지 않도록 보장
        if (_countdownAnimation.value < 0.0 || _countdownAnimation.value > 1.0) {
          _countdownController.value = _countdownAnimation.value.clamp(0.0, 1.0);
        }
      });

    // 문제 텍스트 애니메이션
    _questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _questionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _questionController,
        curve: Curves.easeIn,
      ),
    )..addListener(() {
        // 애니메이션 값이 범위를 벗어나지 않도록 보장
        if (_questionAnimation.value < 0.0 || _questionAnimation.value > 1.0) {
          _questionController.value = _questionAnimation.value.clamp(0.0, 1.0);
        }
      });

    // 버튼 애니메이션
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        // 애니메이션 값이 범위를 벗어나지 않도록 보장
        if (_buttonAnimation.value < 0.0 || _buttonAnimation.value > 1.0) {
          _buttonController.value = _buttonAnimation.value.clamp(0.0, 1.0);
        }
      });

    // 정답 텍스트 애니메이션 (글자 하나씩 나타나기)
    _answerTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // 전체 애니메이션 시간 (더 빠르게)
    );

    _loadQuestions();
  }

  Future<void> _loadScreenMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLandscapeMode = prefs.getBool('isLandscapeMode') ?? false; // 기본값: 세로모드
    });
  }

  void _loadQuestions() {
    // 커스텀 퀴즈가 있으면 커스텀 퀴즈 사용
    if (widget.customQuiz != null) {
      final customQuestions = widget.customQuiz!.questions
          .map((q) {
            return TextQuestion(
              questionText: q.questionText ?? '',
              answer: q.answer,
              correctAnswer: q.isCorrect,
            );
          })
          .toList();
      
      // 랜덤으로 섞기
      customQuestions.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = customQuestions.take(widget.questionCount).toList();
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 수도 카테고리
    else if (widget.category == '수도') {
      final allQuestions = TextQuizData.capitalQuizzes
          .map((q) => TextQuestion(
                questionText: q['question']!,
                answer: q['answer']!,
                correctAnswer: true,
              ))
          .toList();
      
      allQuestions.shuffle(Random());
      _questions = allQuestions.take(widget.questionCount).toList();
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 속담 카테고리
    else if (widget.category == '속담') {
      final allQuestions = TextQuizData.proverbQuizzes
          .map((q) => TextQuestion(
                questionText: q['question']!,
                answer: q['answer']!,
                correctAnswer: true,
              ))
          .toList();
      
      allQuestions.shuffle(Random());
      _questions = allQuestions.take(widget.questionCount).toList();
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 초성 카테고리
    else if (widget.category == '초성') {
      if (widget.subCategory != null && TextQuizData.initialQuizzes.containsKey(widget.subCategory)) {
        final allQuestions = TextQuizData.initialQuizzes[widget.subCategory]!
            .map((q) => TextQuestion(
                  questionText: q['question']!,
                  answer: q['answer']!,
                  correctAnswer: true,
                ))
            .toList();
        
        allQuestions.shuffle(Random());
        _questions = allQuestions.take(widget.questionCount).toList();
        _questionAnswered = List.filled(_questions.length, false);
      } else {
        _questions = [];
        _questionAnswered = [];
      }
    }
    // 사자성어 카테고리
    else if (widget.category == '사자성어') {
      final allQuestions = TextQuizData.idiomQuizzes
          .map((q) => TextQuestion(
                questionText: q['question']!,
                answer: q['answer']!,
                correctAnswer: true,
              ))
          .toList();
      
      allQuestions.shuffle(Random());
      _questions = allQuestions.take(widget.questionCount).toList();
      _questionAnswered = List.filled(_questions.length, false);
    } else {
      // 알 수 없는 카테고리
      _questions = [];
      _questionAnswered = [];
    }
    
    _startQuestion();
  }

  void _startQuestion() {
    setState(() {
      countdown = widget.countdownSeconds;
      showButtons = false;
      showRevealButton = false;
      showAnswer = false;
      selectedAnswer = null;
      showNextButton = false;
    });

    // 정답 텍스트 애니메이션 컨트롤러 리셋 (가로모드에서 정답이 자동으로 표시되는 버그 수정)
    _answerTextController.reset();

    // 문제 텍스트 먼저 페이드인
    _questionController.forward(from: 0.0);
    
    // 카운트다운이 0이면 바로 정답공개 버튼 표시
    if (widget.countdownSeconds == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            showRevealButton = true;
          });
          _buttonController.forward(from: 0.0);
        }
      });
      return;
    }
    
    // 문제 표시 후 0.5초 뒤에 카운트다운 시작
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // 이전 리스너 제거 (메모리 누수 방지)
        if (_countdownListener != null) {
          _countdownController.removeListener(_countdownListener!);
        }
        if (_countdownStatusListener != null) {
          _countdownController.removeStatusListener(_countdownStatusListener!);
        }
        
        // 카운트다운 시작 (첫 번째 숫자 표시와 동시에 첫 번째 BEEP 재생)
        setState(() {
          countdown = widget.countdownSeconds;
        });
        SoundManager().playBeep(); // 첫 번째 BEEP 즉시 재생
        
        // 카운트다운 업데이트 및 BEEP 사운드 재생
        int lastCountdown = widget.countdownSeconds;
        _countdownListener = () {
          if (_countdownController.isAnimating && mounted) {
            final remaining = (widget.countdownSeconds * (1 - _countdownController.value)).ceil();
            // 숫자가 실제로 변경될 때만 BEEP 재생 (이전 값보다 작아질 때)
            if (remaining != lastCountdown && remaining >= 0 && remaining < lastCountdown) {
              SoundManager().playBeep(); // 숫자 변경과 동시에 BEEP 재생
              setState(() {
                countdown = remaining;
              });
              lastCountdown = remaining;
            }
          }
        };
        _countdownController.addListener(_countdownListener!);
        
        _countdownController.forward(from: 0.0);

        // 카운트다운 완료 후 정답공개 버튼 표시
        _countdownStatusListener = (status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() {
              showRevealButton = true;
            });
            _buttonController.forward(from: 0.0);
          }
        };
        _countdownController.addStatusListener(_countdownStatusListener!);
      }
    });
  }

  void _revealAnswer() {
    setState(() {
      showRevealButton = false;
      showAnswer = true;
      showButtons = true;
    });
    _buttonController.forward(from: 0.0);
    _answerTextController.forward(from: 0.0); // 정답 텍스트 애니메이션 시작
    SoundManager().playAnswer(); // 정답 공개 사운드 재생
  }

  void _selectAnswer(bool answer) {
    // O/X 버튼은 여러 번 선택 가능하도록 변경 (사용자 요청)
    // 정답 체크
    final currentQuestion = _questions[currentQuestionIndex];
    final isCorrect = answer == currentQuestion.correctAnswer;
    
    setState(() {
      selectedAnswer = answer;
      showNextButton = true;
      
      // 정답이 맞고 아직 이 문제에서 정답을 체크하지 않았으면 점수 증가
      if (isCorrect && !_questionAnswered[currentQuestionIndex]) {
        correctAnswers++;
        _questionAnswered[currentQuestionIndex] = true;
      } else if (!isCorrect && _questionAnswered[currentQuestionIndex]) {
        // 정답이었는데 틀린 답을 선택하면 점수 감소
        correctAnswers--;
        _questionAnswered[currentQuestionIndex] = false;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < _questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
      _startQuestion();
    } else {
      // 모든 문제 완료 - 결과 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            correctAnswers: correctAnswers,
            totalQuestions: _questions.length,
          ),
        ),
      );
    }
  }

  // 정답 텍스트 위젯 생성 (아래에서 올라오면서 페이드인)
  Widget _buildAnimatedText(String text, double progress) {
    // 부드러운 easeOutCubic 커브 적용
    final eased = 1 - pow(1 - progress, 3).toDouble();
    
    // Opacity: 페이드인
    final opacity = eased;
    
    // Slide up: 아래에서 위로 (30px 이동)
    final translateY = 30 * (1 - eased);
    
    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFF6B35), // 오렌지색
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnimatedTextWithSize(String text, double progress, double fontSize) {
    // 부드러운 easeOutCubic 커브 적용
    final eased = 1 - pow(1 - progress, 3).toDouble();
    
    // Opacity: 페이드인
    final opacity = eased;
    
    // Slide up: 아래에서 위로 (30px 이동)
    final translateY = 30 * (1 - eased);
    
    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF6B35), // 오렌지색
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 리스너 제거 (메모리 누수 방지)
    if (_countdownListener != null) {
      _countdownController.removeListener(_countdownListener!);
    }
    if (_countdownStatusListener != null) {
      _countdownController.removeStatusListener(_countdownStatusListener!);
    }
    
    _countdownController.dispose();
    _questionController.dispose();
    _buttonController.dispose();
    _answerTextController.dispose();
    super.dispose();
  }

  // 텍스트 너비 추정 헬퍼 메서드
  double _estimateTextWidth(String text, double fontSize) {
    // 한글은 대략 fontSize * 0.9, 영문/숫자는 fontSize * 0.6으로 추정
    double width = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (RegExp(r'[가-힣]').hasMatch(char)) {
        width += fontSize * 0.9; // 한글
      } else {
        width += fontSize * 0.6; // 영문/숫자
      }
    }
    // letterSpacing 고려 (2.0 * (문자수 - 1))
    width += 2.0 * (text.length - 1);
    return width;
  }
  
  // 텍스트 줄 수 추정 헬퍼 메서드
  int _estimateTextLines(String text, double fontSize, double availableWidth) {
    if (text.isEmpty) return 1;
    
    // 한 줄당 들어갈 수 있는 문자 수 추정
    final avgCharWidth = fontSize * 0.9; // 한글 기준
    final charsPerLine = (availableWidth / avgCharWidth).floor();
    
    if (charsPerLine <= 0) return 1;
    
    // 줄 수 계산
    final lines = (text.length / charsPerLine).ceil();
    return lines.clamp(1, 100); // 최소 1줄, 최대 100줄
  }
  
  // 텍스트 줄 수 계산 (더 정확한 계산)
  int _calculateTextLines(String text, double fontSize, double availableWidth) {
    if (text.isEmpty) return 1;
    
    // 한글은 대략 fontSize * 0.9, 영문/숫자는 fontSize * 0.6으로 추정
    // letterSpacing 1.0 고려
    double currentLineWidth = 0;
    int lines = 1;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      double charWidth;
      if (RegExp(r'[가-힣]').hasMatch(char)) {
        charWidth = fontSize * 0.9; // 한글
      } else {
        charWidth = fontSize * 0.6; // 영문/숫자
      }
      charWidth += 1.0; // letterSpacing
      
      if (currentLineWidth + charWidth > availableWidth && currentLineWidth > 0) {
        lines++;
        currentLineWidth = charWidth;
      } else {
        currentLineWidth += charWidth;
      }
    }
    
    return lines.clamp(1, 10); // 최소 1줄, 최대 10줄
  }

  @override
  Widget build(BuildContext context) {
    // 가로모드/세로모드에 따라 다른 레이아웃 표시
    if (_isLandscapeMode) {
      return _buildLandscapeLayout(context);
    } else {
      return _buildPortraitLayout(context);
    }
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerWidth = screenWidth * 0.60; // 중앙 60% 영역
    
    return Scaffold(
      backgroundColor: Colors.transparent, // 배경 투명 (main.dart에서 처리)
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠
            Center(
              child: SizedBox(
                width: centerWidth, // 중앙 60%만 사용
                child: Column(
                  children: [
                    // 문제 텍스트 표시 영역 (상단부터 크게, 가운데에 길게)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: const Alignment(0, -0.15), // 위로 올리기 (y: -0.15는 위로 15% 이동)
                            child: Transform.translate(
                              // 문제 위젯 위치 조절: offset의 y 값 (음수 값으로 위로 올림)
                              offset: const Offset(0, -60.0), // 문제 위젯 위치 조절 (15만큼 더 올림)
                              child: AnimatedBuilder(
                                animation: _questionAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _questionAnimation.value.clamp(0.0, 1.0),
                                    child: LayoutBuilder(
                                      builder: (context, innerConstraints) {
                                      // 기준 해상도: 1920x1080 (16:9)
                                      const double referenceWidth = 1920.0;
                                      const double referenceHeight = 1080.0;
                                      const double referenceAspectRatio = referenceWidth / referenceHeight; // 16:9 = 1.777...
                                      
                                      // 컨테이너 크기 계산
                                      final screenWidth = MediaQuery.of(context).size.width;
                                      final centerWidth = screenWidth * 0.60; // 중앙 영역 너비 (60%)
                                      final containerWidth = centerWidth.clamp(400.0, 800.0); // 최소 400px, 최대 800px
                                      final containerHeight = containerWidth / referenceAspectRatio * 1.25; // 16:9 비율 유지, 1.5배 더 길게
                                      
                                      // 문제 컨테이너 크기 및 위치 저장 (홈버튼, 진행도 위치 계산용)
                                      if (_questionContainerWidth != containerWidth || 
                                          _questionContainerHeight != containerHeight) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          setState(() {
                                            _questionContainerWidth = containerWidth;
                                            _questionContainerHeight = containerHeight;
                                          });
                                        });
                                      }
                                      
                                      if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
                                        final question = _questions[currentQuestionIndex];
                                        
                                        // 카테고리 텍스트 생성
                                        String categoryText;
                                        if (widget.customQuiz != null) {
                                          categoryText = widget.customQuiz!.title;
                                        } else if (widget.category == '초성' && widget.subCategory != null) {
                                          categoryText = widget.subCategory!;
                                        } else {
                                          categoryText = widget.category;
                                        }
                                        
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 문제 텍스트 컨테이너
                                            Container(
                                              key: _questionContainerKey,
                                              width: containerWidth,
                                              height: containerHeight,
                                              margin: const EdgeInsets.only(top: 0, bottom: 20),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(0xFF4AA0A9),
                                                  width: 4.0,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Stack(
                                                  children: [
                                                    // 카테고리 표시 (왼쪽 상단)
                                                    Positioned(
                                                      top: 16,
                                                      left: 16,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF4AA0A9).withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(
                                                            color: const Color(0xFF4AA0A9),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          categoryText,
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w900,
                                                            color: Colors.black87,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // 문제 텍스트 영역 (상단 70% = 7/10)
                                                    Positioned(
                                                      top: 0,
                                                      left: 0,
                                                      right: 0,
                                                      height: containerHeight * 0.7, // 상단 70% 영역
                                                      child: Builder(
                                                        builder: (context) {
                                                          // 커스텀 퀴즈인 경우 저장된 글씨 크기 사용, 아니면 텍스트 길이에 따라 결정
                                                          final double fontSize;
                                                          if (widget.customQuiz != null && 
                                                              currentQuestionIndex < widget.customQuiz!.questions.length) {
                                                            final customQuestion = widget.customQuiz!.questions[currentQuestionIndex];
                                                            if (customQuestion.questionFontSize != null) {
                                                              fontSize = customQuestion.questionFontSize!;
                                                            } else {
                                                              // 저장된 글씨 크기가 없으면 기본값 계산
                                                              final textLength = question.questionText.length;
                                                              if (textLength <= 10) {
                                                                fontSize = 64.0;
                                                              } else if (textLength <= 20) {
                                                                fontSize = 56.0;
                                                              } else if (textLength <= 30) {
                                                                fontSize = 48.0;
                                                              } else if (textLength <= 40) {
                                                                fontSize = 40.0;
                                                              } else {
                                                                fontSize = 36.0;
                                                              }
                                                            }
                                                          } else {
                                                            // 일반 퀴즈인 경우 텍스트 길이에 따라 결정
                                                            final textLength = question.questionText.length;
                                                            if (textLength <= 10) {
                                                              fontSize = 64.0;
                                                            } else if (textLength <= 20) {
                                                              fontSize = 56.0;
                                                            } else if (textLength <= 30) {
                                                              fontSize = 48.0;
                                                            } else if (textLength <= 40) {
                                                              fontSize = 40.0;
                                                            } else {
                                                              fontSize = 36.0;
                                                            }
                                                          }
                                                          
                                                          return Center(
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(40.0),
                                                              child: Text(
                                                                key: _questionTextKey,
                                                                question.questionText,
                                                                textAlign: TextAlign.center,
                                                                style: TextStyle(
                                                                  fontSize: fontSize,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Colors.black87,
                                                                  letterSpacing: 1.0,
                                                                  height: 1.4,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    // 정답 영역 (하단 30% = 3/10)
                                                    if (showAnswer)
                                                      Positioned(
                                                        bottom: 0,
                                                        left: 0,
                                                        right: 0,
                                                        height: containerHeight * 0.3, // 하단 30% 영역
                                                        child: Builder(
                                                          builder: (context) {
                                                            // 텍스트 길이에 따라 동적으로 크기 조절
                                                            final text = question.answer;
                                                            final textLength = text.length;
                                                            
                                                            // 최대 20글자 제한
                                                            final displayText = textLength > 20 ? text.substring(0, 20) : text;
                                                            
                                                            // 19글자 이상일 때만 줄바꿈 (띄어쓰기 포함 18글자까지는 1줄)
                                                            String firstLine = displayText;
                                                            String? secondLine;
                                                            if (displayText.length >= 19) {
                                                              // 19글자 이상이면 첫 18글자와 나머지로 나누기
                                                              firstLine = displayText.substring(0, 18);
                                                              secondLine = displayText.substring(18);
                                                            }
                                                            
                                                            // 커스텀 퀴즈인 경우 저장된 글씨 크기 사용, 아니면 텍스트 길이에 따라 결정
                                                            double answerFontSize;
                                                            if (widget.customQuiz != null && 
                                                                currentQuestionIndex < widget.customQuiz!.questions.length) {
                                                              final customQuestion = widget.customQuiz!.questions[currentQuestionIndex];
                                                              if (customQuestion.answerFontSize != null) {
                                                                answerFontSize = customQuestion.answerFontSize!;
                                                              } else {
                                                                // 저장된 글씨 크기가 없으면 기본값 계산
                                                                if (secondLine == null) {
                                                                  if (textLength <= 10) {
                                                                    answerFontSize = 64.0;
                                                                  } else if (textLength <= 20) {
                                                                    answerFontSize = 56.0;
                                                                  } else if (textLength <= 30) {
                                                                    answerFontSize = 48.0;
                                                                  } else if (textLength <= 40) {
                                                                    answerFontSize = 40.0;
                                                                  } else {
                                                                    answerFontSize = 36.0;
                                                                  }
                                                                } else {
                                                                  answerFontSize = 44.0;
                                                                }
                                                              }
                                                            } else {
                                                              // 일반 퀴즈인 경우 텍스트 길이에 따라 결정
                                                              if (secondLine == null) {
                                                                if (textLength <= 10) {
                                                                  answerFontSize = 64.0;
                                                                } else if (textLength <= 20) {
                                                                  answerFontSize = 56.0;
                                                                } else if (textLength <= 30) {
                                                                  answerFontSize = 48.0;
                                                                } else if (textLength <= 40) {
                                                                  answerFontSize = 40.0;
                                                                } else {
                                                                  answerFontSize = 36.0;
                                                                }
                                                              } else {
                                                                answerFontSize = 44.0;
                                                              }
                                                            }
                                                            
                                                            return AnimatedBuilder(
                                                              animation: _answerTextController,
                                                              builder: (context, child) {
                                                                final progress = _answerTextController.value;
                                                                
                                                                return Center(
                                                                  child: secondLine != null
                                                                      ? Column(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                                          children: [
                                                                            _buildAnimatedTextWithSize(firstLine, progress, answerFontSize),
                                                                            const SizedBox(height: 4),
                                                                            _buildAnimatedTextWithSize(secondLine!, progress, answerFontSize),
                                                                          ],
                                                                        )
                                                                      : _buildAnimatedTextWithSize(firstLine, progress, answerFontSize),
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      
                                      // 문제가 없는 경우
                                      return Stack(
                                        alignment: Alignment.topCenter,
                                        children: [
                                          Container(
                                            width: containerWidth,
                                            height: containerHeight,
                                            margin: const EdgeInsets.only(top: 20, bottom: 20),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(20),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.help_outline,
                                                  size: 100,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 카운트다운/정답공개/OX 버튼 영역 (문제 컨테이너 아래 끝선에 맞춤)
            if (_questionContainerWidth != null && _questionContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? questionBox = _questionContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (questionBox != null) {
                    final position = questionBox.localToGlobal(Offset.zero);
                    final size = questionBox.size;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final centerWidth = screenWidth * 0.60;
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset, // 문제 컨테이너 아래 끝선 + offset
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: centerWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 카운트다운/정답공개/OX 버튼 영역 (통일된 고정 높이 120px)
                              SizedBox(
                                key: _countdownButtonAreaKey,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 카운트다운
                                    if (widget.countdownSeconds > 0 && !showRevealButton && !showButtons)
                                      AnimatedBuilder(
                                        animation: _countdownAnimation,
                                        builder: (context, child) {
                                          // 부드러운 펄스 효과: sin 파형을 사용한 크기 변화
                                          final progress = _countdownAnimation.value;
                                          final pulse = (1.0 - progress) * 2.0; // 0.0 ~ 2.0
                                          final scale = 0.85 + (0.15 * (1.0 + (0.5 * (1.0 - progress))));
                                          final opacity = 0.8 + (0.2 * (1.0 - progress));
                                          
                                          return Transform.scale(
                                            scale: scale.clamp(0.85, 1.0),
                                            child: Opacity(
                                              opacity: opacity.clamp(0.8, 1.0),
                                              child: SizedBox(
                                                width: 120,
                                                height: 120,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // 에셋 이미지 배경
                                                    Image.asset(
                                                      'assets/images/Widget_Countdown.png',
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.contain,
                                                      filterQuality: FilterQuality.high,
                                                      isAntiAlias: true,
                                                    ),
                                                    // 숫자 텍스트 오버레이
                                                    Text(
                                                      countdown > 0 ? countdown.toString() : '',
                                                      style: const TextStyle(
                                                        fontSize: 60,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    // 정답공개 버튼 (홈버튼, 진행바와 끝선 맞추기 위해 위로 올림)
                                    if (showRevealButton && !showAnswer)
                                      Positioned(
                                        // 정답공개 버튼 위치 조절: bottom 값 (값이 클수록 위로 올라감)
                                        bottom: 35.0, // 위치 조절 (기본: 20, 더 위로 올리려면 더 큰 값)
                                        left: 0,
                                        right: 0,
                                        child: AnimatedBuilder(
                                          animation: _buttonAnimation,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                                              child: Transform.scale(
                                                scale: _buttonAnimation.value.clamp(0.0, 1.0),
                                                child: GestureDetector(
                                                  onTap: _revealAnswer,
                                                  child: Image.asset(
                                                    'assets/images/Button_Answer.png',
                                                    width: 276,
                                                    height: 82.8,
                                                    fit: BoxFit.contain,
                                                    filterQuality: FilterQuality.high,
                                                    isAntiAlias: true,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    // O, X 버튼
                                    if (showButtons)
                                      Positioned(
                                        // OX 버튼 위치 조절: bottom 값 (값이 클수록 위로 올라감)
                                        bottom: 35.0, // 위치 조절 (기본: 20, 더 위로 올리려면 더 큰 값)
                                        left: 0,
                                        right: 0,
                                        child: AnimatedBuilder(
                                          animation: _buttonAnimation,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                                              child: Transform.scale(
                                                scale: _buttonAnimation.value.clamp(0.0, 1.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // O 버튼
                                                    GestureDetector(
                                                      onTap: () => _selectAnswer(true),
                                                      child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 200),
                                                        width: 80,
                                                        height: 80,
                                                        child: Opacity(
                                                          opacity: selectedAnswer == true ? 1.0 : 0.7,
                                                          child: RepaintBoundary(
                                                            child: Image.asset(
                                                              'assets/images/Button_O.png',
                                                              width: 80,
                                                              height: 80,
                                                              fit: BoxFit.contain,
                                                              filterQuality: FilterQuality.high,
                                                              isAntiAlias: true,
                                                              cacheWidth: 80,
                                                              cacheHeight: 80,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    
                                                    const SizedBox(width: 30),
                                                    
                                                    // X 버튼
                                                    GestureDetector(
                                                      onTap: () => _selectAnswer(false),
                                                      child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 200),
                                                        width: 80,
                                                        height: 80,
                                                        child: Opacity(
                                                          opacity: selectedAnswer == false ? 1.0 : 0.7,
                                                          child: RepaintBoundary(
                                                            child: Image.asset(
                                                              'assets/images/Button_X.png',
                                                              width: 80,
                                                              height: 80,
                                                              fit: BoxFit.contain,
                                                              filterQuality: FilterQuality.high,
                                                              isAntiAlias: true,
                                                              cacheWidth: 80,
                                                              cacheHeight: 80,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // 다음 문제 버튼 영역 (고정 높이로 레이아웃 시프트 방지)
                              SizedBox(
                                height: 100,
                                child: Stack(
                                  clipBehavior: Clip.none, // 버튼이 잘리지 않도록 설정
                                  alignment: Alignment.center,
                                  children: [
                                    if (showNextButton)
                                      Positioned(
                                        // 다음 문제 버튼 위치 조절: top 값 (값이 작을수록 위로 올라감)
                                        top: 5.0, // 위치 조절 (기본: 0, 더 위로 올리려면 음수 값, 더 아래로 내리려면 양수 값)
                                        left: 0,
                                        right: 0,
                                        child: AnimatedBuilder(
                                          animation: _buttonAnimation,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                                              child: GestureDetector(
                                                onTap: _nextQuestion,
                                                child: Image.asset(
                                                  'assets/images/Button_Next.png',
                                                  width: 330,
                                                  height: 82.5,
                                                  fit: BoxFit.contain,
                                                  filterQuality: FilterQuality.high,
                                                  isAntiAlias: true,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            
            // 왼쪽 하단 메인메뉴 버튼 (문제 컨테이너 왼쪽 끝선에 맞춤)
            if (_questionContainerWidth != null && _questionContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? questionBox = _questionContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (questionBox != null) {
                    final position = questionBox.localToGlobal(Offset.zero);
                    final size = questionBox.size;
                    // 문제 컨테이너의 왼쪽 끝선에 맞춤
                    final questionLeft = position.dx;
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset,
                      left: questionLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RepaintBoundary(
                          child: Image.asset(
                            'assets/images/Button_Home.png',
                            width: 55,
                            height: 55,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                            cacheWidth: 55,
                            cacheHeight: 55,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            
            // 오른쪽 하단 진행도 표시 (문제 컨테이너 오른쪽 끝선에 맞춤)
            if (_questionContainerWidth != null && _questionContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? questionBox = _questionContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (questionBox != null) {
                    final position = questionBox.localToGlobal(Offset.zero);
                    final size = questionBox.size;
                    // 문제 컨테이너의 오른쪽 끝선에 맞춤
                    final questionRight = position.dx + size.width;
                    // 진행바 위젯 크기
                    const progressWidth = 100.0;  // 가로 길이 조절 (기본: 200)
                    const progressHeight = 100.0; // 세로 길이 조절 (기본: 60)
                    // 진행바 위젯 위치 조절: top 값 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    const progressTopOffset = -30.0; // 위치 조절 (기본: -20, 위로 올리려면 더 작은 값)
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + progressTopOffset + globalTopOffset,
                      left: questionRight - progressWidth, // 진행바의 오른쪽 끝이 문제 컨테이너 오른쪽 끝선에 맞춤
                      child: SizedBox(
                        // 진행바 위젯 크기 조절: width (가로), height (세로)
                        width: progressWidth,
                        height: progressHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 에셋 이미지 배경
                            Image.asset(
                              'assets/images/Widget_Progress.png',
                              width: progressWidth,
                              height: progressHeight,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                            ),
                            // 진행도 텍스트 오버레이
                            Text(
                              '${currentQuestionIndex + 1} / ${widget.questionCount}',
                              style: const TextStyle(
                                fontSize: 20,  // 크기에 맞게 조절 (기본: 20)
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          children: [
            // 왼쪽: 문제 텍스트 영역 (70%)
            Expanded(
              flex: 7,
              child: _buildLandscapeQuestionArea(context, screenWidth * 0.70, screenHeight),
            ),
            // 오른쪽: 사이드바 (30%)
            Expanded(
              flex: 3,
              child: _buildLandscapeSidebar(context, screenWidth * 0.30, screenHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeQuestionArea(BuildContext context, double width, double height) {
    return Center(
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Expanded(
              child: ClipRect(
                clipBehavior: Clip.none,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _questionAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _questionAnimation.value.clamp(0.0, 1.0),
                          child: LayoutBuilder(
                            builder: (context, innerConstraints) {
                              // 기준 해상도: 1920x1080 (16:9)
                              const double referenceWidth = 1920.0;
                              const double referenceHeight = 1080.0;
                              const double referenceAspectRatio = referenceWidth / referenceHeight; // 16:9 = 1.777...
                              
                              // 세로 길이를 화면 전체 높이의 90%로 설정하고, 비율에 맞게 가로 길이 계산
                              final containerHeight = height * 0.90; // 화면의 세로 길이의 90% (10% 줄임)
                              // 세로모드와 동일한 비율 유지: containerHeight = containerWidth / referenceAspectRatio * 1.25
                              // 따라서: containerWidth = containerHeight / 1.25 * referenceAspectRatio
                              final containerWidth = (containerHeight / 1.25) * referenceAspectRatio;
                              // 가로 길이가 사용 가능한 너비를 넘지 않도록 제한
                              final maxWidth = width * 0.95; // 좌우 여백 고려
                              final finalContainerWidth = containerWidth.clamp(400.0, maxWidth);
                              
                              if (_questionContainerWidth != finalContainerWidth || 
                                  _questionContainerHeight != containerHeight) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setState(() {
                                    _questionContainerWidth = finalContainerWidth;
                                    _questionContainerHeight = containerHeight;
                                  });
                                });
                              }
                              
                              if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
                                final question = _questions[currentQuestionIndex];
                                
                                // 카테고리 텍스트 생성
                                String categoryText;
                                if (widget.customQuiz != null) {
                                  categoryText = widget.customQuiz!.title;
                                } else if (widget.category == '초성' && widget.subCategory != null) {
                                  categoryText = widget.subCategory!;
                                } else {
                                  categoryText = widget.category;
                                }
                                
                                return Align(
                                  alignment: Alignment.center, // 세로 중앙 정렬
                                  child: Transform.translate(
                                    offset: const Offset(275, 0), // X축으로 오른쪽으로 이동
                                    child: Container(
                                      key: _questionContainerKey,
                                      width: finalContainerWidth,
                                      height: containerHeight,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF7B1FA2),
                                          width: 4.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Stack(
                                          children: [
                                            // 카테고리 표시 (왼쪽 상단)
                                            Positioned(
                                              top: 16,
                                              left: 16,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF7B1FA2).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(0xFF7B1FA2),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Text(
                                                  categoryText,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black87,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // 문제 텍스트 영역 (상단 70%)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              height: containerHeight * 0.7,
                                              child: Builder(
                                                builder: (context) {
                                                  final double fontSize;
                                                  if (widget.customQuiz != null && 
                                                      currentQuestionIndex < widget.customQuiz!.questions.length) {
                                                    final customQuestion = widget.customQuiz!.questions[currentQuestionIndex];
                                                    if (customQuestion.questionFontSize != null) {
                                                      fontSize = customQuestion.questionFontSize!;
                                                    } else {
                                                      final textLength = question.questionText.length;
                                                      if (textLength <= 10) {
                                                        fontSize = 64.0;
                                                      } else if (textLength <= 20) {
                                                        fontSize = 56.0;
                                                      } else if (textLength <= 30) {
                                                        fontSize = 48.0;
                                                      } else {
                                                        fontSize = 40.0;
                                                      }
                                                    }
                                                  } else {
                                                    final textLength = question.questionText.length;
                                                    if (textLength <= 10) {
                                                      fontSize = 96.0; // 64.0 * 1.5
                                                    } else if (textLength <= 20) {
                                                      fontSize = 84.0; // 56.0 * 1.5
                                                    } else if (textLength <= 30) {
                                                      fontSize = 72.0; // 48.0 * 1.5
                                                    } else {
                                                      fontSize = 60.0; // 40.0 * 1.5
                                                    }
                                                  }
                                                  
                                                  return Center(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(40.0),
                                                      child: Text(
                                                        question.questionText,
                                                        key: _questionTextKey,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: fontSize,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black87,
                                                          letterSpacing: 2.0,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // 정답 표시 (하단 30%) - showAnswer가 true일 때만 표시
                                            if (showAnswer)
                                              _buildLandscapeAnswerOverlay(question, finalContainerWidth, containerHeight),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              
                              return const SizedBox.shrink();
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeAnswerOverlay(TextQuestion question, double containerWidth, double containerHeight) {
    final text = question.answer;
    final textLength = text.length;
    
    // 최대 20글자 제한
    final displayText = textLength > 20 ? text.substring(0, 20) : text;
    
    // 19글자 이상일 때만 줄바꿈 (띄어쓰기 포함 18글자까지는 1줄)
    String firstLine = displayText;
    String? secondLine;
    if (displayText.length >= 19) {
      // 19글자 이상이면 첫 18글자와 나머지로 나누기
      firstLine = displayText.substring(0, 18);
      secondLine = displayText.substring(18);
    }
    
    // 커스텀 퀴즈인 경우 저장된 글씨 크기 사용, 아니면 텍스트 길이에 따라 결정
    double answerFontSize;
    if (widget.customQuiz != null && 
        currentQuestionIndex < widget.customQuiz!.questions.length) {
      final customQuestion = widget.customQuiz!.questions[currentQuestionIndex];
      if (customQuestion.answerFontSize != null) {
        answerFontSize = customQuestion.answerFontSize!;
      } else {
        // 저장된 글씨 크기가 없으면 기본값 계산
        if (secondLine == null) {
          if (textLength <= 10) {
            answerFontSize = 64.0;
          } else if (textLength <= 20) {
            answerFontSize = 56.0;
          } else if (textLength <= 30) {
            answerFontSize = 48.0;
          } else if (textLength <= 40) {
            answerFontSize = 40.0;
          } else {
            answerFontSize = 36.0;
          }
        } else {
          answerFontSize = 44.0;
        }
      }
    } else {
      // 일반 퀴즈인 경우 텍스트 길이에 따라 결정
      if (secondLine == null) {
        if (textLength <= 10) {
          answerFontSize = 96.0; // 64.0 * 1.5
        } else if (textLength <= 20) {
          answerFontSize = 84.0; // 56.0 * 1.5
        } else if (textLength <= 30) {
          answerFontSize = 72.0; // 48.0 * 1.5
        } else if (textLength <= 40) {
          answerFontSize = 60.0; // 40.0 * 1.5
        } else {
          answerFontSize = 54.0; // 36.0 * 1.5
        }
      } else {
        answerFontSize = 66.0; // 44.0 * 1.5
      }
    }
    
    final double ribbonHeight = containerHeight * 0.3;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: ribbonHeight,
      child: AnimatedBuilder(
        animation: _answerTextController,
        builder: (context, child) {
          final progress = _answerTextController.value;
          
          // progress가 0이면 아무것도 표시하지 않음 (정답공개 버튼을 눌러야만 표시)
          if (progress <= 0.0) {
            return const SizedBox.shrink();
          }
          
          return Center(
            child: secondLine != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAnimatedTextWithSize(firstLine, progress, answerFontSize),
                      const SizedBox(height: 4),
                      _buildAnimatedTextWithSize(secondLine!, progress, answerFontSize),
                    ],
                  )
                : _buildAnimatedTextWithSize(firstLine, progress, answerFontSize),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeSidebar(BuildContext context, double width, double height) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 상단: 홈 버튼과 진행도를 나란히 배치 (문제 위젯의 윗선에 맞춤)
          Transform.translate(
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RepaintBoundary(
                    child: Image.asset(
                      'assets/images/Button_Home.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      cacheWidth: 70,
                      cacheHeight: 70,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Widget_Progress.png',
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      Text(
                        '${currentQuestionIndex + 1} / ${widget.questionCount}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 카운트다운/정답공개/OX 버튼 (홈 버튼과 진행도 바로 밑)
          Transform.translate(
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동
            child: SizedBox(
              height: 156,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.countdownSeconds > 0 && !showRevealButton && !showButtons)
                    AnimatedBuilder(
                      animation: _countdownAnimation,
                      builder: (context, child) {
                        final progress = _countdownAnimation.value;
                        final scale = 0.85 + (0.15 * (1.0 + (0.5 * (1.0 - progress))));
                        final opacity = 0.8 + (0.2 * (1.0 - progress));
                        
                        return Transform.scale(
                          scale: scale.clamp(0.85, 1.0),
                          child: Opacity(
                            opacity: opacity.clamp(0.8, 1.0),
                            child: SizedBox(
                              width: 156,
                              height: 156,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/Widget_Countdown.png',
                                    width: 156,
                                    height: 156,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    isAntiAlias: true,
                                  ),
                                  Text(
                                    countdown > 0 ? countdown.toString() : '',
                                    style: const TextStyle(
                                      fontSize: 78,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (showRevealButton && !showAnswer)
                    AnimatedBuilder(
                      animation: _buttonAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _buttonAnimation.value.clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: _revealAnswer,
                              child: Image.asset(
                                'assets/images/Button_Answer.png',
                                width: 359,
                                height: 107.6,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (showButtons)
                    AnimatedBuilder(
                      animation: _buttonAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _buttonAnimation.value.clamp(0.0, 1.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => _selectAnswer(true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 104,
                                    height: 104,
                                    child: Opacity(
                                      opacity: selectedAnswer == true ? 1.0 : 0.7,
                                      child: RepaintBoundary(
                                        child: Image.asset(
                                          'assets/images/Button_O.png',
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          isAntiAlias: true,
                                          cacheWidth: 104,
                                          cacheHeight: 104,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 39),
                                GestureDetector(
                                  onTap: () => _selectAnswer(false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 104,
                                    height: 104,
                                    child: Opacity(
                                      opacity: selectedAnswer == false ? 1.0 : 0.7,
                                      child: RepaintBoundary(
                                        child: Image.asset(
                                          'assets/images/Button_X.png',
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          isAntiAlias: true,
                                          cacheWidth: 104,
                                          cacheHeight: 104,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 다음 문제 버튼 (카운트다운 위젯 바로 밑)
          Transform.translate(
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동
            child: SizedBox(
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (showNextButton)
                    AnimatedBuilder(
                      animation: _buttonAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                          child: GestureDetector(
                            onTap: _nextQuestion,
                            child: Image.asset(
                              'assets/images/Button_Next.png',
                              width: 429,
                              height: 107.25,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

