import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'package:just_audio/just_audio.dart';
import '../models/custom_quiz.dart';
import '../utils/storage_manager.dart';
import '../utils/sound_manager.dart';

class CreateVoiceQuizScreen extends StatefulWidget {
  final CustomQuiz? quizToEdit;

  const CreateVoiceQuizScreen({
    super.key,
    this.quizToEdit,
  });

  @override
  State<CreateVoiceQuizScreen> createState() => _CreateVoiceQuizScreenState();
}

class _CreateVoiceQuizScreenState extends State<CreateVoiceQuizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final List<Map<String, dynamic>> _questions = []; // {audioPath, answer, volume}

  String? _editingQuizId;
  int? _editingQuestionIndex;
  
  // 탭 호버 애니메이션용
  final Map<int, bool> _tabHoverStates = {};
  
  // 현재 선택된 음성 파일
  String? _selectedAudioPath;
  Uint8List? _selectedAudioBytes;
  double _audioVolume = 1.0; // 기본 볼륨 (0.0 ~ 1.0)
  AudioPlayer? _previewPlayer; // 미리보기용 오디오 플레이어
  Duration? _audioDuration; // 오디오 총 재생 시간
  Duration _currentPosition = Duration.zero; // 현재 재생 위치
  StreamSubscription<Duration>? _positionSubscription; // 위치 스트림 구독
  StreamSubscription<Duration?>? _durationSubscription; // 총 시간 스트림 구독

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
      _categoryController.text = widget.quizToEdit!.title;
      _loadQuizQuestions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryController.dispose();
    _answerController.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _previewPlayer?.dispose();
    super.dispose();
  }
  
  // 시간 포맷팅 (초를 mm:ss 형식으로)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 기존 퀴즈 문제 로드
  void _loadQuizQuestions() {
    if (widget.quizToEdit == null) return;
    
    _questions.clear();
    for (var q in widget.quizToEdit!.questions) {
      _questions.add({
        'audioPath': q.audioPath ?? '',
        'answer': q.answer ?? '',
        'volume': 1.0,
      });
    }
  }

  // 음성 파일 선택
  Future<void> _pickAudioFile() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹 환경에서만 사용 가능합니다.')),
      );
      return;
    }

    try {
      final input = html.FileUploadInputElement()..accept = 'audio/*';
      input.click();

      input.onChange.listen((e) async {
        final file = input.files!.first;
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) async {
          try {
            final bytes = reader.result as Uint8List;
            
            // Base64로 인코딩
            final base64String = base64Encode(bytes);
            
            setState(() {
              _selectedAudioBytes = bytes;
              _selectedAudioPath = 'data:audio/${file.name.split('.').last};base64,$base64String';
            });
          } catch (e) {
            debugPrint('음성 파일 로드 오류: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('음성 파일 로드 중 오류가 발생했습니다: $e')),
              );
            }
          }
        });

        reader.readAsArrayBuffer(file);
      });
    } catch (e) {
      debugPrint('음성 파일 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 파일 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }


  // 음성 미리보기 재생
  Future<void> _previewAudio() async {
    if (_selectedAudioPath == null || _selectedAudioBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 파일을 먼저 선택해주세요.')),
      );
      return;
    }

    try {
      debugPrint('=== 음성 미리보기 재생 시작 ===');
      debugPrint('선택된 오디오 경로 길이: ${_selectedAudioPath!.length}');
      debugPrint('선택된 오디오 경로 시작 부분: ${_selectedAudioPath!.substring(0, _selectedAudioPath!.length > 100 ? 100 : _selectedAudioPath!.length)}...');
      debugPrint('선택된 오디오 바이트 길이: ${_selectedAudioBytes!.length}');
      debugPrint('볼륨: $_audioVolume');
      debugPrint('웹 환경: $kIsWeb');
      
      await _previewPlayer?.dispose();
      _previewPlayer = AudioPlayer();
      debugPrint('오디오 플레이어 생성 완료');
      
      // 파일 확장자에 따라 MIME 타입 결정
      String mimeType = 'audio/mpeg';
      if (_selectedAudioPath != null) {
        if (_selectedAudioPath!.contains('m4a')) {
          mimeType = 'audio/mp4';
        } else if (_selectedAudioPath!.contains('wav')) {
          mimeType = 'audio/wav';
        } else if (_selectedAudioPath!.contains('ogg')) {
          mimeType = 'audio/ogg';
        }
      }
      debugPrint('MIME 타입: $mimeType');
      
      Uint8List? audioDataToPlay = _selectedAudioBytes;
      
      // Flutter Web에서는 Blob URL을 사용
      if (kIsWeb) {
        debugPrint('웹 환경: Blob URL 생성');
        try {
          // Blob 생성
          final blob = html.Blob([audioDataToPlay!]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          debugPrint('Blob URL 생성 완료: $url');
          
          try {
            debugPrint('setUrl 호출 시작: $url');
            await _previewPlayer!.setUrl(url);
            debugPrint('setUrl 호출 완료');
            
            // 재생 완료 후 Blob URL 정리 (별도 리스너로 등록)
            _previewPlayer!.playerStateStream.listen(
              (state) {
                if (state.processingState == ProcessingState.completed) {
                  html.Url.revokeObjectUrl(url);
                  debugPrint('Blob URL 정리 완료');
                }
              },
              onError: (error) {
                debugPrint('플레이어 상태 스트림 오류: $error');
              },
            );
          } catch (e) {
            html.Url.revokeObjectUrl(url);
            debugPrint('setUrl 오류: $e');
            debugPrint('오류 타입: ${e.runtimeType}');
            rethrow;
          }
        } catch (e) {
          debugPrint('Blob URL 생성 오류: $e');
          debugPrint('오류 타입: ${e.runtimeType}');
          rethrow;
        }
      } else {
        debugPrint('모바일 환경: LockCachingAudioSource 사용');
        // 모바일에서는 LockCachingAudioSource 사용
        // 모바일에서는 증폭이 제한적이므로 볼륨만 조절
        await _previewPlayer!.setAudioSource(
          LockCachingAudioSource(
            Uri.dataFromBytes(
              audioDataToPlay!,
              mimeType: mimeType,
            ),
          ),
        );
        debugPrint('setAudioSource 호출 완료');
      }
      
      // 총 재생 시간 가져오기
      _durationSubscription?.cancel();
      _durationSubscription = _previewPlayer!.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _audioDuration = duration;
          });
          debugPrint('오디오 총 재생 시간: ${_formatDuration(duration)}');
        }
      });
      
      // 현재 재생 위치 업데이트
      _positionSubscription?.cancel();
      _positionSubscription = _previewPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });
      
      debugPrint('볼륨 설정 중...');
      await _previewPlayer!.setVolume(_audioVolume);
      debugPrint('볼륨 설정 완료: $_audioVolume');
      
      debugPrint('재생 시작...');
      await _previewPlayer!.play();
      debugPrint('재생 명령 완료');
      
      // 재생 상태 확인 (통합 리스너)
      _previewPlayer!.playerStateStream.listen((state) {
        debugPrint('플레이어 상태 변경: ${state.processingState}, 재생 중: ${state.playing}');
        if (state.processingState == ProcessingState.idle) {
          debugPrint('오디오 상태: idle');
        } else if (state.processingState == ProcessingState.loading) {
          debugPrint('오디오 로딩 중...');
        } else if (state.processingState == ProcessingState.ready) {
          debugPrint('오디오 준비 완료');
        } else if (state.processingState == ProcessingState.buffering) {
          debugPrint('오디오 버퍼링 중...');
        } else if (state.processingState == ProcessingState.completed) {
          debugPrint('오디오 재생 완료');
          if (mounted) {
            setState(() {
              _currentPosition = Duration.zero;
            });
          }
        }
      });
      
      _previewPlayer!.playingStream.listen((playing) {
        debugPrint('재생 중 상태 변경: $playing');
      });
      
    } catch (e, stackTrace) {
      debugPrint('=== 음성 미리보기 재생 오류 ===');
      debugPrint('오류 메시지: $e');
      debugPrint('오류 타입: ${e.runtimeType}');
      debugPrint('스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 재생 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 문제 추가
  void _addQuestion() {
    if (_selectedAudioPath == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 파일과 정답을 모두 입력해주세요.')),
      );
      return;
    }
    
    setState(() {
      if (_editingQuestionIndex != null) {
        // 수정 모드
        _questions[_editingQuestionIndex!] = {
          'audioPath': _selectedAudioPath!,
          'answer': _answerController.text.trim(),
          'volume': _audioVolume,
        };
        _editingQuestionIndex = null;
      } else {
        // 추가 모드
        _questions.add({
          'audioPath': _selectedAudioPath!,
          'answer': _answerController.text.trim(),
          'volume': _audioVolume,
        });
      }
      
      // 초기화
      _selectedAudioPath = null;
      _selectedAudioBytes = null;
      _answerController.clear();
      _audioVolume = 1.0;
      
      // 팝업창 중간에 토스트 메시지 표시
      _showToastMessage('추가 되었습니다.');
    });
  }

  // 문제 수정
  void _editQuestion(int index) {
    final question = _questions[index];
    setState(() {
      _editingQuestionIndex = index;
      _selectedAudioPath = question['audioPath'] as String?;
      _answerController.text = question['answer'] as String;
      _audioVolume = question['volume'] as double? ?? 1.0;
      _tabController.animateTo(1); // 문제 추가 탭으로 이동
    });
  }

  // 문제 삭제
  void _removeQuestion(int index) {
    _showDeleteConfirmDialog(index);
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(int index) {
    showDialog(
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
                '문제 삭제',
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
                '이 문제를 삭제하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '삭제된 문제는 복구할 수 없습니다.',
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
                          Navigator.pop(context);
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
                          Navigator.pop(context);
                          setState(() {
                            _questions.removeAt(index);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade300.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

    // 모든 문제에 음성 파일과 정답이 있는지 확인
    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i]['audioPath'] == null || _questions[i]['audioPath'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}번 문제의 음성 파일을 선택해주세요.')),
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

    try {
      // StorageManager 초기화 확인
      await StorageManager.init();
      
      final questions = _questions.map((q) {
        return CustomQuizQuestion(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_questions.indexOf(q)}',
          audioPath: q['audioPath'],
          answer: q['answer'],
        );
      }).toList();
      
      CustomQuiz quizToSave;
      if (_editingQuizId != null) {
        // 수정 모드
        final existingQuizzes = await StorageManager.loadQuizzes(quizType: 'voice');
        final existingQuiz = existingQuizzes.firstWhere(
          (q) => q.id == _editingQuizId,
          orElse: () => CustomQuiz(
            id: _editingQuizId!,
            quizType: 'voice',
            title: _categoryController.text.trim(),
            questions: [],
            createdAt: DateTime.now(),
          ),
        );
        
        quizToSave = CustomQuiz(
          id: _editingQuizId!,
          quizType: 'voice',
          title: _categoryController.text.trim(),
          questions: questions,
          createdAt: existingQuiz.createdAt,
        );
      } else {
        // 새 퀴즈
        quizToSave = CustomQuiz(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          quizType: 'voice',
          title: _categoryController.text.trim(),
          questions: questions,
          createdAt: DateTime.now(),
        );
      }
      
      await StorageManager.saveQuiz(quizToSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈가 저장되었습니다.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
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
            color: Color(0xFFF57C00),
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
              borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
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
              backgroundColor: const Color(0xFFF57C00),
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
            color: Color(0xFFF57C00),
          ),
        ),
        const SizedBox(height: 24),
        // 음성 파일 선택 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickAudioFile,
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text(
              '음성 파일 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 선택된 음성 파일 표시
        if (_selectedAudioPath != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF57C00), width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Color(0xFFF57C00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '음성 파일이 선택되었습니다',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // 재생 시간 표시
                    if (_audioDuration != null)
                      Text(
                        '${_formatDuration(_currentPosition)} / ${_formatDuration(_audioDuration!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.play_circle, color: Color(0xFFF57C00)),
                      onPressed: _previewAudio,
                      tooltip: '미리보기 재생',
                    ),
                  ],
                ),
                // 재생 진행 바
                if (_audioDuration != null && _audioDuration!.inSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentPosition.inMilliseconds / _audioDuration!.inMilliseconds,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF57C00)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        // 정답 입력 필드
        TextField(
          controller: _answerController,
          maxLength: 20, // 최대 20자 제한
          decoration: InputDecoration(
            labelText: '정답',
            hintText: '정답을 입력하세요 (최대 20자)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: '', // 글자 수 카운터 숨기기
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 24),
        // 볼륨 조절
        const Text(
          '음성 볼륨',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_down, color: Color(0xFFF57C00)),
            Expanded(
              child: Slider(
                value: _audioVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10, // 10% 단위
                label: '${(_audioVolume * 100).toInt()}%',
                activeColor: const Color(0xFFF57C00),
                onChanged: (value) {
                  setState(() {
                    _audioVolume = (value * 10).round() / 10.0; // 10% 단위로 반올림
                    // 재생 중이면 볼륨 업데이트
                    if (_previewPlayer != null) {
                      _previewPlayer!.setVolume(_audioVolume);
                    }
                  });
                },
              ),
            ),
            const Icon(Icons.volume_up, color: Color(0xFFF57C00)),
            const SizedBox(width: 8),
            Text(
              '${(_audioVolume * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF57C00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedAudioPath != null &&
                    _answerController.text.trim().isNotEmpty
                ? _addQuestion
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
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
                color: Color(0xFFF57C00),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF57C00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_questions.length}개',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF57C00),
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
            onPressed: _questions.length >= 3 ? _saveQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              _questions.length >= 3
                  ? '퀴즈 저장 (${_questions.length}개)'
                  : '최소 3개 이상 추가해주세요',
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
                    icon: const Icon(Icons.edit, color: Color(0xFFF57C00)),
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
          Row(
            children: [
              const Icon(Icons.audiotrack, size: 16, color: Color(0xFFF57C00)),
              const SizedBox(width: 4),
              const Text(
                '음성 파일: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              Text(
                question['audioPath'] != null ? '선택됨' : '없음',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: question['audioPath'] != null ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '정답: ${question['answer']}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF57C00),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '볼륨: ${((question['volume'] as double? ?? 1.0) * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
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
            color: const Color(0xFFF57C00), // 주황색 계열
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
                  '음성 퀴즈 만들기',
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
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Color(0xFFF57C00)),
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
                indicatorColor: const Color(0xFFF57C00),
                indicatorWeight: 3,
                labelColor: const Color(0xFFF57C00),
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
