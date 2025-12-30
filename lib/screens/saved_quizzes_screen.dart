import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/celebrity.dart';
import '../models/quiz.dart';
import 'quiz_screen.dart';
import 'custom_quiz_screen.dart';

class SavedQuizzesScreen extends StatefulWidget {
  const SavedQuizzesScreen({super.key});

  @override
  State<SavedQuizzesScreen> createState() => _SavedQuizzesScreenState();
}

class _SavedQuizzesScreenState extends State<SavedQuizzesScreen> {
  List<Quiz> _savedQuizzes = [];
  bool _isLoading = true;
  // 각 퀴즈별로 선택된 개수를 저장할 맵
  final Map<String, int> _selectedCounts = {};

  @override
  void initState() {
    super.initState();
    _loadSavedQuizzes();
  }

  // 저장된 퀴즈 로드
  Future<void> _loadSavedQuizzes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final quizzesList = prefs.getStringList('saved_quizzes') ?? [];
      
      _savedQuizzes = quizzesList.map((quizStr) {
        final quizMap = json.decode(quizStr) as Map<String, dynamic>;
        return Quiz.fromJson(quizMap);
      }).toList();
    } catch (e) {
      debugPrint('Error loading saved quizzes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 퀴즈 삭제
  Future<void> _deleteQuiz(int index) async {
    try {
      _savedQuizzes.removeAt(index);
      
      final prefs = await SharedPreferences.getInstance();
      final quizzesList = _savedQuizzes.map((quiz) => json.encode(quiz.toJson())).toList();
      await prefs.setStringList('saved_quizzes', quizzesList);
      
      setState(() {});
    } catch (e) {
      debugPrint('Error deleting quiz: $e');
    }
  }

  // 퀴즈 시작
  void _startQuiz(Quiz quiz) {
    final selectedCount = _selectedCounts[quiz.id] ?? quiz.celebrities.length;
    
    // 선택된 개수만큼 랜덤으로 선택
    final shuffledCelebrities = List<Celebrity>.from(quiz.celebrities);
    shuffledCelebrities.shuffle();
    
    final selectedCelebrities = shuffledCelebrities.take(selectedCount).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          customCelebrities: selectedCelebrities,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 만든 퀴즈'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedQuizzes.isEmpty
              ? _buildEmptyState()
              : _buildQuizList(),
    );
  }

  // 퀴즈가 없을 때 표시
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            '저장된 퀴즈가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '나만의 퀴즈를 만들고 저장해보세요',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('돌아가기'),
          ),
        ],
      ),
    );
  }

  // 퀴즈 목록 표시
  Widget _buildQuizList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = _savedQuizzes[index];
        
        // 해당 퀴즈의 선택된 개수가 없으면 전체 개수로 초기화
        if (_selectedCounts[quiz.id] == null) {
          _selectedCounts[quiz.id] = quiz.celebrities.length;
        }
        
        // 슬라이더 최대값 계산 (최소 1개)
        final int celebritiesCount = quiz.celebrities.length;
        final double maxValue = celebritiesCount.toDouble();
        // 슬라이더 최소값은 항상 1 또는 최대값 중 작은 값으로 설정
        final double minValue = maxValue > 0 ? 1 : 0;
        // divisions 계산 (0으로 나누지 않도록)
        final int divisions = maxValue > 1 ? (maxValue.toInt() - 1) : 1;
        
        // 선택된 값이 유효한지 확인하고 조정
        int currentValue = _selectedCounts[quiz.id]!;
        if (currentValue > celebritiesCount) {
          currentValue = celebritiesCount;
          _selectedCounts[quiz.id] = currentValue;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  quiz.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  '${quiz.celebrities.length}개의 사진 • ${_formatDate(quiz.createdAt)}',
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // 사진이 1개 이상일 때만 슬라이더 표시
              if (celebritiesCount > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        '사용할 개수: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.deepPurple,
                            inactiveTrackColor: Colors.deepPurple.shade100,
                            thumbColor: Colors.deepPurple,
                            overlayColor: Colors.deepPurple.withOpacity(0.2),
                            valueIndicatorColor: Colors.deepPurple,
                            showValueIndicator: ShowValueIndicator.always,
                          ),
                          child: Slider(
                            value: currentValue.toDouble(),
                            min: minValue,
                            max: maxValue,
                            divisions: divisions,
                            label: '$currentValue / $celebritiesCount',
                            onChanged: (value) {
                              setState(() {
                                _selectedCounts[quiz.id] = value.toInt();
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        '$currentValue/$celebritiesCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 수정 버튼
                    SizedBox(
                      width: 70,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('수정'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        ),
                        onPressed: () => _editQuiz(index),
                      ),
                    ),
                    
                    // 삭제 버튼
                    SizedBox(
                      width: 70,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('삭제'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        ),
                        onPressed: () => _showDeleteConfirmDialog(index),
                      ),
                    ),
                    
                    // 게임 시작 버튼
                    ElevatedButton.icon(
                      onPressed: () => _startQuiz(quiz),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('게임 시작'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 날짜 포맷
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
      builder: (context) => AlertDialog(
        title: const Center(child: Text('퀴즈 삭제')),
        content: const Text('이 퀴즈를 삭제하시겠습니까?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQuiz(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 퀴즈 수정
  void _editQuiz(int index) {
    // 커스텀 퀴즈 화면으로 이동하여 기존 퀴즈 수정
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomQuizScreen(
          quizToEdit: _savedQuizzes[index],
        ),
      ),
    ).then((_) {
      // 화면 복귀 시 퀴즈 목록 새로고침
      _loadSavedQuizzes();
    });
  }
} 