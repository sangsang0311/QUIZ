import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/celebrity.dart';
import '../models/quiz.dart';

class CustomQuizScreen extends StatefulWidget {
  final Quiz? quizToEdit; // 수정할 퀴즈

  const CustomQuizScreen({
    super.key,
    this.quizToEdit,
  });

  @override
  State<CustomQuizScreen> createState() => _CustomQuizScreenState();
}

class _CustomQuizScreenState extends State<CustomQuizScreen> {
  final List<Celebrity> _customCelebrities = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quizTitleController = TextEditingController();
  String? _tempImagePath;
  bool _isSaving = false;
  String? _editingQuizId; // 편집 중인 퀴즈 ID
  
  @override
  void initState() {
    super.initState();
    
    // 기존 퀴즈 로드 (수정 모드)
    if (widget.quizToEdit != null) {
      _editingQuizId = widget.quizToEdit!.id;
      _quizTitleController.text = widget.quizToEdit!.title;
      _customCelebrities.addAll(widget.quizToEdit!.celebrities);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quizTitleController.dispose();
    super.dispose();
  }

  // 이미지 추가 메소드
  Future<void> _addImage() async {
    try {
      if (kIsWeb) {
        // 웹에서는 이미지 선택 후 경고 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("웹에서는 이미지 선택이 제한됩니다. 앱 버전에서 이용해주세요.")),
        );
        return;
      }
      
      // 모바일에서는 정상적으로 이미지 선택
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _tempImagePath = image.path;
        });
        
