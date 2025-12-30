import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/custom_quiz.dart';
import '../utils/sound_manager.dart';
import '../utils/storage_manager.dart';
import 'create_image_quiz_screen.dart';
import 'create_text_quiz_screen.dart';
import 'create_voice_quiz_screen.dart';

class QuizManagementScreen extends StatefulWidget {
  final String quizType; // 'image', 'text', 'voice'

  const QuizManagementScreen({
    super.key,
    required this.quizType,
  });

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen>
    with TickerProviderStateMixin {
  List<CustomQuiz> _quizzes = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'image', 'text', 'voice'
  late AnimationController _homeButtonController;
  late AnimationController _createButtonController;
  late Animation<double> _homeButtonScale;
  late Animation<double> _createButtonScale;
  bool _isHomeHovered = false;
  bool _isHomePressed = false;
  bool _isCreateHovered = false;
  bool _isCreatePressed = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.quizType;
    _loadQuizzes();
    
    // 홈 버튼 애니메이션
    _homeButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _homeButtonScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _homeButtonController, curve: Curves.easeInOut),
    );
    
    // 새 퀴즈 만들기 버튼 애니메이션
    _createButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _createButtonScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _createButtonController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _homeButtonController.dispose();
    _createButtonController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // StorageManager 초기화 확인
      await StorageManager.init();
      
      List<CustomQuiz> allQuizzes = [];

      // 이미지 퀴즈 로드 (StorageManager 사용)
      final imageQuizzes = await StorageManager.loadQuizzes(quizType: 'image');
      allQuizzes.addAll(imageQuizzes);

      // 텍스트 퀴즈 로드 (StorageManager 사용)
      final textQuizzes = await StorageManager.loadQuizzes(quizType: 'text');
      allQuizzes.addAll(textQuizzes);

      // 음성 퀴즈 로드 (StorageManager 사용)
      final voiceQuizzes = await StorageManager.loadQuizzes(quizType: 'voice');
      allQuizzes.addAll(voiceQuizzes);

      setState(() {
        _quizzes = allQuizzes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('퀴즈 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteQuiz(CustomQuiz quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.red.shade300,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 경고 아이콘
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              // 제목
              const Text(
                '퀴즈 삭제',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              // 내용
              Text(
                '${quiz.category ?? quiz.title} 퀴즈를 삭제하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '삭제된 퀴즈는 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 취소 버튼
                  MouseRegion(
                    onEnter: (_) => SoundManager().playHover(),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          SoundManager().playClick();
                          Navigator.pop(context, false);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 삭제 버튼
                  MouseRegion(
                    onEnter: (_) => SoundManager().playHover(),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          SoundManager().playClick();
                          Navigator.pop(context, true);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        // 모든 퀴즈 타입은 StorageManager 사용
        await StorageManager.deleteQuiz(quiz.id, quiz.quizType);
        
        await _loadQuizzes();

        if (mounted) {
          _showToastMessage('삭제되었습니다.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  void _editQuiz(CustomQuiz quiz) {
    switch (quiz.quizType) {
      case 'image':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => CreateImageQuizScreen(quizToEdit: quiz),
        ).then((_) => _loadQuizzes());
        break;
      case 'text':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => CreateTextQuizScreen(
            quizToEdit: quiz,
          ),
        ).then((_) => _loadQuizzes());
        break;
      case 'voice':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => CreateVoiceQuizScreen(
            quizToEdit: quiz,
          ),
        ).then((_) => _loadQuizzes());
        break;
    }
  }

  void _createNewQuiz() {
    switch (widget.quizType) {
      case 'image':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => const CreateImageQuizScreen(),
        ).then((_) => _loadQuizzes());
        break;
      case 'text':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => const CreateTextQuizScreen(),
        ).then((_) => _loadQuizzes());
        break;
      case 'voice':
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (context) => const CreateVoiceQuizScreen(),
        ).then((_) => _loadQuizzes());
        break;
    }
  }

  String _getQuizTypeName(String type) {
    switch (type) {
      case 'image':
        return '이미지 퀴즈';
      case 'text':
        return '텍스트 퀴즈';
      case 'voice':
        return '음성 퀴즈';
      default:
        return type;
    }
  }

  Color _getQuizTypeColor(String type) {
    switch (type) {
      case 'image':
        return const Color(0xFF1976D2);
      case 'text':
        return const Color(0xFF7B1FA2);
      case 'voice':
        return const Color(0xFFF57C00);
      default:
        return Colors.grey;
    }
  }

  List<CustomQuiz> get _filteredQuizzes {
    if (_selectedFilter == 'all') {
      return _quizzes;
    }
    return _quizzes.where((q) => q.quizType == _selectedFilter).toList();
  }

  // 화면 중앙에 토스트 메시지 표시
  void _showToastMessage(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.5 - 30,
        left: MediaQuery.of(context).size.width * 0.5 - 100,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerWidth = screenWidth * 0.30; // 중앙 60% 영역
    
    return Scaffold(
      backgroundColor: Colors.transparent, // 배경 투명 (main.dart에서 처리)
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: centerWidth, // 중앙 60%만 사용
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // 퀴즈 목록 영역 또는 "등록된 퀴즈가 없습니다" 메시지
                      _filteredQuizzes.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.quiz_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '등록된 퀴즈가 없습니다',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 80,
                              ),
                              child: SizedBox(
                                height: 420, // 4개 카드가 보일 만큼의 높이 (각 카드 약 105px)
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 20),
                                  itemCount: _filteredQuizzes.length,
                                  itemBuilder: (context, index) {
                                    return _buildQuizCard(_filteredQuizzes[index]);
                                  },
                                ),
                              ),
                            ),
                      const SizedBox(height: 20), // 퀴즈 목록과 버튼 사이 간격
                      // 하단 버튼 영역 (고정)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          bottom: 20.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                      // 홈 버튼 (게임 화면 에셋 사용)
                      MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _isHomeHovered = true;
                          });
                          _homeButtonController.forward();
                          SoundManager().playHover();
                        },
                        onExit: (_) {
                          setState(() {
                            _isHomeHovered = false;
                          });
                          _homeButtonController.reverse();
                        },
                        child: GestureDetector(
                          onTapDown: (_) {
                            setState(() {
                              _isHomePressed = true;
                            });
                            SoundManager().playClick();
                          },
                          onTapUp: (_) {
                            setState(() {
                              _isHomePressed = false;
                            });
                            // 메인 화면으로 이동 (퀴즈 팝업창은 이미 닫혀있으므로 현재 화면만 닫으면 됨)
                            Navigator.of(context).pop();
                          },
                          onTapCancel: () {
                            setState(() {
                              _isHomePressed = false;
                            });
                          },
                          child: AnimatedBuilder(
                            animation: _homeButtonScale,
                            builder: (context, child) {
                              double scale = _isHomePressed ? 0.95 : _homeButtonScale.value;
                              return Transform.scale(
                                scale: scale,
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
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 새 퀴즈 만들기 버튼
                      MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _isCreateHovered = true;
                          });
                          _createButtonController.forward();
                          SoundManager().playHover();
                        },
                        onExit: (_) {
                          setState(() {
                            _isCreateHovered = false;
                          });
                          _createButtonController.reverse();
                        },
                        child: GestureDetector(
                          onTapDown: (_) {
                            setState(() {
                              _isCreatePressed = true;
                            });
                            SoundManager().playClick();
                          },
                          onTapUp: (_) {
                            setState(() {
                              _isCreatePressed = false;
                            });
                            _createNewQuiz();
                          },
                          onTapCancel: () {
                            setState(() {
                              _isCreatePressed = false;
                            });
                          },
                          child: AnimatedBuilder(
                            animation: _createButtonScale,
                            builder: (context, child) {
                              double scale = _isCreatePressed ? 0.95 : _createButtonScale.value;
                              return Transform.scale(
                                scale: scale,
                                child: RepaintBoundary(
                                  child: SizedBox(
                                    width: 208, // 버튼 가로 길이 조절: 홈버튼 높이(55)에 맞춰 비율 계산 (원본: 625, 현재: 208 = 55 * (625/165))
                                    height: 55, // 버튼 높이 조절: 홈버튼과 동일한 높이 (현재: 55)
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // 버튼 에셋 이미지
                                        Image.asset(
                                          'assets/images/Button_CreateQuiz.png',
                                          width: 208,
                                          height: 55,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          isAntiAlias: true,
                                          cacheWidth: 208,
                                          cacheHeight: 55,
                                        ),
                                        // 텍스트 오버레이
                                        Text(
                                          '+ 새 ${_getQuizTypeName(widget.quizType)} 만들기',
                                          style: TextStyle(
                                            fontSize: 18, // 폰트 크기 조절: 이 값을 변경하면 텍스트 크기가 조절됩니다 (현재: 18)
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                            ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(CustomQuiz quiz) {
    // 모든 퀴즈 타입에 대해 이미지 퀴즈 스타일 적용 (제목이 위에 있는 스타일)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.category ?? quiz.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.questions.length}문제',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.createdAt.year}.${quiz.createdAt.month.toString().padLeft(2, '0')}.${quiz.createdAt.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 수정 버튼
            MouseRegion(
              onEnter: (_) => SoundManager().playHover(),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  SoundManager().playClick();
                  _editQuiz(quiz);
                },
                tooltip: '수정',
              ),
            ),
            // 삭제 버튼
            MouseRegion(
              onEnter: (_) => SoundManager().playHover(),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  SoundManager().playClick();
                  _deleteQuiz(quiz);
                },
                tooltip: '삭제',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
