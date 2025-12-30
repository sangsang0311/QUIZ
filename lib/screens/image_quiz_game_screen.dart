import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'result_screen.dart';
import '../models/custom_quiz.dart';
import '../utils/sound_manager.dart';

// 동물 문제 데이터 모델
class AnimalQuestion {
  final String imagePath;
  final String? imageBytesBase64; // base64 인코딩된 이미지 (웹용)
  final String animalName; // 동물 이름
  final bool correctAnswer; // 정답 (true = O, false = X)
  // 이미지 위치 및 크기 정보
  final double? imageTop;
  final double? imageLeft;
  final double? imageWidth;
  final double? imageHeight;

  AnimalQuestion({
    required this.imagePath,
    this.imageBytesBase64,
    required this.animalName,
    required this.correctAnswer,
    this.imageTop,
    this.imageLeft,
    this.imageWidth,
    this.imageHeight,
  });
}

class ImageQuizGameScreen extends StatefulWidget {
  final String category;
  final int questionCount;
  final int countdownSeconds; // 카운트다운 시간 (0 = 없음, 3, 5)
  final CustomQuiz? customQuiz; // 커스텀 퀴즈

  const ImageQuizGameScreen({
    super.key,
    required this.category,
    required this.questionCount,
    this.countdownSeconds = 3, // 기본값 3초
    this.customQuiz,
  });

  @override
  State<ImageQuizGameScreen> createState() => _ImageQuizGameScreenState();
}

