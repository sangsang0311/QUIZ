import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/fruit.dart';
import '../services/fruit_service.dart';
import 'result_screen.dart';

class FruitQuizScreen extends StatefulWidget {
  const FruitQuizScreen({super.key});

  @override
  State<FruitQuizScreen> createState() => _FruitQuizScreenState();
}

class _FruitQuizScreenState extends State<FruitQuizScreen> {
  final List<Fruit> _fruits = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  bool _showName = false;
  bool _isLoading = true;
  bool _isShowingCountdown = false;
  int _countdown = 3;
  bool _showButtons = false; // O, X 버튼 표시 여부
  bool _showPhoto = false; // 사진 표시 여부 추가
  bool _isFirstQuestion = true; // 첫 번째 문제 여부 추가
  
  // 소리 재생을 위한 플레이어
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadFruits();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadFruits() {
    try {
      final fruits = FruitService.getFruits();
      // 랜덤으로 과일 순서 섞기
      fruits.shuffle();
      
      setState(() {
        _fruits.addAll(fruits);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('데이터를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _startQuiz() {
    // 사진 표시 후 카운트다운 시작
    setState(() {
      _showPhoto = true;
    });
    
    // 카운트다운 바로 시작
    _startCountdown();
  }

  void _startCountdown() async {
    // 카운트다운 소리 생성
    try {
      // beep.flac 파일 로드
      await _audioPlayer.setAsset('assets/sounds/beep.flac');
      await _audioPlayer.setVolume(0.7);
      
      // 첫 소리 재생
      _audioPlayer.play();
    } catch (e) {
      // 소리 파일이 없는 경우 대체 URL 사용
      debugPrint('소리 파일을 찾을 수 없습니다: $e');
      try {
        await _audioPlayer.setVolume(0.5);
        await _audioPlayer.setUrl('https://www.soundjay.com/buttons/beep-07.mp3');
        _audioPlayer.play();
      } catch (e) {
        debugPrint('대체 소리도 로드할 수 없습니다: $e');
      }
    }

    setState(() {
      _isShowingCountdown = true;
      _countdown = 3;
      _showName = false;
      _showButtons = false;
    });

    // 카운트다운 타이머
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        
        // 소리 재생 시도
        try {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } catch (e) {
          debugPrint('소리 재생 중 오류: $e');
        }
      } else {
        timer.cancel();
        setState(() {
          _isShowingCountdown = false;
          _showName = true;
          _showButtons = true;
        });
        
        // 마지막 비프음 (다른 소리로 설정 가능)
        try {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } catch (e) {
          debugPrint('소리 재생 중 오류: $e');
        }
      }
    });
  }

  void _handleAnswer(bool isCorrect) {
    if (isCorrect) {
      setState(() {
        _correctAnswers++;
      });
    }

    // 다음 문제로 넘어가기
    if (_currentIndex < _fruits.length - 1) {
      setState(() {
        _currentIndex++;
        _showName = false;
        _showButtons = false;
        _isFirstQuestion = false; // 첫 번째 문제가 아님
        
        // 첫 번째 이후 문제에서는 사진 바로 표시하고 카운트다운 시작
        _showPhoto = true; 
      });
      
      // 카운트다운 바로 시작 (첫 번째 이후 문제)
      _startCountdown();
    } else {
      // 모든 문제를 풀었을 때 결과 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            correctAnswers: _correctAnswers,
            totalQuestions: _fruits.length,
            onRestartQuiz: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const FruitQuizScreen(),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 진행도 표시
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LinearProgressIndicator(
                  value: _fruits.isEmpty
                      ? 0
                      : (_currentIndex + 1) / _fruits.length,
                  backgroundColor: Colors.deepPurple.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 진행 상황 숫자로 표시
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_currentIndex + 1} / ${_fruits.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fruits.isEmpty
              ? const Center(child: Text('데이터가 없습니다'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 카드 영역 (사진 영역)
                      Expanded(
                        flex: 4,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 사진 또는 시작 버튼
                            if (_showPhoto)
                              _buildFruitCard()
                            else if (_isFirstQuestion)
                              Center(
                                child: ElevatedButton(
                                  onPressed: _startQuiz,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    '시작하기',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 버튼 영역
                      Expanded(
                        flex: 1,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 버튼들
                            if (_showButtons)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // O 버튼
                                  _buildAnswerButton(
                                    text: 'O',
                                    color: Colors.green,
                                    onPressed: () => _handleAnswer(true),
                                  ),
                                  
                                  // X 버튼
                                  _buildAnswerButton(
                                    text: 'X',
                                    color: Colors.red,
                                    onPressed: () => _handleAnswer(false),
                                  ),
                                ],
                              ),
                              
                            // 카운트다운 오버레이
                            if (_isShowingCountdown)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFruitCard() {
    final fruit = _fruits[_currentIndex];
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 이미지
            Image.asset(
              fruit.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 이미지 로드 실패 시 에러 표시
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '이미지를 찾을 수 없습니다:\n${fruit.imagePath}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // 이름 표시 (정답 공개)
            if (_showName)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    fruit.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 120,
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: Text(text),
      ),
    );
  }
} 