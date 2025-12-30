import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'result_screen.dart';
import '../models/custom_quiz.dart';
import '../utils/sound_manager.dart';

// 동물 울음소리 문제 데이터 모델
class VoiceQuestion {
  final String soundPath; // 음성 파일 경로
  final String animalName; // 동물 이름
  final bool correctAnswer; // 정답 (true = O, false = X)

  VoiceQuestion({
    required this.soundPath,
    required this.animalName,
    required this.correctAnswer,
  });
}

class VoiceQuizGameScreen extends StatefulWidget {
  final String category;
  final int questionCount;
  final CustomQuiz? customQuiz; // 커스텀 퀴즈

  const VoiceQuizGameScreen({
    super.key,
    required this.category,
    required this.questionCount,
    this.customQuiz,
  });

  @override
  State<VoiceQuizGameScreen> createState() => _VoiceQuizGameScreenState();
}

class _VoiceQuizGameScreenState extends State<VoiceQuizGameScreen>
    with TickerProviderStateMixin {
  List<VoiceQuestion> _questions = [];
  int currentQuestionIndex = 0;
  bool showRevealButton = true; // 정답공개 버튼 표시 여부 (처음부터 표시)
  bool showAnswer = false; // 정답 표시 여부
  bool? selectedAnswer; // true = O, false = X, null = 선택 안함
  bool showNextButton = false;
  bool showButtons = false; // O/X 버튼 표시 여부 (정답공개 후 정답공개 버튼 자리에 표시)
  bool _isUserAction = false; // 사용자가 버튼을 직접 누른 경우 플래그
  int correctAnswers = 0;
  List<bool> _questionAnswered = []; // 각 문제의 정답 체크 여부
  double? _videoContainerWidth; // 비디오 컨테이너 너비 저장
  double? _videoContainerHeight; // 비디오 컨테이너 높이 저장
  final GlobalKey _videoContainerKey = GlobalKey(); // 비디오 컨테이너 위치 추적용
  final GlobalKey _buttonAreaKey = GlobalKey(); // 버튼 영역 위치 추적용
  bool _isLandscapeMode = false; // 화면 모드 (false = 세로모드, true = 가로모드)
  
  // 비디오 플레이어
  VideoPlayerController? _videoController;
  // 오디오 플레이어
  just_audio.AudioPlayer? _audioPlayer;
  bool _isPlaying = false; // 재생 중 여부
  Duration? _audioDuration; // 오디오 총 재생 시간
  Duration _currentPosition = Duration.zero; // 현재 재생 위치
  StreamSubscription<Duration>? _positionSubscription; // 위치 스트림 구독
  StreamSubscription<Duration?>? _durationSubscription; // 총 시간 스트림 구독
  
  late AnimationController _videoController_anim;
  late AnimationController _buttonController;
  late Animation<double> _videoAnimation;
  late Animation<double> _buttonAnimation;

  // 동물 이름 매핑
  final Map<String, String> _animalNames = {
    'dog': '개',
    'frog': '개구리',
    'cat': '고양이',
    'chicken': '닭',
    'pig': '돼지',
    'lion': '사자',
    'bird': '새',
    'cow': '소',
    'duck': '오리',
    'tiger': '호랑이',
  };

  @override
  void initState() {
    super.initState();
    _loadScreenMode();
    
    _videoController_anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _videoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _videoController_anim,
        curve: Curves.easeIn,
      ),
    );
    
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeOut,
      ),
    );
    
    _loadQuestions();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _videoController_anim.dispose();
    _buttonController.dispose();
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
  
  // 시간 포맷팅 (초를 mm:ss 형식으로)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _loadQuestions() {
    if (widget.customQuiz != null) {
      // 커스텀 퀴즈 로드
      _questions = widget.customQuiz!.questions.map((q) {
        return VoiceQuestion(
          soundPath: q.audioPath ?? '',
          animalName: q.answer ?? '',
          correctAnswer: true, // 커스텀 퀴즈는 항상 정답
        );
      }).toList();
      
      // 선택한 문제 수만큼만 가져오기
      _questions = _questions.take(widget.questionCount).toList();
    } else if (widget.category == '동물소리') {
      // 기본 동물 울음소리 퀴즈
      final allAnimals = [
        VoiceQuestion(soundPath: 'assets/sounds/animals/dog.m4a', animalName: '개', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/frog.m4a', animalName: '개구리', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/cat.m4a', animalName: '고양이', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/chicken.m4a', animalName: '닭', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/pig.m4a', animalName: '돼지', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/lion.m4a', animalName: '사자', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/bird.m4a', animalName: '새', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/cow.m4a', animalName: '소', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/duck.m4a', animalName: '오리', correctAnswer: true),
        VoiceQuestion(soundPath: 'assets/sounds/animals/tiger.m4a', animalName: '호랑이', correctAnswer: true),
      ];
      
      // 랜덤으로 섞기
      allAnimals.shuffle(Random());
      
      // 선택한 문제 수만큼만 가져오기
      _questions = allAnimals.take(widget.questionCount).toList();
    } else {
      // 알 수 없는 카테고리
      _questions = [];
    }
    
    // 정답 체크 여부 초기화
    _questionAnswered = List.filled(_questions.length, false);
    
    _startQuestion();
  }

  Future<void> _loadScreenMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLandscapeMode = prefs.getBool('isLandscapeMode') ?? false; // 기본값: 세로모드
    });
  }

  void _startQuestion() {
    setState(() {
      showRevealButton = true; // 처음부터 정답공개 버튼 표시
      showAnswer = false;
      showNextButton = false;
      selectedAnswer = null;
      showButtons = false; // O/X 버튼 숨김
      _isPlaying = false;
      _audioDuration = null;
      _currentPosition = Duration.zero;
    });
    
    // 비디오 컨트롤러 초기화
    _initializeVideo();
    
    // 오디오 플레이어 초기화
    _initializeAudio();
    
    // 비디오 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _videoController_anim.forward(from: 0.0);
        // 정답공개 버튼 애니메이션 시작
        _buttonController.forward(from: 0.0);
      }
    });
  }

  Future<void> _initializeVideo() async {
    await _videoController?.dispose();
    
    _videoController = VideoPlayerController.asset('assets/videos/soundwave.mp4');
    
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.pause(); // 초기에는 일시정지
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('비디오 초기화 오류: $e');
    }
  }

  Future<void> _initializeAudio() async {
    await _audioPlayer?.dispose();
    
    if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
      final question = _questions[currentQuestionIndex];
      _audioPlayer = just_audio.AudioPlayer();
      
      try {
        // 오디오 파일 경로 확인 및 로드
        String audioPath = question.soundPath;
        
        // Base64 데이터 URI인 경우 처리
        if (audioPath.startsWith('data:')) {
          // Flutter Web에서는 data URI를 직접 사용
          if (kIsWeb) {
            await _audioPlayer!.setUrl(audioPath);
          } else {
            // 모바일에서는 Base64 디코딩 후 LockCachingAudioSource 사용
            try {
              // data:audio/m4a;base64, 또는 data:audio/mpeg;base64, 형태 파싱
              final parts = audioPath.split(',');
              if (parts.length < 2) {
                throw Exception('잘못된 Base64 데이터 URI 형식');
              }
              final base64String = parts[1];
              final bytes = base64Decode(base64String);
              
              // MIME 타입 추출
              String mimeType = 'audio/mpeg';
              if (parts[0].contains('m4a')) {
                mimeType = 'audio/mp4';
              } else if (parts[0].contains('wav')) {
                mimeType = 'audio/wav';
              } else if (parts[0].contains('ogg')) {
                mimeType = 'audio/ogg';
              }
              
              // MemoryAudioSource를 사용하여 재생
              await _audioPlayer!.setAudioSource(
                just_audio.LockCachingAudioSource(
                  Uri.dataFromBytes(
                    bytes,
                    mimeType: mimeType,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Base64 오디오 디코딩 오류: $e');
              rethrow;
            }
          }
        } else if (audioPath.startsWith('assets/')) {
          // assets 경로
          audioPath = audioPath.substring(7); // "assets/" 제거
          await _audioPlayer!.setAsset(audioPath);
        } else {
          // 일반 URL
          await _audioPlayer!.setUrl(audioPath);
        }
        
        // 총 재생 시간 가져오기
        _durationSubscription?.cancel();
        _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
          if (mounted && duration != null) {
            setState(() {
              _audioDuration = duration;
            });
          }
        });
        
        // 현재 재생 위치 업데이트
        _positionSubscription?.cancel();
        _positionSubscription = _audioPlayer!.positionStream.listen((position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
          }
        });
        
        // 오디오 재생 완료 리스너
        _audioPlayer!.playerStateStream.listen((state) {
          if (state.processingState == just_audio.ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _currentPosition = Duration.zero;
                _videoController?.pause();
                _videoController?.seekTo(Duration.zero); // 비디오를 처음으로 되돌림
                // 사용자가 버튼을 직접 누른 경우가 아니고, 정답이 공개되지 않은 경우에만 애니메이션 실행
                if (!_isUserAction && !showAnswer && !showRevealButton) {
                  showRevealButton = true;
                  _buttonController.forward(from: 0.0);
                }
                _isUserAction = false; // 플래그 리셋
              });
            }
          }
        });
        
        // 오디오 재생 중 상태 리스너
        _audioPlayer!.playingStream.listen((playing) {
          if (mounted) {
            setState(() {
              _isPlaying = playing;
              if (!playing && _videoController != null && _videoController!.value.isPlaying) {
                _videoController!.pause();
                _videoController!.seekTo(Duration.zero); // 비디오를 처음으로 되돌림
                // 사용자가 버튼을 직접 누른 경우가 아니고, 정답이 공개되지 않은 경우에만 애니메이션 실행
                if (!_isUserAction && !showAnswer && !showRevealButton) {
                  showRevealButton = true;
                  _buttonController.forward(from: 0.0);
                }
                _isUserAction = false; // 플래그 리셋
              }
            });
          }
        });
      } catch (e) {
        debugPrint('오디오 초기화 오류: $e');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            // 사용자가 버튼을 직접 누른 경우가 아니고, 정답이 공개되지 않은 경우에만 애니메이션 실행
            if (!_isUserAction && !showAnswer && !showRevealButton) {
              showRevealButton = true;
              _buttonController.forward(from: 0.0);
            }
            _isUserAction = false; // 플래그 리셋
          });
        }
      }
    }
  }

  Future<void> _playSound() async {
    _isUserAction = true; // 사용자가 직접 버튼을 누른 경우
    if (_audioPlayer == null) {
      debugPrint('오디오 플레이어가 초기화되지 않았습니다.');
      // 오디오 플레이어 재초기화 시도
      await _initializeAudio();
      if (_audioPlayer == null) {
        debugPrint('오디오 플레이어 초기화 실패');
        return;
      }
    }
    
    if (_videoController == null || !_videoController!.value.isInitialized) {
      debugPrint('비디오 컨트롤러가 초기화되지 않았습니다.');
      // 비디오 컨트롤러 재초기화 시도
      await _initializeVideo();
      if (_videoController == null || !_videoController!.value.isInitialized) {
        debugPrint('비디오 컨트롤러 초기화 실패');
        return;
      }
    }
    
    // 재생 중이면 일시정지, 일시정지 중이면 재생
    if (_isPlaying) {
      // 일시정지
      await _pauseSound();
    } else {
      // 재생
      try {
        // 오디오 플레이어 상태 확인
        final playerState = _audioPlayer!.playerState;
        final currentPos = _audioPlayer!.position;
        final duration = _audioPlayer!.duration;
        
        // 재생 완료 상태인지 확인
        final isCompleted = playerState.processingState == just_audio.ProcessingState.completed ||
                           (duration != null && currentPos.inMilliseconds >= duration.inMilliseconds - 100);
        
        // 재생 완료 상태이거나 처음 재생하는 경우 처음부터 재생
        if (isCompleted || currentPos.inMilliseconds < 100) {
          // 먼저 일시정지하여 상태를 안정화
          await _audioPlayer!.pause();
          await _videoController!.pause();
          
          // 처음으로 되돌림
          await _audioPlayer!.seek(Duration.zero);
          await _videoController!.seekTo(Duration.zero);
          
          // 잠시 대기하여 상태가 안정화되도록 함
          await Future.delayed(const Duration(milliseconds: 50));
          
          if (mounted) {
            setState(() {
              _currentPosition = Duration.zero;
            });
          }
        }
        
        // 비디오와 오디오를 동시에 재생 시작
        await Future.wait([
          _videoController!.play(),
          _audioPlayer!.play(),
        ]);
        
        // Base64 데이터 URI인 경우 로그에 전체 데이터를 출력하지 않음
        final soundPath = _questions[currentQuestionIndex].soundPath;
        if (soundPath.startsWith('data:')) {
          debugPrint('오디오 및 비디오 재생 시작: Base64 데이터 URI (길이: ${soundPath.length})');
        } else {
          debugPrint('오디오 및 비디오 재생 시작: $soundPath');
        }
        
        // 상태 업데이트
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      } catch (e) {
        debugPrint('재생 오류: $e');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _videoController?.pause();
            _videoController?.seekTo(Duration.zero);
          });
        }
      }
    }
  }

  Future<void> _pauseSound() async {
    _isUserAction = true; // 사용자가 직접 버튼을 누른 경우
    try {
      await _audioPlayer?.pause();
      await _videoController?.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('일시정지 오류: $e');
    }
  }

  Future<void> _stopSound() async {
    _isUserAction = true; // 사용자가 직접 버튼을 누른 경우
    try {
      await _audioPlayer?.pause();
      await _videoController?.pause();
      await _audioPlayer?.seek(Duration.zero);
      await _videoController?.seekTo(Duration.zero);
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('정지 오류: $e');
    }
  }

  void _revealAnswer() {
    setState(() {
      showRevealButton = false; // 정답공개 버튼 숨김
      showAnswer = true;
      showButtons = true; // O/X 버튼 표시 (정답공개 버튼 자리에)
    });
    _buttonController.forward(from: 0.0);
    SoundManager().playAnswer(); // 정답 공개 사운드 재생
  }

  void _selectAnswer(bool answer) {
    final currentQuestion = _questions[currentQuestionIndex];
    final isCorrect = answer == currentQuestion.correctAnswer;
    
    setState(() {
      selectedAnswer = answer;
      showNextButton = true;
      
      if (isCorrect && !_questionAnswered[currentQuestionIndex]) {
        correctAnswers++;
        _questionAnswered[currentQuestionIndex] = true;
      } else if (!isCorrect && _questionAnswered[currentQuestionIndex]) {
        correctAnswers--;
        _questionAnswered[currentQuestionIndex] = false;
      }
    });
  }

  void _nextQuestion() {
    // 현재 재생 중인 오디오/비디오 정지
    _audioPlayer?.stop();
    _videoController?.pause();
    
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
                width: centerWidth,
                child: Column(
                  children: [
                    // 비디오 표시 영역 (상단부터 크게, 가운데에 길게)
                    Expanded(
                      child: ClipRect(
                        clipBehavior: Clip.none,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _videoAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _videoAnimation.value.clamp(0.0, 1.0),
                                  child: LayoutBuilder(
                                    builder: (context, innerConstraints) {
                                      const double referenceWidth = 1920.0;
                                      const double referenceHeight = 1080.0;
                                      const double referenceAspectRatio = referenceWidth / referenceHeight;
                                      
                                      final screenWidth = MediaQuery.of(context).size.width;
                                      final centerWidth = screenWidth * 0.60;
                                      final containerWidth = centerWidth.clamp(400.0, 800.0);
                                      final containerHeight = containerWidth / referenceAspectRatio * 1.25;
                                      
                                      if (_videoContainerWidth != containerWidth || 
                                          _videoContainerHeight != containerHeight) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          setState(() {
                                            _videoContainerWidth = containerWidth;
                                            _videoContainerHeight = containerHeight;
                                          });
                                        });
                                      }
                                      
                                      return Align(
                                        alignment: const Alignment(0, -0.15), // 전체 문제 위젯 위치 (이미지 퀴즈와 동일)
                                        child: Transform.translate(
                                          offset: const Offset(0, -60.0), // 전체 문제 위젯 추가 위치 조절
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // 비디오 컨테이너 (문제 위젯 안에서 세로 위치 조절 가능)
                                              Container(
                                                key: _videoContainerKey,
                                                width: containerWidth,
                                                height: containerHeight,
                                                margin: const EdgeInsets.only(top: 0, bottom: 20),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: const Color(0xFFF57C00),
                                                    width: 4.0,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(20),
                                                  clipBehavior: Clip.hardEdge,
                                                  child: Stack(
                                                    clipBehavior: Clip.hardEdge,
                                                    children: [
                                                      // 웨이브사운드 동영상 세로 위치 조절: Positioned의 top 값 변경 (픽셀 단위, 음수 = 위로, 양수 = 아래로)
                                                      Positioned(
                                                        top: 0.0, // 웨이브사운드 동영상 세로 위치 조절 (픽셀 단위)
                                                        left: 0,
                                                        right: 0,
                                                        bottom: 0,
                                                        child: _videoController != null && 
                                                                _videoController!.value.isInitialized
                                                            ? AspectRatio(
                                                                aspectRatio: _videoController!.value.aspectRatio,
                                                                child: VideoPlayer(_videoController!),
                                                              )
                                                            : const Center(
                                                                child: CircularProgressIndicator(),
                                                              ),
                                                      ),
                                                      // 정답 표시 (정답공개 버튼이 나타날 때 미리 렌더링, 정답공개 후 페이드인)
                                                      if (showRevealButton || showAnswer)
                                                        Builder(
                                                          builder: (context) {
                                                            final question = _questions[currentQuestionIndex];
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
                                                                            : Flexible(
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
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      // 재생 진행바 (사운드웨이브 동영상 중간 위치에 표시, 최상위 레이어)
                                                      // 정답이 공개되면 진행바 숨김
                                                      if (_audioDuration != null && _audioDuration!.inSeconds > 0 && !showAnswer)
                                                        Positioned(
                                                          // 중간 위치에 배치 (containerHeight의 약 50% 위치)
                                                          top: containerHeight * 0.9 - 2, // 진행바 높이(4)의 절반을 빼서 중앙 정렬
                                                          left: containerWidth * 0.1, // 왼쪽에서 10% 위치
                                                          right: containerWidth * 0.1, // 오른쪽에서 10% 위치 (즉, 전체 너비의 80% 길이)
                                                          child: Container(
                                                            height: 4,
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(2),
                                                              child: LinearProgressIndicator(
                                                                value: _currentPosition.inMilliseconds / _audioDuration!.inMilliseconds,
                                                                minHeight: 4,
                                                                backgroundColor: Colors.white.withOpacity(0.3),
                                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
            // 왼쪽 하단 홈 버튼 표시 (비디오 컨테이너 왼쪽 끝선에 맞춤)
            if (_videoContainerWidth != null && _videoContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? videoBox = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (videoBox != null) {
                    final position = videoBox.localToGlobal(Offset.zero);
                    final size = videoBox.size;
                    final imageLeft = position.dx;
                    const globalTopOffset = 0.0;
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset,
                      left: imageLeft,
                      child: GestureDetector(
                        onTap: () {
                          SoundManager().playClick();
                          Navigator.pop(context);
                        },
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
            
            // 재생/일시정지/정지 버튼 (홈 버튼과 진행바 사이)
            if (_videoContainerWidth != null && _videoContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? videoBox = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (videoBox != null) {
                    final position = videoBox.localToGlobal(Offset.zero);
                    final size = videoBox.size;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final imageLeft = position.dx;
                    final imageRight = position.dx + size.width;
                    const buttonSize = 50.0;
                    const buttonSpacing = 15.0;
                    const globalTopOffset = 0.0;
                    final totalButtonsWidth = (buttonSize * 2) + (buttonSpacing * 1); // 버튼 2개 (재생/일시정지 통합 + 정지)
                    final centerX = (imageLeft + imageRight) / 2;
                    final buttonsLeft = centerX - (totalButtonsWidth / 2);
                    
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset,
                      left: buttonsLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 재생/일시정지 버튼 (상태에 따라 아이콘 변경)
                          GestureDetector(
                            onTap: () {
                              _playSound();
                            },
                            child: Container(
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57C00),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF57C00).withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          SizedBox(width: buttonSpacing),
                          // 정지 버튼
                          GestureDetector(
                            onTap: () {
                              _stopSound();
                            },
                            child: Container(
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57C00),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF57C00).withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            
            // 오른쪽 하단 진행도 표시 (비디오 컨테이너 오른쪽 끝선에 맞춤)
            if (_videoContainerWidth != null && _videoContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? videoBox = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (videoBox != null) {
                    final position = videoBox.localToGlobal(Offset.zero);
                    final size = videoBox.size;
                    final imageRight = position.dx + size.width;
                    const progressWidth = 100.0;
                    const progressHeight = 100.0;
                    const progressTopOffset = -30.0;
                    const globalTopOffset = 0.0;
                    return Positioned(
                      top: position.dy + size.height + progressTopOffset + globalTopOffset,
                      left: imageRight - progressWidth,
                      child: SizedBox(
                        width: progressWidth,
                        height: progressHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/Widget_Progress.png',
                              width: progressWidth,
                              height: progressHeight,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                            ),
                            Text(
                              '${currentQuestionIndex + 1} / ${_questions.length}',
                              style: const TextStyle(
                                fontSize: 20,
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
            
            // 정답공개/OX 버튼 영역
            if (_videoContainerWidth != null && _videoContainerHeight != null)
              Builder(
                builder: (context) {
                  final RenderBox? videoBox = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (videoBox != null) {
                    final position = videoBox.localToGlobal(Offset.zero);
                    final size = videoBox.size;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final centerWidth = screenWidth * 0.60;
                    const buttonAreaTopOffset = 80.0; // 재생/일시정지/정지 버튼 영역 높이 (버튼 2개로 변경)
                    const globalTopOffset = 0.0; // 전체 위젯 위치 조절 (음수 값으로 위로 올림, 양수 값으로 아래로 내림)
                    return Positioned(
                      top: position.dy + size.height + globalTopOffset + buttonAreaTopOffset, // 재생 버튼들 아래로
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: centerWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 정답공개 버튼
                              if (showRevealButton && !showAnswer)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
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
                              // O, X 버튼 (정답공개 버튼 자리에 표시)
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
                              // 다음 버튼
                              if (showNextButton)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: GestureDetector(
                                    onTap: () {
                                      SoundManager().playClick();
                                      _nextQuestion();
                                    },
                                    child: Image.asset(
                                      'assets/images/Button_Next.png',
                                      width: 276,
                                      height: 82.8,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      isAntiAlias: true,
                                    ),
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
            // 왼쪽: 비디오 영역 (70%)
            Expanded(
              flex: 7,
              child: _buildLandscapeVideoArea(context, screenWidth * 0.70, screenHeight),
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

  Widget _buildLandscapeVideoArea(BuildContext context, double width, double height) {
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
                      animation: _videoAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _videoAnimation.value.clamp(0.0, 1.0),
                          child: LayoutBuilder(
                            builder: (context, innerConstraints) {
                              const double referenceWidth = 1920.0;
                              const double referenceHeight = 1080.0;
                              const double referenceAspectRatio = referenceWidth / referenceHeight;
                              
                              // 세로 길이를 화면 전체 높이의 90%로 설정하고, 비율에 맞게 가로 길이 계산
                              final containerHeight = height * 0.90; // 화면의 세로 길이의 90% (10% 줄임)
                              // 세로모드와 동일한 비율 유지: containerHeight = containerWidth / referenceAspectRatio * 1.25
                              // 따라서: containerWidth = containerHeight / 1.25 * referenceAspectRatio
                              final containerWidth = (containerHeight / 1.25) * referenceAspectRatio;
                              // 가로 길이가 사용 가능한 너비를 넘지 않도록 제한
                              final maxWidth = width * 0.95; // 좌우 여백 고려
                              final finalContainerWidth = containerWidth.clamp(400.0, maxWidth);
                              
                              if (_videoContainerWidth != finalContainerWidth || 
                                  _videoContainerHeight != containerHeight) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setState(() {
                                    _videoContainerWidth = finalContainerWidth;
                                    _videoContainerHeight = containerHeight;
                                  });
                                });
                              }
                              
                              return Align(
                                alignment: Alignment.center, // 세로 중앙 정렬
                                child: Transform.translate(
                                  offset: const Offset(275, 0), // X축으로 오른쪽으로 이동
                                  child: Container(
                                    key: _videoContainerKey,
                                    width: finalContainerWidth,
                                    height: containerHeight,
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFF57C00),
                                        width: 4.0,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      clipBehavior: Clip.hardEdge,
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          // 웨이브사운드 동영상
                                          Positioned(
                                            top: 0.0,
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: _videoController != null && 
                                                    _videoController!.value.isInitialized
                                                ? AspectRatio(
                                                    aspectRatio: _videoController!.value.aspectRatio,
                                                    child: VideoPlayer(_videoController!),
                                                  )
                                                : const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                          ),
                                          // 정답 표시
                                          if (showRevealButton || showAnswer)
                                            Builder(
                                              builder: (context) {
                                                if (_questions.isNotEmpty && currentQuestionIndex < _questions.length) {
                                                  final question = _questions[currentQuestionIndex];
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
                                                                  : Flexible(
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
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          // 재생 진행바 (정답이 공개되면 숨김)
                                          if (_audioDuration != null && _audioDuration!.inSeconds > 0 && !showAnswer)
                                            Positioned(
                                              top: containerHeight * 0.9 - 2,
                                              left: finalContainerWidth * 0.1,
                                              right: finalContainerWidth * 0.1,
                                              child: Container(
                                                height: 4,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(2),
                                                  child: LinearProgressIndicator(
                                                    value: _currentPosition.inMilliseconds / _audioDuration!.inMilliseconds,
                                                    minHeight: 4,
                                                    backgroundColor: Colors.white.withOpacity(0.3),
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                  onTap: () {
                    SoundManager().playClick();
                    Navigator.pop(context);
                  },
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
                        '${currentQuestionIndex + 1} / ${_questions.length}',
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
          // 재생/일시정지/정지 버튼
          Transform.translate(
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 재생/일시정지 버튼
                GestureDetector(
                  onTap: () {
                    _playSound();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF57C00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF57C00).withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // 정지 버튼
                GestureDetector(
                  onTap: () {
                    _stopSound();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF57C00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF57C00).withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 카운트다운/정답공개/OX 버튼
          Transform.translate(
            offset: const Offset(100, 0), // X축으로 오른쪽으로 이동
            child: SizedBox(
              height: 156,
              child: Stack(
                alignment: Alignment.center,
                children: [
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
          // 다음 문제 버튼
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
                            onTap: () {
                              SoundManager().playClick();
                              _nextQuestion();
                            },
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

