import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/custom_quiz.dart';
import '../utils/storage_manager.dart';
import '../utils/sound_manager.dart';

class CreateTextQuizScreen extends StatefulWidget {
  final String? category; // 카테고리 (수도, 속담, 초성, 사자성어)
  final String? subCategory; // 초성 퀴즈용 서브카테고리
  final CustomQuiz? quizToEdit;

  const CreateTextQuizScreen({
    super.key,
    this.category,
    this.subCategory,
    this.quizToEdit,
  });

  @override
  State<CreateTextQuizScreen> createState() => _CreateTextQuizScreenState();
}

class _CreateTextQuizScreenState extends State<CreateTextQuizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final List<Map<String, dynamic>> _questions = []; // {questionText, answer, questionFontSize, answerFontSize}
  
  // 글씨 크기 (기본값은 텍스트 길이에 따라 자동 결정, 사용자가 조절 가능)
  double _questionFontSize = 48.0; // 기본값
  double _answerFontSize = 40.0; // 기본값

  String? _editingQuizId;
  int? _editingQuestionIndex;
  bool _isSaving = false; // 저장 중 상태
  
  // 탭 호버 애니메이션용
  final Map<int, bool> _tabHoverStates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        SoundManager().playClick();
      }
    });
    // StorageManager 초기화
    StorageManager.init();
    if (widget.quizToEdit != null) {
      _editingQuizId = widget.quizToEdit!.id;
      _categoryController.text = widget.quizToEdit!.category ?? widget.quizToEdit!.title;
      _loadQuizQuestions();
    } else if (widget.category != null) {
      _categoryController.text = widget.category!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  // 기존 퀴즈 문제 로드
  void _loadQuizQuestions() {
    if (widget.quizToEdit == null) return;
    
    _questions.clear();
    for (var q in widget.quizToEdit!.questions) {
      _questions.add({
        'questionText': q.questionText ?? '',
        'answer': q.answer ?? '',
        'questionFontSize': q.questionFontSize,
        'answerFontSize': q.answerFontSize,
      });
    }
  }
  
  // 팝업창 중간에 토스트 메시지 표시
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
  
  // 텍스트 길이에 따른 기본 폰트 크기 계산
  double _calculateDefaultFontSize(int textLength) {
    if (textLength <= 10) {
      return 64.0;
    } else if (textLength <= 20) {
      return 56.0;
    } else if (textLength <= 30) {
      return 48.0;
    } else if (textLength <= 40) {
      return 40.0;
    } else {
      return 36.0;
    }
  }

  // 문제 추가
  void _addQuestion() {
    if (_questionController.text.trim().isEmpty || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제와 정답을 모두 입력해주세요.')),
      );
      return;
    }
    
    setState(() {
      if (_editingQuestionIndex != null) {
        // 수정 모드
        _questions[_editingQuestionIndex!] = {
          'questionText': _questionController.text.trim(),
          'answer': _answerController.text.trim(),
          'questionFontSize': _questionFontSize,
          'answerFontSize': _answerFontSize,
        };
        _editingQuestionIndex = null;
      } else {
        // 추가 모드
        _questions.add({
          'questionText': _questionController.text.trim(),
          'answer': _answerController.text.trim(),
          'questionFontSize': _questionFontSize,
          'answerFontSize': _answerFontSize,
        });
      }
      
      // 초기화
      _questionController.clear();
      _answerController.clear();
      // 글씨 크기도 기본값으로 리셋
      _questionFontSize = 48.0;
      _answerFontSize = 40.0;
      
      // 팝업창 중간에 토스트 메시지 표시
      _showToastMessage('추가 되었습니다.');
    });
  }

  // 문제 수정
  void _editQuestion(int index) {
    final question = _questions[index];
    setState(() {
      _editingQuestionIndex = index;
      _questionController.text = question['questionText'] as String;
      _answerController.text = question['answer'] as String;
      _questionFontSize = question['questionFontSize'] != null 
          ? (question['questionFontSize'] as num).toDouble()
          : _calculateDefaultFontSize((question['questionText'] as String).length);
      _answerFontSize = question['answerFontSize'] != null
          ? (question['answerFontSize'] as num).toDouble()
          : _calculateDefaultFontSize((question['answer'] as String).length);
      _tabController.animateTo(1); // 문제 추가 탭으로 이동
    });
  }

  // 문제 삭제
  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  // 퀴즈 저장
  Future<void> _saveQuiz() async {
    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리명을 입력해주세요.')),
      );
      return;
    }

    if (_questions.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 3개 이상의 문제를 추가해주세요.')),
      );
      return;
    }

    // 모든 문제에 문제 텍스트와 정답이 있는지 확인
    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i]['questionText'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}번 문제의 문제를 입력해주세요.')),
        );
        return;
      }
      if (_questions[i]['answer'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}번 문제의 정답을 입력해주세요.')),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // StorageManager 초기화 확인
      await StorageManager.init();
      
      final questions = _questions.map((q) {
        return CustomQuizQuestion(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_questions.indexOf(q)}',
          questionText: q['questionText'],
          answer: q['answer'],
          questionFontSize: q['questionFontSize'] != null ? (q['questionFontSize'] as num).toDouble() : null,
          answerFontSize: q['answerFontSize'] != null ? (q['answerFontSize'] as num).toDouble() : null,
        );
      }).toList();
      
      CustomQuiz quizToSave;
      if (_editingQuizId != null) {
        // 수정 모드
        final existingQuizzes = await StorageManager.loadQuizzes(quizType: 'text');
        final existingQuiz = existingQuizzes.firstWhere(
          (q) => q.id == _editingQuizId,
          orElse: () => CustomQuiz(
            id: _editingQuizId!,
            quizType: 'text',
            title: _categoryController.text.trim(),
            category: _categoryController.text.trim(),
            questions: [],
            createdAt: DateTime.now(),
          ),
        );
        
        quizToSave = CustomQuiz(
          id: _editingQuizId!,
          quizType: 'text',
          title: _categoryController.text.trim(),
          category: _categoryController.text.trim(),
          questions: questions,
          createdAt: existingQuiz.createdAt,
        );
      } else {
        // 새 퀴즈
        quizToSave = CustomQuiz(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          quizType: 'text',
          title: _categoryController.text.trim(),
          category: _categoryController.text.trim(),
          questions: questions,
          createdAt: DateTime.now(),
        );
      }
      
      await StorageManager.saveQuiz(quizToSave);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showToastMessage('저장되었습니다.');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 게임 화면 미리보기 (텍스트 퀴즈)
  Widget _buildGamePreview() {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.60;
    final previewWidth = availableWidth.clamp(400.0, 600.0);
    final previewHeight = previewWidth / (1920.0 / 1080.0);
    
    // 문제 폰트 크기 (사용자가 조절한 값 또는 기본값)
    final questionFontSize = _questionFontSize;
    // 정답 폰트 크기 (사용자가 조절한 값 또는 기본값)
    final answerFontSize = _answerFontSize;
    
    return Container(
      width: previewWidth,
      height: previewHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7B1FA2), width: 2), // 테마 색상, 두께 줄임
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // 문제 영역 (70%)
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF4AA0A9),
                      width: 2.0,
                    ),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      _questionController.text.isEmpty ? '문제를 입력하세요' : _questionController.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: questionFontSize,
                        fontWeight: FontWeight.w900,
                        color: _questionController.text.isEmpty ? Colors.grey : Colors.black87,
                        letterSpacing: 1.0,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 정답 영역 (30%)
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _answerController.text.isEmpty ? '정답을 입력하세요' : _answerController.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: answerFontSize,
                        fontWeight: FontWeight.w900,
                        color: _answerController.text.isEmpty ? Colors.grey : Colors.black87,
                        letterSpacing: 1.0,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // 카테고리 탭
  Widget _buildCategoryTab() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리명',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7B1FA2),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _categoryController,
          maxLength: 10, // 최대 10글자 제한
          decoration: InputDecoration(
            hintText: '예: 동물, 과일 등',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            counterText: '', // 글자 수 카운터 숨기기
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _categoryController.text.trim().isNotEmpty
                ? () {
                    _tabController.animateTo(1);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              '다음',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Spacer(), // 남은 공간 채우기
      ],
    );
  }

  // 문제 추가 탭
  Widget _buildAddQuestionTab() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '문제 추가',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7B1FA2),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            '게임 화면 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: _buildGamePreview()),
        const SizedBox(height: 24),
        // 문제 입력 필드와 글씨 크기 조절
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: '문제를 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '', // 글자 수 카운터 숨기기
                ),
                onChanged: (value) {
                  // 실시간 업데이트를 위해 setState 호출
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            // 문제 글씨 크기 조절 버튼
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _questionFontSize = (_questionFontSize - 4).clamp(20.0, 100.0);
                    });
                  },
                  icon: const Icon(Icons.remove, color: Color(0xFF7B1FA2)),
                  tooltip: '글씨 크기 줄이기',
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_questionFontSize.toInt()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7B1FA2),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _questionFontSize = (_questionFontSize + 4).clamp(20.0, 100.0);
                    });
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF7B1FA2)),
                  tooltip: '글씨 크기 늘리기',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 정답 입력 필드와 글씨 크기 조절
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: '정답을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '', // 글자 수 카운터 숨기기
                ),
                onChanged: (value) {
                  // 실시간 업데이트를 위해 setState 호출
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            // 정답 글씨 크기 조절 버튼
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _answerFontSize = (_answerFontSize - 4).clamp(20.0, 100.0);
                    });
                  },
                  icon: const Icon(Icons.remove, color: Color(0xFF7B1FA2)),
                  tooltip: '글씨 크기 줄이기',
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_answerFontSize.toInt()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7B1FA2),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _answerFontSize = (_answerFontSize + 4).clamp(20.0, 100.0);
                    });
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF7B1FA2)),
                  tooltip: '글씨 크기 늘리기',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _questionController.text.trim().isNotEmpty &&
                    _answerController.text.trim().isNotEmpty
                ? _addQuestion
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              _editingQuestionIndex != null ? '문제 수정' : '문제 추가',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // 문제 목록 탭
  Widget _buildQuestionListTab() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '문제 목록',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B1FA2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_questions.length}개',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Flexible(
          child: _questions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          '추가된 문제가 없습니다.\n문제 추가 탭에서 문제를 추가해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: List.generate(_questions.length, (index) {
                      return _buildQuestionCard(index);
                    }),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_questions.length >= 3 && !_isSaving) ? _saveQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '저장 중...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _questions.length >= 3
                        ? '퀴즈 저장 (${_questions.length}개)'
                        : '최소 3개 이상 추가해주세요 (${_questions.length}/3)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // 문제 카드 빌드
  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${index + 1}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF7B1FA2)),
                    onPressed: () => _editQuestion(index),
                    tooltip: '수정',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeQuestion(index),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '문제: ${question['questionText']}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '정답: ${question['answer']}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B1FA2),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 900),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF7B1FA2), // 보라색 계열
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
                    color: const Color(0xFF7B1FA2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.text_fields,
                    color: Color(0xFF7B1FA2),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '텍스트 퀴즈 만들기',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
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
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Color(0xFF7B1FA2)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 탭 바
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF7B1FA2),
                indicatorWeight: 3,
                labelColor: const Color(0xFF7B1FA2),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                onTap: (index) {
                  if (_tabController.index != index) {
                    SoundManager().playHover();
                  }
                },
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.category, size: 20),
                        const SizedBox(width: 8),
                        const Text('카테고리'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 20),
                        const SizedBox(width: 8),
                        const Text('문제 추가'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.list, size: 20),
                        const SizedBox(width: 8),
                        Text('문제 목록 (${_questions.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 탭 내용
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 700,
                      child: _buildCategoryTab(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 700,
                      child: _buildAddQuestionTab(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 700,
                      child: _buildQuestionListTab(),
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
}
