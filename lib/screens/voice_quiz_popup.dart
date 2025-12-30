import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'quiz_management_screen.dart';
import 'voice_quiz_game_screen.dart';
import '../models/custom_quiz.dart';
import '../utils/sound_manager.dart';
import '../utils/storage_manager.dart';

class VoiceQuizPopup extends StatefulWidget {
  const VoiceQuizPopup({super.key});

  @override
  State<VoiceQuizPopup> createState() => _VoiceQuizPopupState();
}

class _VoiceQuizPopupState extends State<VoiceQuizPopup>
    with SingleTickerProviderStateMixin {
  String? selectedCategory;
  String? selectedCustomQuizId; // 커스텀 퀴즈 ID
  int questionCount = 5;
  bool showSlider = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  List<CustomQuiz> customQuizzes = [];

  // 음성 퀴즈 카테고리
  List<String> categories = ['동물소리'];

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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _loadCustomQuizzes();
  }

  Future<void> _loadCustomQuizzes() async {
    try {
      await StorageManager.init();
      final loadedQuizzes = await StorageManager.loadQuizzes(quizType: 'voice');
      
      if (mounted) {
        setState(() {
          customQuizzes = loadedQuizzes;
        });
      }
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
          quizType: 'voice',
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
            color: const Color(0xFFF57C00),
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
          child: ScaleTransition(
            scale: _scaleAnimation,
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
                        color: const Color(0xFFF57C00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Color(0xFFF57C00),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '음성 퀴즈',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF57C00),
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
                // 카테고리 버튼들 (기본 카테고리 + 커스텀 퀴즈)
                if (categories.isEmpty && customQuizzes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '아직 생성된 퀴즈가 없습니다.\n퀴즈 만들기를 통해 퀴즈를 생성해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // 기본 카테고리들
                      ...categories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        final isSelected = selectedCategory == category;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: _CategoryButtonWithHover(
                                isSelected: isSelected,
                                category: category,
                                onTap: () {
                                  SoundManager().playClick();
                                  setState(() {
                                    selectedCategory = category;
                                    selectedCustomQuizId = null; // 커스텀 퀴즈 선택 해제
                                    showSlider = true;
                                  });
                                },
                              ),
                            );
                          },
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
                              child: _CategoryButtonWithHover(
                                isSelected: isSelected,
                                category: quiz.title,
                                onTap: () {
                                  SoundManager().playClick();
                                  setState(() {
                                    selectedCustomQuizId = quiz.id;
                                    selectedCategory = null; // 기본 카테고리 선택 해제
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
                          },
                        );
                      }),
                    ],
                  ),
                // Slider (카테고리 선택 시 표시)
                if (showSlider) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(
                        Icons.quiz,
                        color: Color(0xFFF57C00),
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
                      activeTrackColor: const Color(0xFFF57C00),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: const Color(0xFFF57C00),
                      overlayColor: const Color(0xFFF57C00).withOpacity(0.2),
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
                const SizedBox(height: 28),
                // 시작 버튼 (항상 표시, 비활성화 가능)
                if (showSlider)
                  _buildStartButton(
                    color: const Color(0xFFF57C00),
                    isEnabled: selectedCategory != null || selectedCustomQuizId != null,
                    onPressed: (selectedCategory != null || selectedCustomQuizId != null)
                        ? () {
                            Navigator.pop(context);
                            if (selectedCustomQuizId != null) {
                              // 커스텀 퀴즈 선택 시
                              final customQuiz = customQuizzes.firstWhere(
                                (q) => q.id == selectedCustomQuizId,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VoiceQuizGameScreen(
                                    category: customQuiz.category ?? customQuiz.title,
                                    questionCount: questionCount,
                                    customQuiz: customQuiz,
                                  ),
                                ),
                              );
                            } else {
                              // 기본 카테고리 선택 시
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VoiceQuizGameScreen(
                                    category: selectedCategory!,
                                    questionCount: questionCount,
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
                  color: const Color(0xFFF57C00),
                  onPressed: () async {
                    // 퀴즈 팝업창 먼저 닫기
                    Navigator.pop(context);
                    // 퀴즈 관리 화면으로 이동
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuizManagementScreen(quizType: 'voice'),
                      ),
                    );
                    // 퀴즈 관리 화면에서 돌아온 후 새로고침
                    if (mounted) {
                      _loadCustomQuizzes();
                    }
                  },
                ),
                const SizedBox(height: 12),
                // 취소 버튼
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
      ),
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

// 카테고리 버튼 호버 애니메이션 위젯
class _CategoryButtonWithHover extends StatefulWidget {
  final bool isSelected;
  final String category;
  final VoidCallback onTap;

  const _CategoryButtonWithHover({
    required this.isSelected,
    required this.category,
    required this.onTap,
  });

  @override
  State<_CategoryButtonWithHover> createState() => _CategoryButtonWithHoverState();
}

class _CategoryButtonWithHoverState extends State<_CategoryButtonWithHover> {
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
                  ? const Color(0xFFF57C00)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFF57C00)
                    : Colors.grey.shade300,
                width: widget.isSelected ? 3 : 2,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF57C00).withOpacity(0.3),
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
