import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'image_quiz_game_screen.dart';
import 'quiz_management_screen.dart';
import '../models/custom_quiz.dart';
import '../utils/sound_manager.dart';
import '../utils/storage_manager.dart';

class ImageQuizPopup extends StatefulWidget {
  const ImageQuizPopup({super.key});

  @override
  State<ImageQuizPopup> createState() => _ImageQuizPopupState();
}

class _ImageQuizPopupState extends State<ImageQuizPopup>
    with SingleTickerProviderStateMixin {
  String? selectedCategory;
  String? selectedCustomQuizId; // 커스텀 퀴즈 ID
  int questionCount = 5;
  int countdownSeconds = 3; // 카운트다운 시간 (0 = 없음, 3, 5)
  bool showSlider = false;
  bool showCountdownSlider = true; // 카운트다운 슬라이더 표시 여부
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<CustomQuiz> customQuizzes = [];

  final List<String> categories = [
    '동물',
    '과일',
    '나라',
  ];

  @override
  void initState() {
    super.initState();
    // 문제수 Slider는 펼쳐진 상태
    showSlider = true;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
    _loadCustomQuizzes();
  }

  Future<void> _loadCustomQuizzes() async {
    try {
      await StorageManager.init();
      final loadedQuizzes = await StorageManager.loadQuizzes(quizType: 'image');
      setState(() {
        customQuizzes = loadedQuizzes;
      });
    } catch (e) {
      debugPrint('커스텀 퀴즈 로드 오류: $e');
    }
  }

  int _getMaxQuestionCount() {
    // 커스텀 퀴즈가 선택된 경우
    if (selectedCustomQuizId != null) {
      final customQuiz = customQuizzes.firstWhere(
        (q) => q.id == selectedCustomQuizId,
        orElse: () => CustomQuiz(
          id: '',
          quizType: 'image',
          title: '',
          questions: [],
          createdAt: DateTime.now(),
        ),
      );
      final questionCount = customQuiz.questions.length;
      if (questionCount < 3) return 3;
      return questionCount.clamp(3, 10);
    }
    // 기본 카테고리인 경우
    return 10;
  }

  Future<void> _deleteCustomQuiz(String quizId) async {
    // 삭제 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 삭제'),
        content: const Text('이 퀴즈를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageManager.deleteQuiz(quizId, 'image');
        
        setState(() {
          customQuizzes.removeWhere((q) => q.id == quizId);
          if (selectedCustomQuizId == quizId) {
            selectedCustomQuizId = null;
            selectedCategory = null;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('퀴즈가 삭제되었습니다.')),
          );
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF1976D2), // 파란색 계열로 변경
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: Color(0xFF1976D2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '이미지 퀴즈',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '카테고리 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // 카테고리 버튼들 (기본 카테고리 + 커스텀 퀴즈 함께 표시)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // 기본 카테고리들
                  ...categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final isSelected = selectedCategory == category && selectedCustomQuizId == null;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: _CategoryButton(
                        isSelected: isSelected,
                        category: category,
                        onTap: () {
                          SoundManager().playClick();
                          setState(() {
                            selectedCategory = category;
                            selectedCustomQuizId = null;
                            showSlider = true;
                          });
                        },
                      ),
                    );
                  }),
                  // 커스텀 퀴즈들
                  ...customQuizzes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final quiz = entry.value;
                    final isSelected = selectedCustomQuizId == quiz.id;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + ((categories.length + index) * 50)),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: _CategoryButton(
                        isSelected: isSelected,
                        category: quiz.title,
                        onTap: () {
                          SoundManager().playClick();
                          setState(() {
                            selectedCustomQuizId = quiz.id;
                            selectedCategory = null;
                            showSlider = true;
                            // 문제 수를 최대값으로 조정
                            final maxCount = quiz.questions.length.clamp(3, 10);
                            if (questionCount > maxCount) {
                              questionCount = maxCount;
                            }
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
              // 문제 수 Slider (카테고리 선택 시 표시)
              if (showSlider) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Icon(
                      Icons.quiz,
                      color: Color(0xFF1976D2),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '문제 수: $questionCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF1976D2),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFF1976D2),
                    overlayColor: const Color(0xFF1976D2).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: questionCount.toDouble(),
                    min: 3,
                    max: _getMaxQuestionCount().toDouble(),
                    divisions: _getMaxQuestionCount() > 3 ? (_getMaxQuestionCount() - 3).clamp(1, 7) : null,
                    label: questionCount.toString(),
                    onChangeStart: (_) {
                      // onChangeStart에서는 사운드 재생하지 않음
                    },
                    onChanged: (value) {
                      final newValue = value.toInt();
                      if (newValue != questionCount) {
                        // 값이 변경될 때만 호버 사운드 재생
                        SoundManager().playHover();
                      }
                      setState(() {
                        questionCount = newValue;
                      });
                    },
                  ),
                ),
              ],
              // 카운트다운 시간 Slider
              if (showCountdownSlider) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      color: Color(0xFF1976D2),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '카운트다운: ${countdownSeconds == 0 ? "없음" : "$countdownSeconds초"}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF1976D2),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFF1976D2),
                    overlayColor: const Color(0xFF1976D2).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: countdownSeconds.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 2, // 0, 3, 5
                    label: countdownSeconds == 0 ? "없음" : "$countdownSeconds초",
                    onChangeStart: (_) {
                      // onChangeStart에서는 사운드 재생하지 않음
                    },
                    onChanged: (value) {
                      int newValue;
                      // 0, 3, 5 중 가장 가까운 값으로 설정
                      if (value < 1.5) {
                        newValue = 0;
                      } else if (value < 4) {
                        newValue = 3;
                      } else {
                        newValue = 5;
                      }
                      if (newValue != countdownSeconds) {
                        // 값이 변경될 때만 호버 사운드 재생
                        SoundManager().playHover();
                      }
                      setState(() {
                        countdownSeconds = newValue;
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // 시작 버튼 (항상 표시, 비활성화 가능)
              if (showSlider)
                _buildStartButton(
                  color: const Color(0xFF1976D2),
                  isEnabled: selectedCategory != null || selectedCustomQuizId != null,
                  onPressed: (selectedCategory != null || selectedCustomQuizId != null)
                      ? () {
                          Navigator.pop(context);
                          if (selectedCustomQuizId != null) {
                            // 커스텀 퀴즈 선택 시
                            final customQuiz = customQuizzes.firstWhere(
                              (q) => q.id == selectedCustomQuizId,
                            );
                            // TODO: 커스텀 퀴즈 게임 화면으로 이동
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageQuizGameScreen(
                                  category: customQuiz.category ?? '커스텀',
                                  questionCount: questionCount,
                                  countdownSeconds: countdownSeconds,
                                  customQuiz: customQuiz,
                                ),
                              ),
                            );
                          } else {
                            // 기본 카테고리 선택 시
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageQuizGameScreen(
                                  category: selectedCategory!,
                                  questionCount: questionCount,
                                  countdownSeconds: countdownSeconds,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              // 퀴즈 관리 버튼
              if (showSlider)
                const SizedBox(height: 12),
              _buildCreateQuizButton(
                color: const Color(0xFF1976D2),
                onPressed: () async {
                  // 퀴즈 팝업창 먼저 닫기
                  Navigator.pop(context);
                  // 퀴즈 관리 화면으로 이동
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizManagementScreen(quizType: 'image'),
                    ),
                  );
                  // 퀴즈 관리 화면에서 돌아온 후 새로고침 (팝업창을 다시 열어야 하므로 여기서는 처리하지 않음)
                },
              ),
              // 취소 버튼
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카테고리 버튼 위젯 (호버 애니메이션 포함)
  Widget _CategoryButton({
    required bool isSelected,
    required String category,
    required VoidCallback onTap,
  }) {
    return _CategoryButtonWidget(
      isSelected: isSelected,
      category: category,
      onTap: onTap,
    );
  }

  Widget _buildStartButton({
    required Color color,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                  color.withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade300.withOpacity(0.15),
                  Colors.grey.shade300.withOpacity(0.08),
                  Colors.grey.shade300.withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? color
              : Colors.grey.shade400,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? color.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: isEnabled ? (_) => SoundManager().playHover() : null,
          child: InkWell(
            onTap: isEnabled ? () {
              SoundManager().playClick();
              onPressed?.call();
            } : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Center(
                child: Text(
                  '시작',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isEnabled ? color : Colors.grey.shade600,
                    letterSpacing: 5.0,
                    shadows: isEnabled
                        ? [
                            Shadow(
                              color: color.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateQuizButton({
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: const Offset(0, -2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) => SoundManager().playHover(),
          child: InkWell(
            onTap: () {
              SoundManager().playClick();
              onPressed();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.08),
                    color.withOpacity(0.03),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 가운데 텍스트 (항상 가운데 고정)
                  Text(
                    '퀴즈 관리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: color.withOpacity(0.2),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // 왼쪽 아이콘 (왼쪽에서 80px 떨어진 위치)
                  Positioned(
                    left: 120,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          color: color,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 카테고리 버튼 상태 관리 위젯
class _CategoryButtonWidget extends StatefulWidget {
  final bool isSelected;
  final String category;
  final VoidCallback onTap;

  const _CategoryButtonWidget({
    required this.isSelected,
    required this.category,
    required this.onTap,
  });

  @override
  State<_CategoryButtonWidget> createState() => _CategoryButtonWidgetState();
}

class _CategoryButtonWidgetState extends State<_CategoryButtonWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        SoundManager().playHover();
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF1976D2)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade300,
                width: widget.isSelected ? 3 : 2,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1976D2)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.category,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isSelected
                    ? Colors.white
                    : Colors.grey.shade700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