        // 다이얼로그를 다시 그려서 이미지 미리보기가 즉시 표시되도록 함
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          _addNewCelebrity();
        }
      }
    } catch (e) {
      // 오류 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 불러오는 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 커스텀 정보 추가
  void _addCustomCelebrity() {
    final String name = _nameController.text.trim();
    
    // 정보 추가 (유효성 검사는 이미 _validateAndAddCelebrity에서 완료)
    setState(() {
      _customCelebrities.add(
        Celebrity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          imagePath: _tempImagePath!,
        ),
      );
      
      // 초기화
      _nameController.clear();
      _tempImagePath = null;
    });
  }

  // 정보 삭제
  void _removeCelebrity(int index) {
    setState(() {
      _customCelebrities.removeAt(index);
    });
  }
  
  // 퀴즈 저장 기능 - 삭제 예정
  // _saveCustomQuiz로 대체됨

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        title: const Text('커스텀 퀴즈 만들기'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 설명 텍스트
              const Text(
                '이미지와 이름을 추가하여 나만의 퀴즈를 만들어보세요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '(웹에서는 이미지 업로드 기능이 제한됩니다. 앱에서 이용해주세요.)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // 새 연예인 추가 버튼
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('추가하기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: kIsWeb ? null : _addNewCelebrity,
              ),
              const SizedBox(height: 16),
              
              // 추가된 셀럽 목록
              Expanded(
                child: _customCelebrities.isEmpty
                    ? const Center(
                        child: Text(
                          '추가하기 버튼을 눌러서 정보를 추가해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _customCelebrities.length,
                        itemBuilder: (context, index) {
                          return _buildCelebrityCard(index);
                        },
                      ),
              ),
              
              // 저장 버튼
              if (_customCelebrities.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: _saveCustomQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.deepPurple),
                    ),
                    child: const Text('저장하기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrityCard(int index) {
    final celebrity = _customCelebrities[index];
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _buildCelebrityImage(celebrity.imagePath),
        ),
        title: Text(celebrity.name),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeCelebrity(index),
        ),
      ),
    );
  }
  
  Widget _buildCelebrityImage(String path) {
    if (kIsWeb) {
      // 웹에서는 플레이스홀더 이미지 표시
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey.shade300,
        child: const Icon(Icons.image, color: Colors.grey),
      );
    } else {
      // 앱에서는 파일 이미지 표시
      return Image.file(
        File(path),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }
  }

  void _addNewCelebrity() {
    // 웹에서는 기능 제한
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("웹에서는 이미지 업로드 기능이 제한됩니다. 앱에서 이용해주세요.")),
      );
      return;
    }
    
    // 이미지 선택 및 이름 입력을 위한 다이얼로그 표시
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
      barrierDismissible: false, // 배경 터치로 닫히지 않게
      builder: (context) => AlertDialog(
        // 제목 제거
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이름 입력 필드
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              
              // 선택된 이미지 미리보기
              if (_tempImagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_tempImagePath!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              // 이미지 선택 버튼
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _addImage,
                  icon: const Icon(Icons.photo_library, size: 28),
                  label: const Text(
                    '이미지 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 취소 버튼
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _tempImagePath = null;
                  _nameController.clear();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('취소', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 16),
              // 추가 버튼
              ElevatedButton(
                onPressed: () {
                  _validateAndAddCelebrity(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }
  
  // 입력 유효성 검사 및 추가 메서드
  void _validateAndAddCelebrity(BuildContext dialogContext) {
    final String name = _nameController.text.trim();
    
    if (name.isEmpty) {
      // 이름이 비어있음
      _showToast(dialogContext, '이름을 입력해주세요');
      return;
    }
    
    if (_tempImagePath == null) {
      // 이미지가 선택되지 않음
      _showToast(dialogContext, '이미지를 선택해주세요');
      return;
    }
    
    // 유효성 검사 통과, 실제 추가 진행
    _addCustomCelebrity();
    Navigator.pop(dialogContext); // 다이얼로그 닫기
  }
  
  // 토스트 메시지 표시
  void _showToast(BuildContext context, String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.clearSnackBars();
    
    final snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.5,
        left: 40,
        right: 40,
      ),
      backgroundColor: Colors.deepPurple.shade400,
    );
    
    scaffold.showSnackBar(snackBar);
  }

  void _saveCustomQuiz() async {
    if (_customCelebrities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 인물이 없습니다.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // shared_preferences 인스턴스 가져오기
      final prefs = await SharedPreferences.getInstance();
      
      // 기존 저장된 퀴즈 가져오기
      final List<String>? savedQuizzesJson = prefs.getStringList('saved_quizzes');
      List<Quiz> savedQuizzes = [];
      
      if (savedQuizzesJson != null) {
        savedQuizzes = savedQuizzesJson
            .map((json) => Quiz.fromJson(jsonDecode(json)))
            .toList();
      }
      
      // 퀴즈 제목 입력 받기 (수정 모드면 이미 제목이 설정되어 있음)
      String? quizTitle;
      if (_editingQuizId != null && _quizTitleController.text.isNotEmpty) {
        quizTitle = _quizTitleController.text;
      } else {
        quizTitle = await _getQuizTitle();
      }
      
      if (quizTitle == null || quizTitle.isEmpty) {
        setState(() {
          _isSaving = false;
        });
        return;
      }
      
      // 인물 목록에서 랜덤으로 전체 선택
      final List<Celebrity> selectedCelebrities = List.from(_customCelebrities);
      // 인물 순서는 섞어서 저장 (게임 시작 시 개수 조정은 내가 만든 퀴즈 화면에서 함)
      selectedCelebrities.shuffle();
      
      // 편집 모드인 경우 기존 퀴즈 찾기 및 업데이트
      if (_editingQuizId != null) {
        final int quizIndex = savedQuizzes.indexWhere((q) => q.id == _editingQuizId);
        
        if (quizIndex >= 0) {
          // 기존 퀴즈 정보 업데이트
          final updatedQuiz = Quiz(
            id: _editingQuizId,
            title: quizTitle,
            createdAt: widget.quizToEdit!.createdAt, // 원래 생성일 유지
            celebrities: selectedCelebrities,
          );
          
          // 기존 퀴즈 대체
          savedQuizzes[quizIndex] = updatedQuiz;
        }
      } else {
        // 새 퀴즈 생성
        final newQuiz = Quiz(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: quizTitle,
          createdAt: DateTime.now(),
          celebrities: selectedCelebrities,
        );
        
        // 퀴즈 목록에 추가
        savedQuizzes.add(newQuiz);
      }
      
      // JSON으로 변환하여 저장
      final List<String> quizzesJson = savedQuizzes
          .map((quiz) => jsonEncode(quiz.toJson()))
          .toList();
      
      await prefs.setStringList('saved_quizzes', quizzesJson);
      
      // 저장 완료 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            _editingQuizId != null ? 
              '$quizTitle 퀴즈가 수정되었습니다!' : 
              '$quizTitle 퀴즈가 저장되었습니다!'
          )),
        );
        
        // 저장 후 이전 화면으로 돌아가기
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String?> _getQuizTitle() async {
    final TextEditingController titleController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 제목 입력', textAlign: TextAlign.center),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '퀴즈 제목을 입력해주세요',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('취소', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, titleController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }
} 