class _ImageQuizGameScreenState extends State<ImageQuizGameScreen>
    with TickerProviderStateMixin {
  List<AnimalQuestion> _questions = [];
  int currentQuestionIndex = 0;
  int countdown = 3;
  bool showButtons = false;
  bool showRevealButton = false; // 정답공개 버튼 표시 여부
  bool showAnswer = false; // 정답 표시 여부
  bool? selectedAnswer; // true = O, false = X, null = 선택 안함
  bool showNextButton = false;
  int correctAnswers = 0;
  List<bool> _questionAnswered = []; // 각 문제의 정답 체크 여부
  double? _imageContainerWidth; // 이미지 컨테이너 너비 저장
  double? _imageContainerHeight; // 이미지 컨테이너 높이 저장
  final GlobalKey _imageContainerKey = GlobalKey(); // 이미지 컨테이너 위치 추적용
  final GlobalKey _countdownButtonAreaKey = GlobalKey(); // 카운트다운/정답공개 버튼 영역 위치 추적용
  bool _isLandscapeMode = false; // 화면 모드 (false = 세로모드, true = 가로모드)
  
  late AnimationController _countdownController;
  late AnimationController _imageController;
  late AnimationController _buttonController;
  late Animation<double> _countdownAnimation;
  late Animation<double> _imageAnimation;
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
      duration: Duration(seconds: widget.countdownSeconds),
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

    // 이미지 애니메이션
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _imageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _imageController,
        curve: Curves.easeIn,
      ),
    )..addListener(() {
        // 애니메이션 값이 범위를 벗어나지 않도록 보장
        if (_imageAnimation.value < 0.0 || _imageAnimation.value > 1.0) {
          _imageController.value = _imageAnimation.value.clamp(0.0, 1.0);
        }
      });

    // 버튼 애니메이션 (그림자 애니메이션 포함)
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // 그림자 애니메이션을 위해 조금 더 길게
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeOutCubic, // 더 부드러운 곡선
      ),
    )..addListener(() {
        // 애니메이션 값이 범위를 벗어나지 않도록 보장
        if (_buttonAnimation.value < 0.0 || _buttonAnimation.value > 1.0) {
          _buttonController.value = _buttonAnimation.value.clamp(0.0, 1.0);
        }
      });

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
            // base64로 저장된 이미지인지 확인
            String? base64Data;
            if (q.imagePath != null && q.imagePath!.startsWith('data:image') == false) {
              try {
                // base64 디코딩 시도
                base64Decode(q.imagePath!);
                base64Data = q.imagePath;
              } catch (e) {
                // base64가 아니면 일반 경로로 처리
              }
            } else if (q.imagePath != null) {
              base64Data = q.imagePath;
            }
            
            return AnimalQuestion(
              imagePath: q.imagePath ?? '',
              imageBytesBase64: base64Data,
              animalName: q.answer,
              correctAnswer: q.isCorrect,
              imageTop: q.imageTop,
              imageLeft: q.imageLeft,
              imageWidth: q.imageWidth,
              imageHeight: q.imageHeight,
            );
          })
          .toList();
      
      // 랜덤으로 섞기
      customQuestions.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = customQuestions.take(widget.questionCount).toList();
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 동물 카테고리일 때 동물 데이터 로드
    else if (widget.category == '동물') {
      final allAnimals = [
        AnimalQuestion(imagePath: 'assets/images/Animal_Baer.png', animalName: '곰', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Cat.png', animalName: '고양이', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Dog.png', animalName: '강아지', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Giraffe.png', animalName: '기린', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Hedgehog.png', animalName: '고슴도치', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Koala.png', animalName: '코알라', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Lion.png', animalName: '사자', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Panda.png', animalName: '팬더', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Rabbit.png', animalName: '토끼', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Animal_Tiger.png', animalName: '호랑이', correctAnswer: true),
      ];
      
      // 랜덤으로 섞기
      allAnimals.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = allAnimals.take(widget.questionCount).toList();
      // 정답 체크 여부 초기화
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 과일 카테고리일 때 과일 데이터 로드
    else if (widget.category == '과일') {
      final allFruits = [
        AnimalQuestion(imagePath: 'assets/images/Fruit_Apple.png', animalName: '사과', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Banana.png', animalName: '바나나', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Cherry.png', animalName: '체리', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Grape.png', animalName: '포도', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Kiwi.png', animalName: '키위', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Lemon.png', animalName: '레몬', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Pineapple.png', animalName: '파인애플', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Pomegranate.png', animalName: '석류', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Strawberry.png', animalName: '딸기', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Fruit_Watermelon.png', animalName: '수박', correctAnswer: true),
      ];
      
      // 랜덤으로 섞기
      allFruits.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = allFruits.take(widget.questionCount).toList();
      // 정답 체크 여부 초기화
      _questionAnswered = List.filled(_questions.length, false);
    }
    // 나라 카테고리일 때 나라 데이터 로드
    else if (widget.category == '나라') {
      final allCountries = [
        AnimalQuestion(imagePath: 'assets/images/Country_Canada.png', animalName: '캐나다', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_China.png', animalName: '중국', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_France.png', animalName: '프랑스', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_Germany.png', animalName: '독일', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_Italy.png', animalName: '이탈리아', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_Japan.png', animalName: '일본', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_Korea.png', animalName: '한국', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_United Kingdom.png', animalName: '영국', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_UnitedStates.png', animalName: '미국', correctAnswer: true),
        AnimalQuestion(imagePath: 'assets/images/Country_Vietnam.png', animalName: '베트남', correctAnswer: true),
      ];
      
      // 랜덤으로 섞기
      allCountries.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = allCountries.take(widget.questionCount).toList();
      // 정답 체크 여부 초기화
      _questionAnswered = List.filled(_questions.length, false);
    } else {
      // 알 수 없는 카테고리
      _questions = [];
      _questionAnswered = [];
    }
    
    _startQuestion();
  }

  Widget _buildQuestionImage(AnimalQuestion question) {
    // base64로 저장된 이미지인 경우
    if (question.imageBytesBase64 != null) {
      try {
        final bytes = base64Decode(question.imageBytesBase64!);
        return Image.memory(
          bytes,
          fit: BoxFit.fill, // 미리보기 화면과 동일: 비율 무시하고 선택한 크기에 맞춰 왜곡
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.image,
                size: 100,
                color: Colors.grey,
              ),
            );
          },
        );
      } catch (e) {
        // base64 디코딩 실패 시 일반 경로로 시도
      }
    }
    
    // 일반 경로 (assets 또는 파일)
    if (question.imagePath.startsWith('assets/')) {
      return Image.asset(
        question.imagePath,
        fit: BoxFit.fill, // 미리보기 화면과 동일: 비율 무시하고 선택한 크기에 맞춰 왜곡
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image,
              size: 100,
              color: Colors.grey,
            ),
          );
        },
      );
    } else if (!kIsWeb) {
      // 모바일에서 파일 경로 사용
      return Image.file(
        File(question.imagePath),
        fit: BoxFit.fill, // 미리보기 화면과 동일: 비율 무시하고 선택한 크기에 맞춰 왜곡
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image,
              size: 100,
              color: Colors.grey,
            ),
          );
        },
      );
    }
    
    return const Center(
      child: Icon(
        Icons.image,
        size: 100,
        color: Colors.grey,
      ),
    );
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

  void _startQuestion() {
    setState(() {
      countdown = widget.countdownSeconds;
      showButtons = false;
      showRevealButton = false;
      showAnswer = false;
      selectedAnswer = null;
      showNextButton = false;
    });

    // 이미지 먼저 페이드인
    _imageController.forward(from: 0.0);
    
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
    
    // 이미지 표시 후 0.5초 뒤에 카운트다운 시작
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
    _imageController.dispose();
    _buttonController.dispose();
    super.dispose();
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
                // 이미지 표시 영역 (상단부터 크게, 가운데에 길게)
                Expanded(
                  child: ClipRect(
                    clipBehavior: Clip.none, // Transform.translate가 Expanded 경계를 벗어나도 잘리지 않도록
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedBuilder(
                          animation: _imageAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _imageAnimation.value.clamp(0.0, 1.0),
                              child: LayoutBuilder(
                                builder: (context, innerConstraints) {
                                  // 기준 해상도: 1920x1080 (16:9)
                                  const double referenceWidth = 1920.0;
                                  const double referenceHeight = 1080.0;
                                  const double referenceAspectRatio = referenceWidth / referenceHeight; // 16:9 = 1.777...
                                  
                                  // 컨테이너 크기 계산 (텍스트 퀴즈와 동일한 크기로 맞춤)
                                  final screenWidth = MediaQuery.of(context).size.width;
                                  final centerWidth = screenWidth * 0.60; // 중앙 영역 너비 (60%)
                                  // 텍스트 퀴즈와 동일한 크기 적용 (최대 800px, 높이 1.25배)
                                  final containerWidth = centerWidth.clamp(400.0, 800.0); // 텍스트 퀴즈와 동일: 최소 400px, 최대 800px
                                  final containerHeight = containerWidth / referenceAspectRatio * 1.25; // 텍스트 퀴즈와 동일: 1.25배 더 길게
                                  
                                  // 이미지 컨테이너 크기 및 위치 저장 (홈버튼, 진행도 위치 계산용)
                                  if (_imageContainerWidth != containerWidth || 
                                      _imageContainerHeight != containerHeight) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      setState(() {
                                        _imageContainerWidth = containerWidth;
                                        _imageContainerHeight = containerHeight;
                                      });
                                    });
                                  }
                                  
                                  if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
                                    final question = _questions[currentQuestionIndex];
                                    
                                    // 커스텀 퀴즈인지 확인 (imageTop, imageLeft, imageWidth, imageHeight가 모두 null이면 기본 카테고리)
                                    final isCustomQuiz = question.imageTop != null || 
                                                        question.imageLeft != null || 
                                                        question.imageWidth != null || 
                                                        question.imageHeight != null;
                                    
                                    // 저장된 비율 값 (0.0 ~ 1.0)
                                    // 기본 카테고리인 경우 전체 화면을 채우도록 설정
                                    final topRatio = question.imageTop ?? 0.0;
                                    final leftRatio = question.imageLeft ?? 0.0;
                                    final widthRatio = question.imageWidth ?? (isCustomQuiz ? 0.5 : 1.0);
                                    final heightRatio = question.imageHeight ?? (isCustomQuiz ? 0.324 : 1.0);
                                    
                                    // ===== 미리보기 화면과 동일한 이미지 크기 계산 =====
                                    // 미리보기 화면과 동일한 로직으로 이미지 크기 계산
                                    // 비율을 실제 픽셀 크기로 변환 (미리보기 화면과 동일한 로직)
                                    double imageWidth = containerWidth * widthRatio.clamp(0.2, 1.0);
                                    double imageHeight = containerHeight * heightRatio.clamp(0.2, 1.0);
                                    double imageTop = containerHeight * topRatio.clamp(0.0, 1.0);
                                    double imageLeft = containerWidth * leftRatio.clamp(0.0, 1.0);
                                    
                                    // 미리보기 화면과 동일한 제한 적용 (rightMargin 없이 전체 컨테이너 사용)
                                    // 이미지가 컨테이너를 벗어나지 않도록 보장
                                    if (imageLeft + imageWidth > containerWidth) {
                                      imageWidth = containerWidth - imageLeft;
                                      if (imageWidth < 0) {
                                        imageWidth = 0;
                                        imageLeft = containerWidth;
                                      }
                                    }
                                    if (imageTop + imageHeight > containerHeight) {
                                      imageHeight = containerHeight - imageTop;
                                      if (imageHeight < 0) {
                                        imageHeight = 0;
                                        imageTop = containerHeight;
                                      }
                                    }
                                    
                                    // 최종 검증: 이미지가 화면을 벗어나지 않도록 보장 (미리보기 화면과 동일)
                                    imageLeft = imageLeft.clamp(0.0, containerWidth);
                                    imageTop = imageTop.clamp(0.0, containerHeight);
                                    imageWidth = imageWidth.clamp(0.0, containerWidth - imageLeft);
                                    imageHeight = imageHeight.clamp(0.0, containerHeight - imageTop);
                                    // ===========================================
                                    
                                    return Align(
                                      alignment: const Alignment(0, -0.15), // 위로 올리기 (y: -0.15는 위로 15% 이동)
                                      child: Transform.translate(
                                        // 문제 위젯 위치 조절: offset의 y 값 (음수 값으로 위로 올림)
                                        offset: const Offset(0, -60.0), // 문제 위젯 위치 조절 (15만큼 더 올림)
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 이미지 컨테이너
                                            Container(
                                              key: _imageContainerKey,
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
                                                clipBehavior: Clip.hardEdge, // 이미지가 경계를 벗어나지 않도록 엄격한 클리핑
                                                child: Stack(
                                                  clipBehavior: Clip.hardEdge, // Stack 내부 요소도 클리핑
                                                  children: [
                                                    // 이미지
                                                    // 기본 카테고리인 경우 전체를 채우도록, 커스텀 퀴즈인 경우 Positioned 사용
                                                    isCustomQuiz
                                                        ? Positioned(
                                                            // 미리보기 화면과 동일한 제한 적용 (오른쪽 경계 제한)
                                                            top: imageTop,
                                                            left: imageLeft,
                                                            child: Container(
                                                              width: imageWidth,
                                                              height: imageHeight,
                                                              child: _buildQuestionImage(question),
                                                            ),
                                                          )
                                                        : SizedBox(
                                                            width: containerWidth,
                                                            height: containerHeight,
                                                            child: _buildQuestionImage(question),
                                                          ),
                                                    // 정답 표시 (정답공개 버튼이 나타날 때 미리 렌더링, 정답공개 후 페이드인)
                                                    if (showRevealButton || showAnswer)
                                                      Builder(
                                                        builder: (context) {
                                                          // 텍스트 길이에 따라 동적으로 크기 조절
                                                          final text = question.animalName;
                                                          final textLength = text.length;
                                                          
                                                          // 최대 20글자 제한
                                                          final displayText = textLength > 20 ? text.substring(0, 20) : text;
                                                          
                                                          // 11글자 이상일 때만 10글자씩 2줄로 나누기
                                                          String firstLine = displayText;
                                                          String? secondLine;
                                                          if (displayText.length >= 11) {
                                                            firstLine = displayText.substring(0, 10);
                                                            secondLine = displayText.substring(10);
                                                          }
                                                          
                                                          // 텍스트 너비 추정 (대략적인 계산)
                                                          final estimatedWidth = secondLine != null
                                                              ? _estimateTextWidth(firstLine.length > secondLine.length ? firstLine : secondLine, 42)
                                                              : _estimateTextWidth(firstLine, 42);
                                                          
                                                          // 패딩 포함한 전체 너비
                                                          final padding = 30.0 * 2; // 좌우 패딩
                                                          final totalWidth = estimatedWidth + padding;
                                                          
                                                          // 최대 너비는 이미지 너비의 90% (좌우 5%씩 여백)
                                                          final maxWidth = containerWidth * 0.9;
                                                          final finalWidth = totalWidth.clamp(100.0, maxWidth);
                                                          
                                                          // 중앙 정렬을 위한 left/right 계산
                                                          final horizontalMargin = (containerWidth - finalWidth) / 2;
                                                          
                                                          return Positioned(
                                                            bottom: 0, // 하단에 붙이기
                                                            left: 0, // 왼쪽 끝부터
                                                            right: 0, // 오른쪽 끝까지 (전체 너비)
                                                            child: AnimatedBuilder(
                                                              animation: _buttonAnimation,
                                                              builder: (context, child) {
                                                                // 정답공개 버튼이 나타났을 때는 opacity 0으로 미리 렌더링
                                                                // 정답공개 후에는 페이드인
                                                                final opacity = showAnswer 
                                                                    ? _buttonAnimation.value.clamp(0.0, 1.0)
                                                                    : 0.0;
                                                                
                                                                // 띠 높이는 문제 위젯 하단의 25%로 고정 (폰트 크기와 무관)
                                                                final double ribbonHeight = containerHeight * 0.25;
                                                                
                                                                return Opacity(
                                                                  opacity: opacity,
                                                                    child: Container(
                                                                    width: double.infinity, // 전체 너비
                                                                    height: ribbonHeight, // 고정 높이 (문제 위젯의 25%)
                                                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), // 좌우 패딩 증가, 상하 패딩 추가
                                                                    alignment: Alignment.center, // 세로 중앙 정렬
                                                                    constraints: BoxConstraints(
                                                                      minHeight: ribbonHeight, // 최소 높이 보장
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.black.withOpacity(0.75), // 어두운 배경
                                                                      borderRadius: const BorderRadius.only(
                                                                        bottomLeft: Radius.circular(20), // 이미지 컨테이너와 동일한 둥근 모서리
                                                                        bottomRight: Radius.circular(20),
                                                                      ),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: Colors.black.withOpacity(0.3),
                                                                          blurRadius: 10,
                                                                          offset: const Offset(0, -2),
                                                                          spreadRadius: 0,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Center(
                                                                      child: secondLine != null
                                                                          ? Column(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              crossAxisAlignment: CrossAxisAlignment.center,
                                                                              children: [
                                                                                Flexible(
                                                                                  child: FittedBox(
                                                                                    fit: BoxFit.scaleDown,
                                                                                    child: Text(
                                                                                      firstLine,
                                                                                      textAlign: TextAlign.center,
                                                                                      maxLines: 1,
                                                                                      overflow: TextOverflow.ellipsis,
                                                                                      style: const TextStyle(
                                                                                        fontSize: 80,
                                                                                        fontWeight: FontWeight.w900,
                                                                                        color: Colors.white,
                                                                                        letterSpacing: 3.0,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                Flexible(
                                                                                  child: FittedBox(
                                                                                    fit: BoxFit.scaleDown,
                                                                                    child: Text(
                                                                                      secondLine,
                                                                                      textAlign: TextAlign.center,
                                                                                      maxLines: 1,
                                                                                      overflow: TextOverflow.ellipsis,
                                                                                      style: const TextStyle(
                                                                                        fontSize: 80,
                                                                                        fontWeight: FontWeight.w900,
                                                                                        color: Colors.white,
                                                                                        letterSpacing: 3.0,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            )
                                                                          : FittedBox(
                                                                              fit: BoxFit.scaleDown,
                                                                              child: Text(
                                                                                firstLine,
                                                                                textAlign: TextAlign.center,
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                                style: const TextStyle(
                                                                                  fontSize: 80,
                                                                                  fontWeight: FontWeight.w900,
                                                                                  color: Colors.white,
                                                                                  letterSpacing: 3.0,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
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
                                      ),
                                    );
                                  }
                                  
                                  // 이미지가 없는 경우
                                  return Transform.translate(
                                    // 문제 위젯 위치 조절: offset의 y 값 (음수 값으로 위로 올림)
                                    offset: const Offset(0, -60.0), // 문제 위젯 위치 조절 (15만큼 더 올림)
                                    child: Stack(
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
                                                Icons.image,
                                                size: 100,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
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
        ),
            
            // 카운트다운/정답공개/OX 버튼 영역 (이미지 컨테이너 아래 끝선에 맞춤)
            if (_imageContainerWidth != null && _imageContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? imageBox = _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (imageBox != null) {
                    final position = imageBox.localToGlobal(Offset.zero);
                    final size = imageBox.size;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final centerWidth = screenWidth * 0.60;
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset, // 이미지 컨테이너 아래 끝선 + offset
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
            
            // 왼쪽 하단 메인메뉴 버튼 (이미지 컨테이너 왼쪽 끝선에 맞춤)
            if (_imageContainerWidth != null && _imageContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? imageBox = _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (imageBox != null) {
                    final position = imageBox.localToGlobal(Offset.zero);
                    final size = imageBox.size;
                    // 이미지 컨테이너의 왼쪽 끝선에 맞춤
                    final imageLeft = position.dx;
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset,
                      left: imageLeft,
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
            
            // 오른쪽 하단 진행도 표시 (이미지 컨테이너 오른쪽 끝선에 맞춤)
            if (_imageContainerWidth != null && _imageContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? imageBox = _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (imageBox != null) {
                    final position = imageBox.localToGlobal(Offset.zero);
                    final size = imageBox.size;
                    // 이미지 컨테이너의 오른쪽 끝선에 맞춤
                    final imageRight = position.dx + size.width;
                    final screenWidth = MediaQuery.of(context).size.width;
                    // 진행바 위젯 크기
                    const progressWidth = 100.0;  // 가로 길이 조절 (기본: 200)
                    const progressHeight = 100.0; // 세로 길이 조절 (기본: 60)
                    // 진행바 위젯 위치 조절: top 값 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    const progressTopOffset = -30.0; // 위치 조절 (기본: -20, 위로 올리려면 더 작은 값)
                    // 모든 위젯을 위로 올리는 공통 offset
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + progressTopOffset + globalTopOffset,
                      left: imageRight - progressWidth, // 진행바의 오른쪽 끝이 이미지 컨테이너 오른쪽 끝선에 맞춤
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
            // 왼쪽: 이미지 영역 (70%)
            Expanded(
              flex: 7,
              child: _buildLandscapeImageArea(context, screenWidth * 0.70, screenHeight),
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

  Widget _buildLandscapeImageArea(BuildContext context, double width, double height) {
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
                      animation: _imageAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _imageAnimation.value.clamp(0.0, 1.0),
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
                              
                              if (_imageContainerWidth != finalContainerWidth || 
                                  _imageContainerHeight != containerHeight) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setState(() {
                                    _imageContainerWidth = finalContainerWidth;
                                    _imageContainerHeight = containerHeight;
                                  });
                                });
                              }
                              
                              if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
                                final question = _questions[currentQuestionIndex];
                                final isCustomQuiz = question.imageTop != null || 
                                                    question.imageLeft != null || 
                                                    question.imageWidth != null || 
                                                    question.imageHeight != null;
                                
                                final topRatio = question.imageTop ?? 0.0;
                                final leftRatio = question.imageLeft ?? 0.0;
                                final widthRatio = question.imageWidth ?? (isCustomQuiz ? 0.5 : 1.0);
                                final heightRatio = question.imageHeight ?? (isCustomQuiz ? 0.324 : 1.0);
                                
                                double imageWidth = finalContainerWidth * widthRatio.clamp(0.2, 1.0);
                                double imageHeight = containerHeight * heightRatio.clamp(0.2, 1.0);
                                double imageTop = containerHeight * topRatio.clamp(0.0, 1.0);
                                double imageLeft = finalContainerWidth * leftRatio.clamp(0.0, 1.0);
                                
                                if (imageLeft + imageWidth > finalContainerWidth) {
                                  imageWidth = finalContainerWidth - imageLeft;
                                  if (imageWidth < 0) {
                                    imageWidth = 0;
                                    imageLeft = finalContainerWidth;
                                  }
                                }
                                if (imageTop + imageHeight > containerHeight) {
                                  imageHeight = containerHeight - imageTop;
                                  if (imageHeight < 0) {
                                    imageHeight = 0;
                                    imageTop = containerHeight;
                                  }
                                }
                                
                                imageLeft = imageLeft.clamp(0.0, finalContainerWidth);
                                imageTop = imageTop.clamp(0.0, containerHeight);
                                imageWidth = imageWidth.clamp(0.0, finalContainerWidth - imageLeft);
                                imageHeight = imageHeight.clamp(0.0, containerHeight - imageTop);
                                
                                return Align(
                                  alignment: Alignment.center, // 세로 중앙 정렬
                                  child: Transform.translate(
                                    offset: const Offset(275, 0), // X축으로 오른쪽으로 이동 (양수 = 오른쪽, 음수 = 왼쪽)
                                    child: Container(
                                      key: _imageContainerKey,
                                      width: finalContainerWidth,
                                      height: containerHeight,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // 상하 마진은 Align의 center로 처리
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
                                      clipBehavior: Clip.hardEdge,
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          isCustomQuiz
                                              ? Positioned(
                                                  top: imageTop,
                                                  left: imageLeft,
                                                  child: Container(
                                                    width: imageWidth,
                                                    height: imageHeight,
                                                    child: _buildQuestionImage(question),
                                                  ),
                                                )
                                              : SizedBox(
                                                  width: finalContainerWidth,
                                                  height: containerHeight,
                                                  child: _buildQuestionImage(question),
                                                ),
                                          if (showRevealButton || showAnswer)
                                            _buildAnswerOverlay(question, finalContainerWidth, containerHeight),
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

  Widget _buildAnswerOverlay(AnimalQuestion question, double containerWidth, double containerHeight) {
    final text = question.animalName;
    final textLength = text.length;
    final displayText = textLength > 20 ? text.substring(0, 20) : text;
    
    String firstLine = displayText;
    String? secondLine;
    if (displayText.length >= 11) {
      firstLine = displayText.substring(0, 10);
      secondLine = displayText.substring(10);
    }
    
    final double ribbonHeight = containerHeight * 0.25;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _buttonAnimation,
        builder: (context, child) {
          final opacity = showAnswer 
              ? _buttonAnimation.value.clamp(0.0, 1.0)
              : 0.0;
          
          return Opacity(
            opacity: opacity,
            child: Container(
              width: double.infinity,
              height: ribbonHeight,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              alignment: Alignment.center,
              constraints: BoxConstraints(
                minHeight: ribbonHeight,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: secondLine != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                firstLine,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                secondLine,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          firstLine,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 3.0,
                          ),
                        ),
                      ),
              ),
            ),
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
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동 (양수 = 오른쪽, 음수 = 왼쪽)
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RepaintBoundary(
                    child: Image.asset(
                      'assets/images/Button_Home.png',
                      width: 70, // 55 -> 70 (약 27% 증가)
                      height: 70, // 55 -> 70
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
                  width: 130, // 100 -> 130 (30% 증가)
                  height: 130, // 100 -> 130
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Widget_Progress.png',
                        width: 130, // 100 -> 130
                        height: 130, // 100 -> 130
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      Text(
                        '${currentQuestionIndex + 1} / ${widget.questionCount}',
                        style: const TextStyle(
                          fontSize: 26, // 20 -> 26 (비율 유지)
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
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동 (양수 = 오른쪽, 음수 = 왼쪽)
            child: SizedBox(
              height: 156, // 120 -> 156 (30% 증가)
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
                            width: 156, // 120 -> 156 (30% 증가)
                            height: 156, // 120 -> 156
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/Widget_Countdown.png',
                                  width: 156, // 120 -> 156
                                  height: 156, // 120 -> 156
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                ),
                                Text(
                                  countdown > 0 ? countdown.toString() : '',
                                  style: const TextStyle(
                                    fontSize: 78, // 60 -> 78 (30% 증가)
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
                              width: 359, // 276 -> 359 (30% 증가)
                              height: 107.6, // 82.8 -> 107.6 (30% 증가)
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
                                  width: 104, // 80 -> 104 (30% 증가)
                                  height: 104, // 80 -> 104
                                  child: Opacity(
                                    opacity: selectedAnswer == true ? 1.0 : 0.7,
                                    child: RepaintBoundary(
                                      child: Image.asset(
                                        'assets/images/Button_O.png',
                                        width: 104, // 80 -> 104
                                        height: 104, // 80 -> 104
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
                              const SizedBox(width: 39), // 30 -> 39 (30% 증가)
                              GestureDetector(
                                onTap: () => _selectAnswer(false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 104, // 80 -> 104 (30% 증가)
                                  height: 104, // 80 -> 104
                                  child: Opacity(
                                    opacity: selectedAnswer == false ? 1.0 : 0.7,
                                    child: RepaintBoundary(
                                      child: Image.asset(
                                        'assets/images/Button_X.png',
                                        width: 104, // 80 -> 104
                                        height: 104, // 80 -> 104
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
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동 (양수 = 오른쪽, 음수 = 왼쪽)
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
                              width: 429, // 330 -> 429 (30% 증가)
                              height: 107.25, // 82.5 -> 107.25 (30% 증가)
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

