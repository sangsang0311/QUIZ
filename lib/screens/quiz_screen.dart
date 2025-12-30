import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/celebrity.dart';
import '../services/celebrity_service.dart';
import '../widgets/celebrity_card.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final List<Celebrity>? customCelebrities;

  const QuizScreen({
    super.key,
    this.customCelebrities,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final List<Celebrity> _celebrities = [];
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
    _loadCelebrities();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCelebrities() async {
    try {
      if (widget.customCelebrities != null && widget.customCelebrities!.isNotEmpty) {
        setState(() {
          _celebrities.addAll(widget.customCelebrities!);
          _isLoading = false;
        });
      } else {
        final celebrities = await CelebrityService.getCelebrities();
        setState(() {
          _celebrities.addAll(celebrities);
          _isLoading = false;
        });
      }
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
    if (_currentIndex < _celebrities.length - 1) {
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
            totalQuestions: _celebrities.length,
            onRestartQuiz: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    customCelebrities: widget.customCelebrities,
                  ),
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
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // 화살표 색상 변경
        titleTextStyle: const TextStyle(color: Colors.white), // 타이틀 색상 변경
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 진행도 표시
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LinearProgressIndicator(
                  value: _celebrities.isEmpty
                      ? 0
                      : (_currentIndex + 1) / _celebrities.length,
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
                '${_currentIndex + 1} / ${_celebrities.length}',
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
          : _celebrities.isEmpty
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
                              CelebrityCard(
                                celebrity: _celebrities[_currentIndex],
                                showName: _showName,
                              )
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