import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/custom_quiz.dart';
import '../utils/storage_manager.dart';
import '../utils/sound_manager.dart';
import 'dart:html' as html if (dart.library.html) 'dart:html';

// 가이드라인 그리기용 CustomPainter
class GuideLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // 가로 중앙선
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    
    // 세로 중앙선
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CreateImageQuizScreen extends StatefulWidget {
  final String? category;
  final CustomQuiz? quizToEdit;

  const CreateImageQuizScreen({
    super.key,
    this.category,
    this.quizToEdit,
  });

  @override
  State<CreateImageQuizScreen> createState() => _CreateImageQuizScreenState();
}

class _CreateImageQuizScreenState extends State<CreateImageQuizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final List<Map<String, dynamic>> _questions = [];
  final ImagePicker _picker = ImagePicker();
  
  // 현재 편집 중인 이미지
  String? _currentImagePath; // Base64 문자열 또는 파일 경로
  Uint8List? _currentImageBytes; // 디코딩된 이미지 바이트
  
  // 이미지 위치/크기 (비율: 0.0 ~ 1.0)
  double _imageTopRatio = 0.0;
  double _imageLeftRatio = 0.0;
  double _imageWidthRatio = 0.5;
  double _imageHeightRatio = 0.324;
  double? _originalImageAspectRatio;
  
  // 기준 해상도 (16:9)
  static const double _referenceAspectRatio = 1920.0 / 1080.0;
  
  String? _editingQuizId;
  int? _editingQuestionIndex;
  bool _isSaving = false; // 저장 중 상태
  
  // 탭 호버 애니메이션용
  final Map<int, bool> _tabHoverStates = {};
  
  // 이미지 선택 및 리사이즈 상태
  bool _isImageSelected = false;
  String? _resizeHandle; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight', 'top', 'bottom', 'left', 'right', null
  Offset? _resizeStartPoint;
  Offset? _resizeStartGlobalPoint; // 리사이즈 시작 시 globalPosition
  double? _resizeStartWidth;
  double? _resizeStartHeight;
  double? _resizeStartLeft;
  double? _resizeStartTop;
  bool _showGuideLines = false; // 가이드라인 표시 여부
  
  // 이미지 자르기 상태
  bool _isCropMode = false; // 자르기 모드 활성화 여부
  Rect? _cropArea; // 자를 영역 (이미지 좌표 기준, 비율: 0.0 ~ 1.0)
  String? _cropResizeHandle; // 자르기 영역 리사이즈 핸들 ('topLeft', 'topRight', 'bottomLeft', 'bottomRight', null)
  Offset? _cropResizeStartPoint;
  Offset? _cropResizeStartGlobalPoint; // 리사이즈 시작 시 globalPosition
  Rect? _cropResizeStartArea;

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
    _answerController.dispose();
    super.dispose();
  }

  // 기존 퀴즈 문제 로드
  Future<void> _loadQuizQuestions() async {
    if (widget.quizToEdit == null) return;
    
    _questions.clear();
    for (var q in widget.quizToEdit!.questions) {
      String? imagePath = q.imagePath;
      Uint8List? imageBytes;
      
      // Base64 문자열을 디코딩
      // Base64 문자열은 매우 길고, 파일 경로가 아닌 경우 (data:image 같은 prefix가 있거나, 순수 Base64)
      if (imagePath != null && imagePath.length > 100) {
        // data:image/png;base64, 같은 prefix 제거
        String? base64String = imagePath;
        if (imagePath.startsWith('data:image')) {
          final commaIndex = imagePath.indexOf(',');
          if (commaIndex != -1) {
            base64String = imagePath.substring(commaIndex + 1);
          }
        }
        
        // 파일 경로가 아닌 경우 (\\가 없고, 파일 시스템 경로 패턴이 아닌 경우)
        // Base64 문자열은 /를 포함할 수 있으므로, /로 시작하거나 :/ 패턴이 있는지만 체크
        final isFilePath = base64String != null && (
          base64String.contains('\\') || 
          base64String.startsWith('/') || 
          base64String.contains(':/') ||
          base64String.contains('C:') ||
          base64String.contains('D:')
        );
        
        if (base64String != null && !isFilePath) {
          try {
            imageBytes = base64Decode(base64String);
            debugPrint('Base64 디코딩 성공: ${imageBytes.length} bytes');
          } catch (e) {
            debugPrint('이미지 디코딩 오류: $e');
          }
        }
      }
      
      if (imageBytes == null && imagePath != null && !kIsWeb) {
        // 모바일에서 파일 경로
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            imageBytes = await file.readAsBytes();
          }
        } catch (e) {
          debugPrint('파일 읽기 오류: $e');
        }
      }
      
      setState(() {
        _questions.add({
          'imagePath': imagePath,
          'imageBytes': imageBytes,
          'answer': q.answer,
          'imageTop': q.imageTop ?? 0.0,
          'imageLeft': q.imageLeft ?? 0.0,
          'imageWidth': q.imageWidth ?? 0.5,
          'imageHeight': q.imageHeight ?? 0.324,
        });
      });
    }
  }

  // 이미지 선택
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // 이미지 품질 유지
      );

      if (image != null) {
        Uint8List bytes = await image.readAsBytes();
        
        // 원본 이미지 비율 확인
        if (kIsWeb) {
          final imageInfo = await _getImageInfo(bytes);
          if (imageInfo != null && imageInfo['width'] != null && imageInfo['height'] != null) {
            _originalImageAspectRatio = imageInfo['width']! / imageInfo['height']!;
            // 웹에서 큰 이미지일 때만 리사이즈 (1920x1080 이상일 때만)
            int originalWidth = imageInfo['width']!;
            int originalHeight = imageInfo['height']!;
            if (originalWidth > 1920 || originalHeight > 1080) {
              bytes = await _resizeImageForWeb(bytes, maxWidth: 1920, maxHeight: 1080);
            }
          }
        } else {
          try {
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final decodedImage = frame.image;
            _originalImageAspectRatio = decodedImage.width / decodedImage.height;
          } catch (e) {
            debugPrint('이미지 디코딩 오류: $e');
          }
        }
        
        // Base64로 인코딩
        final base64String = base64Encode(bytes);
        
        // 초기 위치/크기 설정
        if (_originalImageAspectRatio != null) {
          final screenWidth = MediaQuery.of(context).size.width;
          final availableWidth = screenWidth * 0.60;
          final previewWidth = availableWidth.clamp(400.0, 800.0);
          final previewHeight = previewWidth / _referenceAspectRatio;
          
          final maxImageWidth = previewWidth * 1.0;
          final maxImageHeight = previewHeight * 1.0;
          
          double imageWidth = maxImageWidth;
          double imageHeight = imageWidth / _originalImageAspectRatio!;
          
          if (imageHeight > maxImageHeight) {
            imageHeight = maxImageHeight;
            imageWidth = imageHeight * _originalImageAspectRatio!;
          }
          
          _imageWidthRatio = (imageWidth / previewWidth).clamp(0.0, 1.0);
          _imageHeightRatio = (imageHeight / previewHeight).clamp(0.0, 1.0);
          _imageLeftRatio = ((previewWidth - imageWidth) / 2 / previewWidth).clamp(0.0, 1.0 - _imageWidthRatio);
          _imageTopRatio = ((previewHeight - imageHeight) / 2 / previewHeight).clamp(0.0, 1.0 - _imageHeightRatio);
          
          debugPrint('[PICK_IMAGE] Image loaded - aspectRatio: $_originalImageAspectRatio, previewSize: (${previewWidth.toStringAsFixed(1)}, ${previewHeight.toStringAsFixed(1)}), imageSize: (${imageWidth.toStringAsFixed(1)}, ${imageHeight.toStringAsFixed(1)}), ratios: (${_imageWidthRatio.toStringAsFixed(3)}, ${_imageHeightRatio.toStringAsFixed(3)}, ${_imageLeftRatio.toStringAsFixed(3)}, ${_imageTopRatio.toStringAsFixed(3)})');
        } else {
          debugPrint('[PICK_IMAGE] Image loaded but _originalImageAspectRatio is null!');
        }
        
        setState(() {
          _currentImagePath = base64String;
          _currentImageBytes = bytes;
          _isImageSelected = false;
          _resizeHandle = null;
          debugPrint('[PICK_IMAGE] Image state updated - _currentImageBytes: ${bytes.length} bytes, _isImageSelected: false');
        });
      }
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 웹에서 이미지 정보 가져오기
  Future<Map<String, int>?> _getImageInfo(Uint8List bytes) async {
    if (!kIsWeb) return null;
    
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement();
      
      final completer = Completer<Map<String, int>?>();
      img.onLoad.listen((_) {
        completer.complete({'width': img.width!, 'height': img.height!});
        html.Url.revokeObjectUrl(url);
      });
      img.onError.listen((_) {
        completer.complete(null);
        html.Url.revokeObjectUrl(url);
      });
      
      img.src = url;
      return await completer.future;
    } catch (e) {
      debugPrint('이미지 정보 가져오기 오류: $e');
      return null;
    }
  }

  // 웹에서 이미지 리사이즈
  Future<Uint8List> _resizeImageForWeb(Uint8List imageBytes, {int maxWidth = 1280, int maxHeight = 720}) async {
    if (!kIsWeb) return imageBytes;
    
    try {
      final blob = html.Blob([imageBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement();
      
      final completer = Completer<Uint8List>();
      
      img.onLoad.listen((_) async {
        try {
          int originalWidth = img.width!;
          int originalHeight = img.height!;
          
          double scale = (maxWidth / originalWidth).clamp(0.0, 1.0);
          if (originalHeight * scale > maxHeight) {
            scale = (maxHeight / originalHeight).clamp(0.0, 1.0);
          }
          
          int newWidth = (originalWidth * scale).round();
          int newHeight = (originalHeight * scale).round();
          
          if (newWidth >= originalWidth && newHeight >= originalHeight) {
            html.Url.revokeObjectUrl(url);
            completer.complete(imageBytes);
            return;
          }
          
          // PNG인지 확인
          final isPng = imageBytes.length >= 8 && 
                        imageBytes[0] == 0x89 && 
                        imageBytes[1] == 0x50 && 
                        imageBytes[2] == 0x4E && 
                        imageBytes[3] == 0x47;
          
          final mimeType = isPng ? 'image/png' : 'image/jpeg';
          final quality = isPng ? 1.0 : 0.9; // 이미지 품질 유지
          
          final canvas = html.CanvasElement(width: newWidth, height: newHeight);
          final ctx = canvas.context2D;
          ctx.clearRect(0, 0, newWidth, newHeight);
          ctx.drawImageScaled(img, 0, 0, newWidth, newHeight);
          
          canvas.toBlob(mimeType, quality).then((blob) {
            final reader = html.FileReader();
            reader.onLoadEnd.listen((_) {
              final result = reader.result as Uint8List;
              html.Url.revokeObjectUrl(url);
              completer.complete(result);
            });
            reader.readAsArrayBuffer(blob!);
          });
        } catch (e) {
          html.Url.revokeObjectUrl(url);
          completer.complete(imageBytes);
        }
      });
      
      img.onError.listen((_) {
        html.Url.revokeObjectUrl(url);
        completer.complete(imageBytes);
      });
      
      img.src = url;
      return await completer.future;
    } catch (e) {
      debugPrint('이미지 리사이즈 오류: $e');
      return imageBytes;
    }
  }

  // 문제 추가
  void _addQuestion() {
    if (_currentImagePath == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지와 정답을 모두 입력해주세요.')),
      );
      return;
    }
    
    // 디버그 로그
    debugPrint('문제 추가/수정: imagePath=${_currentImagePath != null ? "있음 (${_currentImagePath!.length} chars)" : "null"}, imageBytes=${_currentImageBytes != null ? "있음 (${_currentImageBytes!.length} bytes)" : "null"}');
    
    setState(() {
      if (_editingQuestionIndex != null) {
        // 수정 모드
        debugPrint('문제 수정 모드: index=$_editingQuestionIndex');
        _questions[_editingQuestionIndex!] = {
          'imagePath': _currentImagePath,
          'imageBytes': _currentImageBytes,
          'answer': _answerController.text.trim(),
          'imageTop': _imageTopRatio,
          'imageLeft': _imageLeftRatio,
          'imageWidth': _imageWidthRatio,
          'imageHeight': _imageHeightRatio,
        };
        debugPrint('문제 수정 완료: imagePath=${_questions[_editingQuestionIndex!]['imagePath'] != null ? "있음" : "null"}');
        _editingQuestionIndex = null;
      } else {
        // 추가 모드
        debugPrint('문제 추가 모드');
        _questions.add({
          'imagePath': _currentImagePath,
          'imageBytes': _currentImageBytes,
          'answer': _answerController.text.trim(),
          'imageTop': _imageTopRatio,
          'imageLeft': _imageLeftRatio,
          'imageWidth': _imageWidthRatio,
          'imageHeight': _imageHeightRatio,
        });
        debugPrint('문제 추가 완료: 총 ${_questions.length}개, 마지막 문제 imagePath=${_questions.last['imagePath'] != null ? "있음" : "null"}');
      }
      
      // 초기화
      _currentImagePath = null;
      _currentImageBytes = null;
      _answerController.clear();
      _imageTopRatio = 0.0;
      _imageLeftRatio = 0.0;
      _imageWidthRatio = 0.5;
      _imageHeightRatio = 0.324;
      _originalImageAspectRatio = null;
      _isImageSelected = false;
      _resizeHandle = null;
      
      // 팝업창 중간에 토스트 메시지 표시
      _showToastMessage('추가 되었습니다.');
    });
  }

  // 이미지 비율 계산 (공통 함수)
  Future<void> _calculateImageAspectRatio(Uint8List bytes) async {
    if (kIsWeb) {
      final imageInfo = await _getImageInfo(bytes);
      if (imageInfo != null && imageInfo['width'] != null && imageInfo['height'] != null) {
        _originalImageAspectRatio = imageInfo['width']! / imageInfo['height']!;
        debugPrint('[EDIT_QUESTION] Image aspect ratio calculated: $_originalImageAspectRatio');
      }
    } else {
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final decodedImage = frame.image;
        _originalImageAspectRatio = decodedImage.width / decodedImage.height;
        debugPrint('[EDIT_QUESTION] Image aspect ratio calculated: $_originalImageAspectRatio');
      } catch (e) {
        debugPrint('이미지 디코딩 오류: $e');
      }
    }
  }

  // 문제 수정
  void _editQuestion(int index) async {
    final question = _questions[index];
    
    // 디버그 로그
    final imagePath = question['imagePath'] != null ? question['imagePath'] as String : null;
    final imageBytes = question['imageBytes'] != null ? question['imageBytes'] as Uint8List : null;
    debugPrint('문제 수정 시작: index=$index, imagePath=${imagePath != null ? "있음 (${imagePath.length} chars)" : "null"}, imageBytes=${imageBytes != null ? "있음 (${imageBytes.length} bytes)" : "null"}');
    
    // 이미지 비율 계산
    if (imageBytes != null) {
      await _calculateImageAspectRatio(imageBytes);
    }
    
    setState(() {
      _editingQuestionIndex = index;
      _currentImagePath = imagePath;
      _currentImageBytes = imageBytes;
      _answerController.text = question['answer'] as String;
      _imageTopRatio = question['imageTop'] != null ? (question['imageTop'] as num).toDouble() : 0.0;
      _imageLeftRatio = question['imageLeft'] != null ? (question['imageLeft'] as num).toDouble() : 0.0;
      _imageWidthRatio = question['imageWidth'] != null ? (question['imageWidth'] as num).toDouble() : 0.5;
      _imageHeightRatio = question['imageHeight'] != null ? (question['imageHeight'] as num).toDouble() : 0.324;
      _isImageSelected = false;
      _resizeHandle = null;
      _tabController.animateTo(1); // 문제 추가 탭으로 이동
    });
  }

  // 문제 삭제
  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
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
                          _removeQuestion(index);
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
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // StorageManager 초기화 확인
      await StorageManager.init();
      
      final category = _categoryController.text.trim();
      final questions = _questions.map((q) {
        // imageBytes가 있으면 Base64로 인코딩, 없으면 imagePath 사용
        String? imageData;
        if (q['imageBytes'] != null) {
          Uint8List imageBytes = q['imageBytes'] as Uint8List;
          // 이미지 크기 체크 (50MB 제한 - IndexedDB/SQLite는 대용량 지원)
          if (imageBytes.length > 50 * 1024 * 1024) {
            throw Exception('이미지가 너무 큽니다. 더 작은 이미지를 사용해주세요.');
          }
          imageData = base64Encode(imageBytes);
        } else if (q['imagePath'] != null) {
          imageData = q['imagePath'];
        }
        
        return CustomQuizQuestion(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_questions.indexOf(q)}',
          imagePath: imageData,
          answer: q['answer'],
          imageTop: q['imageTop'],
          imageLeft: q['imageLeft'],
          imageWidth: q['imageWidth'],
          imageHeight: q['imageHeight'],
        );
      }).toList();
      
      CustomQuiz quizToSave;
      if (_editingQuizId != null) {
        // 수정 모드 - 기존 퀴즈 로드해서 createdAt 유지
        final existingQuizzes = await StorageManager.loadQuizzes(quizType: 'image');
        final existingQuiz = existingQuizzes.firstWhere(
          (q) => q.id == _editingQuizId,
          orElse: () => CustomQuiz(
            id: _editingQuizId!,
            quizType: 'image',
            title: category,
            category: category,
            questions: [],
            createdAt: DateTime.now(),
          ),
        );
        
        quizToSave = CustomQuiz(
          id: _editingQuizId!,
          quizType: 'image',
          title: category,
          category: category,
          questions: questions,
          createdAt: existingQuiz.createdAt,
        );
      } else {
        // 새 퀴즈
        quizToSave = CustomQuiz(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          quizType: 'image',
          title: category,
          category: category,
          questions: questions,
          createdAt: DateTime.now(),
        );
      }
      
      // StorageManager를 사용하여 저장
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
      debugPrint('저장 오류: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        String errorMessage = '저장 중 오류가 발생했습니다.';
        if (e.toString().contains('QuotaExceededError') || e.toString().contains('exceeded the quota')) {
          errorMessage = '저장 공간이 부족합니다.\n기존 퀴즈를 삭제하거나 더 작은 이미지를 사용해주세요.';
        } else if (e.toString().contains('너무 큽니다')) {
          errorMessage = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // 이미지 위젯 빌드
  Widget _buildImageWidget(String? imagePath, Uint8List? imageBytes, {double? height, double? width}) {
    debugPrint('_buildImageWidget 호출: imagePath=${imagePath != null ? "있음 (${imagePath.length} chars)" : "null"}, imageBytes=${imageBytes != null ? "있음 (${imageBytes.length} bytes)" : "null"}');
    
    // imageBytes가 있으면 우선 사용
    if (imageBytes != null && imageBytes.isNotEmpty) {
      debugPrint('imageBytes 사용하여 이미지 표시');
      return SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: Image.memory(
          imageBytes,
          fit: BoxFit.fill, // 비율 무시하고 선택한 크기에 맞춰 왜곡
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Image.memory 오류: $error');
            // 오류 발생 시 imagePath로 재시도
            if (imagePath != null) {
              debugPrint('imagePath로 재시도');
              return _buildImageWidgetFromPath(imagePath, height: height, width: width);
            }
            return Container(
              height: height,
              width: width ?? double.infinity,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      );
    }
    
    // imagePath가 있으면 처리
    if (imagePath != null) {
      debugPrint('imagePath 사용하여 이미지 표시');
      return _buildImageWidgetFromPath(imagePath, height: height, width: width);
    }
    
    // 이미지 없음
    debugPrint('이미지 없음 - placeholder 표시');
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // imagePath로부터 이미지 위젯 빌드
  Widget _buildImageWidgetFromPath(String imagePath, {double? height, double? width}) {
    debugPrint('_buildImageWidgetFromPath 호출: imagePath 길이=${imagePath.length}, contains(/)=${imagePath.contains('/')}, contains(\\\\)=${imagePath.contains('\\')}');
    
    // Base64 문자열인 경우
    // Base64 문자열은 매우 길고, 파일 경로가 아닌 경우
    if (imagePath.length > 100) {
      // data:image/png;base64, 같은 prefix 제거
      String? base64String = imagePath;
      if (imagePath.startsWith('data:image')) {
        final commaIndex = imagePath.indexOf(',');
        if (commaIndex != -1) {
          base64String = imagePath.substring(commaIndex + 1);
          debugPrint('data:image prefix 제거: ${base64String.length} chars');
        }
      }
      
      // 파일 경로가 아닌 경우 (\\가 없고, 파일 시스템 경로 패턴이 아닌 경우)
      // Base64 문자열은 /를 포함할 수 있으므로, /로 시작하거나 :/ 패턴이 있는지만 체크
      final isFilePath = base64String != null && (
        base64String.contains('\\') || 
        base64String.startsWith('/') || 
        base64String.contains(':/') ||
        base64String.contains('C:') ||
        base64String.contains('D:')
      );
      
      if (base64String != null && !isFilePath) {
        debugPrint('Base64 문자열로 인식, 디코딩 시도...');
        try {
          final bytes = base64Decode(base64String);
          debugPrint('Base64 디코딩 성공: ${bytes.length} bytes');
          return SizedBox(
            height: height,
            width: width ?? double.infinity,
            child: Image.memory(
              bytes,
              fit: BoxFit.fill, // 비율 무시하고 선택한 크기에 맞춰 왜곡
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Base64 Image.memory 오류: $error');
                return Container(
                  height: height,
                  width: width ?? double.infinity,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              },
            ),
          );
        } catch (e, stackTrace) {
          debugPrint('Base64 디코딩 오류: $e');
          debugPrint('스택 트레이스: $stackTrace');
        }
      } else {
        debugPrint('파일 경로로 인식: \\ 포함=${base64String?.contains('\\')}, /로 시작=${base64String?.startsWith('/')}, :/ 포함=${base64String?.contains(':/')}');
      }
    } else {
      debugPrint('Base64 문자열이 아님: 길이=${imagePath.length} (100 이하)');
    }
    
    // 모바일에서 파일 경로인 경우
    if (!kIsWeb) {
      return SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: Image.file(
          File(imagePath),
          fit: BoxFit.fill, // 비율 무시하고 선택한 크기에 맞춰 왜곡
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Image.file 오류: $error');
            return Container(
              height: height,
              width: width ?? double.infinity,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      );
    }
    
    // 이미지 없음
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // 자르기 오버레이 UI (이미지 영역에만 적용)
  Widget _buildCropOverlay(double previewWidth, double previewHeight) {
    final imageLeft = previewWidth * _imageLeftRatio.clamp(0.0, 1.0);
    final imageTop = previewHeight * _imageTopRatio.clamp(0.0, 1.0);
    final imageWidth = previewWidth * _imageWidthRatio.clamp(0.2, 1.0);
    final imageHeight = previewHeight * _imageHeightRatio.clamp(0.2, 1.0);
    
    // 자를 영역이 없으면 기본값 설정 (이미지 전체)
    if (_cropArea == null) {
      _cropArea = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    }
    
    // 이미지 좌표 기준으로 자를 영역 계산
    final cropLeft = imageLeft + (_cropArea!.left * imageWidth);
    final cropTop = imageTop + (_cropArea!.top * imageHeight);
    final cropWidth = _cropArea!.width * imageWidth;
    final cropHeight = _cropArea!.height * imageHeight;
    
    return Stack(
      children: [
        // 이미지 전체에 반투명 오버레이
        Positioned(
          left: imageLeft,
          top: imageTop,
          child: Container(
            width: imageWidth,
            height: imageHeight,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // 자를 영역 (밝게 표시 - 남길 부분)
        Positioned(
          left: cropLeft,
          top: cropTop,
          child: Container(
            width: cropWidth,
            height: cropHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: Container(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        // 자르기 영역 리사이즈 핸들들 (모서리)
        _buildCropResizeHandle(
          'topLeft',
          cropLeft,
          cropTop,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'topRight',
          cropLeft + cropWidth - 12,
          cropTop,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'bottomLeft',
          cropLeft,
          cropTop + cropHeight - 12,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'bottomRight',
          cropLeft + cropWidth - 12,
          cropTop + cropHeight - 12,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        // 자르기 영역 리사이즈 핸들들 (변 중앙)
        _buildCropResizeHandle(
          'top',
          cropLeft + (cropWidth - 12) / 2,
          cropTop,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'bottom',
          cropLeft + (cropWidth - 12) / 2,
          cropTop + cropHeight - 12,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'left',
          cropLeft,
          cropTop + (cropHeight - 12) / 2,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
        _buildCropResizeHandle(
          'right',
          cropLeft + cropWidth - 12,
          cropTop + (cropHeight - 12) / 2,
          previewWidth,
          previewHeight,
          imageLeft,
          imageTop,
          imageWidth,
          imageHeight,
        ),
      ],
    );
  }
  
  // 자르기 영역 리사이즈 핸들
  Widget _buildCropResizeHandle(
    String handleType,
    double left,
    double top,
    double previewWidth,
    double previewHeight,
    double imageLeft,
    double imageTop,
    double imageWidth,
    double imageHeight,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() {
            _cropResizeHandle = handleType;
            _cropResizeStartPoint = details.localPosition;
            _cropResizeStartGlobalPoint = details.globalPosition;
            _cropResizeStartArea = _cropArea;
          });
        },
        onPanUpdate: (details) {
          if (_cropResizeHandle != handleType || _cropResizeStartArea == null) return;
          
          setState(() {
            // globalPosition을 사용하여 시작 위치에서의 총 이동량 계산
            final totalDelta = details.globalPosition - (_cropResizeStartGlobalPoint ?? Offset.zero);
            // 이미지 비율로 변환 (조절 감도 조정)
            final deltaX = (totalDelta.dx / imageWidth);
            final deltaY = (totalDelta.dy / imageHeight);
            
            double newLeft = _cropResizeStartArea!.left;
            double newTop = _cropResizeStartArea!.top;
            double newRight = _cropResizeStartArea!.right;
            double newBottom = _cropResizeStartArea!.bottom;
            
            switch (handleType) {
              case 'topLeft':
                newLeft = (_cropResizeStartArea!.left + deltaX).clamp(0.0, newRight - 0.05);
                newTop = (_cropResizeStartArea!.top + deltaY).clamp(0.0, newBottom - 0.05);
                break;
              case 'topRight':
                newRight = (_cropResizeStartArea!.right + deltaX).clamp(newLeft + 0.05, 1.0);
                newTop = (_cropResizeStartArea!.top + deltaY).clamp(0.0, newBottom - 0.05);
                break;
              case 'bottomLeft':
                newLeft = (_cropResizeStartArea!.left + deltaX).clamp(0.0, newRight - 0.05);
                newBottom = (_cropResizeStartArea!.bottom + deltaY).clamp(newTop + 0.05, 1.0);
                break;
              case 'bottomRight':
                newRight = (_cropResizeStartArea!.right + deltaX).clamp(newLeft + 0.05, 1.0);
                newBottom = (_cropResizeStartArea!.bottom + deltaY).clamp(newTop + 0.05, 1.0);
                break;
              case 'top':
                // 상단 중앙: 세로만 조절
                newTop = (_cropResizeStartArea!.top + deltaY).clamp(0.0, newBottom - 0.05);
                break;
              case 'bottom':
                // 하단 중앙: 세로만 조절
                newBottom = (_cropResizeStartArea!.bottom + deltaY).clamp(newTop + 0.05, 1.0);
                break;
              case 'left':
                // 좌측 중앙: 가로만 조절
                newLeft = (_cropResizeStartArea!.left + deltaX).clamp(0.0, newRight - 0.05);
                break;
              case 'right':
                // 우측 중앙: 가로만 조절
                newRight = (_cropResizeStartArea!.right + deltaX).clamp(newLeft + 0.05, 1.0);
                break;
            }
            
            _cropArea = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
          });
        },
        onPanEnd: (_) {
          setState(() {
            _cropResizeHandle = null;
            _cropResizeStartPoint = null;
            _cropResizeStartGlobalPoint = null;
            _cropResizeStartArea = null;
          });
        },
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF1976D2),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 이미지 자르기 함수
  Future<void> _cropImage() async {
    if (_cropArea == null || _currentImageBytes == null) return;
    
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final availableWidth = screenWidth * 0.60;
      final previewWidth = availableWidth.clamp(400.0, 600.0);
      final previewHeight = previewWidth / _referenceAspectRatio;
      
      // 이미지 좌표 계산
      final imageLeft = previewWidth * _imageLeftRatio;
      final imageTop = previewHeight * _imageTopRatio;
      final imageWidth = previewWidth * _imageWidthRatio;
      final imageHeight = previewHeight * _imageHeightRatio;
      
      // 자를 영역을 실제 이미지 좌표로 변환 (이미지 내부 비율 기준)
      final cropLeft = _cropArea!.left * imageWidth;
      final cropTop = _cropArea!.top * imageHeight;
      final cropWidth = _cropArea!.width * imageWidth;
      final cropHeight = _cropArea!.height * imageHeight;
      
      if (cropWidth <= 0 || cropHeight <= 0) {
        _showToastMessage('유효한 자르기 영역을 선택해주세요.');
        return;
      }
      
      // 실제 이미지 크기 가져오기
      int? imageWidthPx;
      int? imageHeightPx;
      
      if (kIsWeb) {
        final imageInfo = await _getImageInfo(_currentImageBytes!);
        if (imageInfo != null) {
          imageWidthPx = imageInfo['width'];
          imageHeightPx = imageInfo['height'];
        }
      } else {
        try {
          final codec = await ui.instantiateImageCodec(_currentImageBytes!);
          final frame = await codec.getNextFrame();
          final decodedImage = frame.image;
          imageWidthPx = decodedImage.width;
          imageHeightPx = decodedImage.height;
        } catch (e) {
          debugPrint('이미지 디코딩 오류: $e');
        }
      }
      
      if (imageWidthPx == null || imageHeightPx == null) {
        _showToastMessage('이미지 정보를 가져올 수 없습니다.');
        return;
      }
      
      // 미리보기 비율을 실제 이미지 비율로 변환
      final scaleX = imageWidthPx / imageWidth;
      final scaleY = imageHeightPx / imageHeight;
      
      final actualCropLeft = (cropLeft * scaleX).round();
      final actualCropTop = (cropTop * scaleY).round();
      final actualCropWidth = (cropWidth * scaleX).round();
      final actualCropHeight = (cropHeight * scaleY).round();
      
      // 이미지 자르기
      Uint8List? croppedBytes;
      
      if (kIsWeb) {
        croppedBytes = await _cropImageWeb(
          _currentImageBytes!,
          actualCropLeft,
          actualCropTop,
          actualCropWidth,
          actualCropHeight,
        );
      } else {
        croppedBytes = await _cropImageMobile(
          _currentImageBytes!,
          actualCropLeft,
          actualCropTop,
          actualCropWidth,
          actualCropHeight,
        );
      }
      
      if (croppedBytes != null) {
        // 원본 이미지 비율 재계산
        if (kIsWeb) {
          final imageInfo = await _getImageInfo(croppedBytes);
          if (imageInfo != null && imageInfo['width'] != null && imageInfo['height'] != null) {
            _originalImageAspectRatio = imageInfo['width']! / imageInfo['height']!;
          }
        } else {
          try {
            final codec = await ui.instantiateImageCodec(croppedBytes);
            final frame = await codec.getNextFrame();
            final decodedImage = frame.image;
            _originalImageAspectRatio = decodedImage.width / decodedImage.height;
          } catch (e) {
            debugPrint('이미지 디코딩 오류: $e');
          }
        }
        
        final base64String = base64Encode(croppedBytes);
        
        setState(() {
          _currentImagePath = base64String;
          _currentImageBytes = croppedBytes;
          _isCropMode = false;
          _cropArea = null;
          _cropResizeHandle = null;
          _cropResizeStartPoint = null;
          _cropResizeStartGlobalPoint = null;
          _cropResizeStartArea = null;
          _isImageSelected = false;
          _resizeHandle = null;
          
          // 자른 이미지의 크기에 맞춰 위치/크기 재조정
          if (_originalImageAspectRatio != null) {
            final maxImageWidth = previewWidth * 1.0;
            final maxImageHeight = previewHeight * 1.0;
            
            double newImageWidth = maxImageWidth;
            double newImageHeight = newImageWidth / _originalImageAspectRatio!;
            
            if (newImageHeight > maxImageHeight) {
              newImageHeight = maxImageHeight;
              newImageWidth = newImageHeight * _originalImageAspectRatio!;
            }
            
            _imageWidthRatio = (newImageWidth / previewWidth).clamp(0.0, 1.0);
            _imageHeightRatio = (newImageHeight / previewHeight).clamp(0.0, 1.0);
            _imageLeftRatio = ((previewWidth - newImageWidth) / 2 / previewWidth).clamp(0.0, 1.0 - _imageWidthRatio);
            _imageTopRatio = ((previewHeight - newImageHeight) / 2 / previewHeight).clamp(0.0, 1.0 - _imageHeightRatio);
          }
        });
        
        _showToastMessage('이미지가 잘렸습니다.');
      } else {
        _showToastMessage('이미지 자르기에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('이미지 자르기 오류: $e');
      _showToastMessage('이미지 자르기 중 오류가 발생했습니다.');
    }
  }

  // 웹에서 이미지 자르기
  Future<Uint8List?> _cropImageWeb(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) async {
    if (!kIsWeb) return null;
    
    try {
      final blob = html.Blob([imageBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement();
      
      final completer = Completer<Uint8List?>();
      
      img.onLoad.listen((_) async {
        try {
          final canvas = html.CanvasElement(width: width, height: height);
          final ctx = canvas.context2D;
          ctx.drawImageScaledFromSource(img, x, y, width, height, 0, 0, width, height);
          
          final isPng = imageBytes.length >= 8 && 
                        imageBytes[0] == 0x89 && 
                        imageBytes[1] == 0x50 && 
                        imageBytes[2] == 0x4E && 
                        imageBytes[3] == 0x47;
          
          final mimeType = isPng ? 'image/png' : 'image/jpeg';
          final quality = isPng ? 1.0 : 0.9;
          
          canvas.toBlob(mimeType, quality).then((blob) {
            if (blob != null) {
              final reader = html.FileReader();
              reader.onLoadEnd.listen((_) {
                final result = reader.result as Uint8List;
                html.Url.revokeObjectUrl(url);
                completer.complete(result);
              });
              reader.readAsArrayBuffer(blob);
            } else {
              html.Url.revokeObjectUrl(url);
              completer.complete(null);
            }
          });
        } catch (e) {
          html.Url.revokeObjectUrl(url);
          completer.completeError(e);
        }
      });
      
      img.onError.listen((_) {
        html.Url.revokeObjectUrl(url);
        completer.complete(null);
      });
      
      img.src = url;
      
      return completer.future;
    } catch (e) {
      debugPrint('웹 이미지 자르기 오류: $e');
      return null;
    }
  }

  // 모바일에서 이미지 자르기
  Future<Uint8List?> _cropImageMobile(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) async {
    if (kIsWeb) return null;
    
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);
      
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint(),
      );
      
      final picture = pictureRecorder.endRecording();
      final croppedImage = await picture.toImage(width, height);
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('모바일 이미지 자르기 오류: $e');
      return null;
    }
  }

  // 탭 호버 애니메이션 위젯
  Widget _buildAnimatedTab(int index, Widget child) {
    final isHovered = _tabHoverStates[index] ?? false;
    final isSelected = _tabController.index == index;
    
    return MouseRegion(
      onEnter: (_) {
        if (!isSelected) {
          SoundManager().playHover();
        }
        setState(() {
          _tabHoverStates[index] = true;
        });
      },
      onExit: (_) {
        setState(() {
          _tabHoverStates[index] = false;
        });
      },
      child: AnimatedScale(
        scale: isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }

  // 게임 화면 미리보기
  Widget _buildGamePreview() {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.60;
    final previewWidth = availableWidth.clamp(400.0, 600.0); // 최대 크기를 600px로 제한하여 스크롤 방지
    final previewHeight = previewWidth / _referenceAspectRatio;
    
    return Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1976D2), width: 2), // 테마 색상, 두께 줄임
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.hardEdge, // 이미지가 경계를 벗어나지 않도록 엄격한 클리핑
          child: Stack(
            clipBehavior: Clip.hardEdge, // Stack 내부 요소도 클리핑
            children: [
              // 배경
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  debugPrint('[BACKGROUND] onTap called, _resizeHandle: $_resizeHandle');
                  // 배경 클릭 시 선택 해제 (리사이즈 핸들이 활성화되지 않은 경우에만)
                  if (_resizeHandle == null) {
                    setState(() {
                      _isImageSelected = false;
                      _resizeHandle = null;
                      debugPrint('[BACKGROUND] onTap - _isImageSelected set to false');
                    });
                  } else {
                    debugPrint('[BACKGROUND] onTap - blocked by _resizeHandle');
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.white, // 흰색으로 변경
                    ),
                    // 가이드라인
                    if (_showGuideLines)
                      CustomPaint(
                        painter: GuideLinePainter(),
                        size: Size(previewWidth, previewHeight),
                      ),
                  ],
                ),
              ),
              // 이미지
              if (_currentImageBytes != null || _currentImagePath != null)
                _buildImageWithBoundingBox(previewWidth, previewHeight),
              // 자르기 영역 선택 UI
              if (_isCropMode)
                _buildCropOverlay(previewWidth, previewHeight),
              // 가이드라인을 최상위 레이어에 표시 (이미지 위에)
              if (_showGuideLines)
                IgnorePointer(
                  child: CustomPaint(
                    painter: GuideLinePainter(),
                    size: Size(previewWidth, previewHeight),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildImageWithBoundingBox(double previewWidth, double previewHeight) {
    // 리사이즈 핸들 크기 고려 (핸들이 화면 밖으로 나가지 않도록)
    const handleSize = 12.0;
    
    // ===== 오른쪽 경계 제한 수치 조절 부분 =====
    // 오른쪽 경계를 넘지 않도록 안쪽 여유 공간 (픽셀 단위)
    // 이 값을 조절하여 오른쪽 경계 제한을 변경할 수 있습니다 (기본값: 1.0)
    const double rightMargin = 50.0; // 오른쪽 경계에서 안쪽으로 1px 여유
    // ===========================================
    
    // 이미지 크기 계산
    double imageWidth = previewWidth * _imageWidthRatio.clamp(0.2, 1.0);
    double imageHeight = previewHeight * _imageHeightRatio.clamp(0.2, 1.0);
    
    // 이미지 위치 계산
    double imageLeft = previewWidth * _imageLeftRatio;
    double imageTop = previewHeight * _imageTopRatio;
    
    // 이미지가 미리보기 화면을 절대 벗어나지 않도록 엄격한 제한
    // 오른쪽 경계를 rightMargin만큼 안쪽으로 제한하여 넘어가지 않도록 보장
    final maxRight = previewWidth - rightMargin; // 오른쪽 최대 경계 (안쪽으로 1px)
    
    if (imageLeft + imageWidth > maxRight) {
      imageWidth = maxRight - imageLeft;
      if (imageWidth < 0) {
        imageWidth = 0;
        imageLeft = maxRight;
      }
    }
    if (imageTop + imageHeight > previewHeight) {
      imageHeight = previewHeight - imageTop;
      if (imageHeight < 0) {
        imageHeight = 0;
        imageTop = previewHeight;
      }
    }
    
    // 최종 검증: 이미지가 화면을 벗어나지 않도록 보장
    imageLeft = imageLeft.clamp(0.0, maxRight);
    imageTop = imageTop.clamp(0.0, previewHeight);
    imageWidth = imageWidth.clamp(0.0, maxRight - imageLeft);
    imageHeight = imageHeight.clamp(0.0, previewHeight - imageTop);
    
    return Stack(
      children: [
        // 이미지
        Positioned(
          top: imageTop,
          left: imageLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // 자르기 모드일 때는 이미지 선택/이동 비활성화
              if (_isCropMode) return;
              
              debugPrint('[IMAGE] onTap called, _resizeHandle: $_resizeHandle, _isImageSelected: $_isImageSelected');
              // 이미지 클릭 시 선택 상태 토글 (리사이즈 핸들이 활성화되지 않은 경우에만)
              if (_resizeHandle == null) {
                setState(() {
                  _isImageSelected = !_isImageSelected;
                  debugPrint('[IMAGE] onTap - _isImageSelected changed to: $_isImageSelected');
                  if (!_isImageSelected) {
                    _resizeHandle = null;
                  }
                });
              } else {
                debugPrint('[IMAGE] onTap - blocked by _resizeHandle');
              }
            },
            onPanStart: (details) {
              // 자르기 모드일 때는 이미지 이동 비활성화
              if (_isCropMode) return;
              
              debugPrint('[IMAGE] onPanStart called, _resizeHandle: $_resizeHandle, _isImageSelected: $_isImageSelected');
              if (_resizeHandle != null) {
                debugPrint('[IMAGE] onPanStart - blocked by _resizeHandle');
                return;
              }
              // 드래그 시작 시 선택 상태 활성화
              if (!_isImageSelected) {
                setState(() {
                  _isImageSelected = true;
                  debugPrint('[IMAGE] onPanStart - _isImageSelected set to true');
                });
              }
            },
            onPanUpdate: (details) {
              // 자르기 모드일 때는 이미지 이동 비활성화
              if (_isCropMode) return;
              
              debugPrint('[IMAGE] onPanUpdate called, _resizeHandle: $_resizeHandle, _isImageSelected: $_isImageSelected, _originalImageAspectRatio: $_originalImageAspectRatio');
              // 리사이즈 핸들이 활성화되어 있으면 이미지 이동 불가
              if (_resizeHandle != null) {
                debugPrint('[IMAGE] onPanUpdate - blocked by _resizeHandle');
                return;
              }
              
              // 리사이즈 핸들이 없으면 드래그로 위치 이동 (선택된 상태에서도 가능)
              if (_originalImageAspectRatio == null) {
                debugPrint('[IMAGE] onPanUpdate - blocked by null _originalImageAspectRatio');
                return;
              }
              
              debugPrint('[IMAGE] onPanUpdate - moving image, delta: (${details.delta.dx}, ${details.delta.dy})');
              setState(() {
                final deltaX = details.delta.dx;
                final deltaY = details.delta.dy;
                
                final newLeft = _imageLeftRatio + (deltaX / previewWidth);
                final newTop = _imageTopRatio + (deltaY / previewHeight);
                
                _imageLeftRatio = newLeft.clamp(0.0, 1.0 - _imageWidthRatio);
                _imageTopRatio = newTop.clamp(0.0, 1.0 - _imageHeightRatio);
                debugPrint('[IMAGE] onPanUpdate - new position: left=${_imageLeftRatio.toStringAsFixed(3)}, top=${_imageTopRatio.toStringAsFixed(3)}');
              });
            },
            child: Container(
              width: imageWidth,
              height: imageHeight,
              child: _buildImageWidget(
                _currentImagePath,
                _currentImageBytes,
              ),
            ),
          ),
        ),
        // 바운딩 박스와 리사이즈 핸들 (별도 레이어) - 자르기 모드일 때는 숨김
        if (_isImageSelected && !_isCropMode)
          _buildBoundingBox(imageWidth, imageHeight, previewWidth, previewHeight, imageLeft, imageTop),
      ],
    );
  }

  Widget _buildBoundingBox(double imageWidth, double imageHeight, double previewWidth, double previewHeight, double imageLeft, double imageTop) {
    const handleSize = 12.0;
    const borderWidth = 2.0;
    
    // ===== 오른쪽 경계 제한 수치 조절 부분 =====
    // 오른쪽 경계를 넘지 않도록 안쪽 여유 공간 (픽셀 단위)
    // _buildImageWithBoundingBox의 rightMargin과 동일한 값 사용
    const double rightMargin = 50.0; // 오른쪽 경계에서 안쪽으로 1px 여유
    final maxRight = previewWidth - rightMargin; // 오른쪽 최대 경계
    // ===========================================
    
    // 이미지가 미리보기 화면을 벗어나지 않도록 보장
    final safeImageLeft = imageLeft.clamp(0.0, maxRight);
    final safeImageTop = imageTop.clamp(0.0, previewHeight);
    final safeImageWidth = (imageLeft + imageWidth).clamp(0.0, maxRight) - safeImageLeft;
    final safeImageHeight = (imageTop + imageHeight).clamp(0.0, previewHeight) - safeImageTop;
    
    // 리사이즈 핸들 위치를 미리보기 화면 내로 엄격하게 제한 (오른쪽 경계는 rightMargin 고려)
    final handleLeft = safeImageLeft.clamp(0.0, maxRight - handleSize);
    final handleTop = safeImageTop.clamp(0.0, previewHeight - handleSize);
    final handleRight = (safeImageLeft + safeImageWidth - handleSize).clamp(0.0, maxRight - handleSize);
    final handleBottom = (safeImageTop + safeImageHeight - handleSize).clamp(0.0, previewHeight - handleSize);
    final handleCenterX = (safeImageLeft + (safeImageWidth - handleSize) / 2).clamp(handleSize / 2, maxRight - handleSize / 2);
    final handleCenterY = (safeImageTop + (safeImageHeight - handleSize) / 2).clamp(handleSize / 2, previewHeight - handleSize / 2);
    
    return Stack(
      children: [
        // 바운딩 박스 테두리 (이벤트를 가로채지 않도록 IgnorePointer 사용)
        Positioned(
          top: safeImageTop,
          left: safeImageLeft,
          child: IgnorePointer(
            child: Container(
              width: safeImageWidth,
              height: safeImageHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF1976D2),
                  width: borderWidth,
                ),
              ),
            ),
          ),
        ),
        // 리사이즈 핸들들 (절대 좌표, 미리보기 화면 내로 제한)
        // 좌상단
        _buildResizeHandle(
          'topLeft',
          handleLeft,
          handleTop,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 우상단
        _buildResizeHandle(
          'topRight',
          handleRight,
          handleTop,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 좌하단
        _buildResizeHandle(
          'bottomLeft',
          handleLeft,
          handleBottom,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 우하단
        _buildResizeHandle(
          'bottomRight',
          handleRight,
          handleBottom,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 상단 중앙 (세로만 조절)
        _buildResizeHandle(
          'top',
          handleCenterX,
          handleTop,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 하단 중앙 (세로만 조절)
        _buildResizeHandle(
          'bottom',
          handleCenterX,
          handleBottom,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 좌측 중앙 (가로만 조절)
        _buildResizeHandle(
          'left',
          handleLeft,
          handleCenterY,
          handleSize,
          previewWidth,
          previewHeight,
        ),
        // 우측 중앙 (가로만 조절)
        _buildResizeHandle(
          'right',
          handleRight,
          handleCenterY,
          handleSize,
          previewWidth,
          previewHeight,
        ),
      ],
    );
  }

  Widget _buildResizeHandle(String handleType, double left, double top, double size, double previewWidth, double previewHeight) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          debugPrint('[RESIZE_HANDLE] onPanStart called, handleType: $handleType, localPosition: ${details.localPosition}, globalPosition: ${details.globalPosition}');
          setState(() {
            _resizeHandle = handleType;
            _resizeStartPoint = details.localPosition;
            _resizeStartGlobalPoint = details.globalPosition;
            _resizeStartWidth = previewWidth * _imageWidthRatio;
            _resizeStartHeight = previewHeight * _imageHeightRatio;
            _resizeStartLeft = previewWidth * _imageLeftRatio;
            _resizeStartTop = previewHeight * _imageTopRatio;
            debugPrint('[RESIZE_HANDLE] onPanStart - _resizeHandle set to $handleType, startSize: (${_resizeStartWidth!.toStringAsFixed(1)}, ${_resizeStartHeight!.toStringAsFixed(1)}), startPos: (${_resizeStartLeft!.toStringAsFixed(1)}, ${_resizeStartTop!.toStringAsFixed(1)})');
          });
        },
        onPanUpdate: (details) {
          debugPrint('[RESIZE_HANDLE] onPanUpdate called, handleType: $handleType, _resizeHandle: $_resizeHandle, _originalImageAspectRatio: $_originalImageAspectRatio, globalPosition: ${details.globalPosition}, localPosition: ${details.localPosition}');
          if (_resizeHandle != handleType) {
            debugPrint('[RESIZE_HANDLE] onPanUpdate - blocked: _resizeHandle ($_resizeHandle) != handleType ($handleType)');
            return;
          }
          // 변 중앙 핸들은 비율 체크 불필요, 모서리 핸들만 비율 체크
          final isEdgeHandle = handleType == 'top' || handleType == 'bottom' || 
                               handleType == 'left' || handleType == 'right';
          if (!isEdgeHandle && _originalImageAspectRatio == null) {
            debugPrint('[RESIZE_HANDLE] onPanUpdate - blocked: _originalImageAspectRatio is null');
            return;
          }
          
          // globalPosition을 사용하여 시작 위치에서의 총 이동량 계산
          final totalDelta = details.globalPosition - (_resizeStartGlobalPoint ?? Offset.zero);
          final deltaX = totalDelta.dx;
          final deltaY = totalDelta.dy;
          
          debugPrint('[RESIZE_HANDLE] onPanUpdate - resizing, totalDelta: (${deltaX.toStringAsFixed(2)}, ${deltaY.toStringAsFixed(2)})');
          setState(() {
            double newWidth = _resizeStartWidth!;
            double newHeight = _resizeStartHeight!;
            double newLeft = _resizeStartLeft!;
            double newTop = _resizeStartTop!;
            
            // 모서리 핸들은 비율 유지, 변 중앙 핸들은 가로/세로만 조절
            switch (handleType) {
              case 'topLeft':
                // 좌상단: 비율 유지하면서 크기 조절
                newWidth = (_resizeStartWidth! - deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                newHeight = newWidth / _originalImageAspectRatio!;
                newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                break;
              case 'topRight':
                // 우상단: 비율 유지하면서 크기 조절
                newWidth = (_resizeStartWidth! + deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                newHeight = newWidth / _originalImageAspectRatio!;
                newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                break;
              case 'bottomLeft':
                // 좌하단: 비율 유지하면서 크기 조절
                newWidth = (_resizeStartWidth! - deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                newHeight = newWidth / _originalImageAspectRatio!;
                newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                break;
              case 'bottomRight':
                // 우하단: 비율 유지하면서 크기 조절
                newWidth = (_resizeStartWidth! + deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                newHeight = newWidth / _originalImageAspectRatio!;
                break;
              case 'top':
                // 상단 중앙: 세로만 조절 (위쪽으로) - 비율 변경
                newHeight = (_resizeStartHeight! - deltaY).clamp(previewHeight * 0.1, previewHeight * 1.0);
                newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                // 비율 변경: _originalImageAspectRatio 업데이트하지 않고 그대로 사용
                break;
              case 'bottom':
                // 하단 중앙: 세로만 조절 (아래쪽으로) - 비율 변경
                newHeight = (_resizeStartHeight! + deltaY).clamp(previewHeight * 0.1, previewHeight * 1.0);
                // 비율 변경: _originalImageAspectRatio 업데이트하지 않고 그대로 사용
                break;
              case 'left':
                // 좌측 중앙: 가로만 조절 (왼쪽으로) - 비율 변경
                newWidth = (_resizeStartWidth! - deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                // 비율 변경: _originalImageAspectRatio 업데이트하지 않고 그대로 사용
                break;
              case 'right':
                // 우측 중앙: 가로만 조절 (오른쪽으로) - 비율 변경
                newWidth = (_resizeStartWidth! + deltaX).clamp(previewWidth * 0.1, previewWidth * 1.0);
                // 비율 변경: _originalImageAspectRatio 업데이트하지 않고 그대로 사용
                break;
            }
            
            // 미리보기 화면 내에서만 제한
            final maxHeight = previewHeight * 1.0;
            final minHeight = previewHeight * 0.1;
            final maxWidth = previewWidth * 1.0;
            final minWidth = previewWidth * 0.1;
            
            // 모서리 핸들은 비율 유지하면서 크기 제한 적용
            final isCornerHandle = handleType == 'topLeft' || handleType == 'topRight' || 
                                   handleType == 'bottomLeft' || handleType == 'bottomRight';
            
            if (isCornerHandle) {
              // 모서리 핸들: 비율 유지하면서 크기 제한
              if (newHeight > maxHeight) {
                newHeight = maxHeight;
                newWidth = newHeight * _originalImageAspectRatio!;
                
                // 위치 재조정
                switch (handleType) {
                  case 'topLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'topRight':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'bottomLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  case 'bottomRight':
                    break;
                }
              } else if (newHeight < minHeight) {
                newHeight = minHeight;
                newWidth = newHeight * _originalImageAspectRatio!;
                
                // 위치 재조정
                switch (handleType) {
                  case 'topLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'topRight':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'bottomLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  case 'bottomRight':
                    break;
                }
              }
              
              if (newWidth > maxWidth) {
                newWidth = maxWidth;
                newHeight = newWidth / _originalImageAspectRatio!;
                
                // 위치 재조정
                switch (handleType) {
                  case 'topLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'topRight':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'bottomLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  case 'bottomRight':
                    break;
                }
              } else if (newWidth < minWidth) {
                newWidth = minWidth;
                newHeight = newWidth / _originalImageAspectRatio!;
                
                // 위치 재조정
                switch (handleType) {
                  case 'topLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'topRight':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  case 'bottomLeft':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  case 'bottomRight':
                    break;
                }
              }
            } else {
              // 변 중앙 핸들: 가로/세로만 조절 (비율 무시)
              if (newHeight > maxHeight) {
                newHeight = maxHeight;
                // 위치 재조정
                switch (handleType) {
                  case 'top':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  default:
                    break;
                }
              } else if (newHeight < minHeight) {
                newHeight = minHeight;
                // 위치 재조정
                switch (handleType) {
                  case 'top':
                    newTop = _resizeStartTop! + (_resizeStartHeight! - newHeight);
                    break;
                  default:
                    break;
                }
              }
              
              if (newWidth > maxWidth) {
                newWidth = maxWidth;
                // 위치 재조정
                switch (handleType) {
                  case 'left':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  default:
                    break;
                }
              } else if (newWidth < minWidth) {
                newWidth = minWidth;
                // 위치 재조정
                switch (handleType) {
                  case 'left':
                    newLeft = _resizeStartLeft! + (_resizeStartWidth! - newWidth);
                    break;
                  default:
                    break;
                }
              }
            }
            
            // 변 중앙 핸들을 사용한 경우 비율 변경 (이미지 왜곡 허용)
            final isEdgeHandle = handleType == 'top' || handleType == 'bottom' || 
                                 handleType == 'left' || handleType == 'right';
            if (isEdgeHandle) {
              // 변 중앙 핸들: 비율 변경 (이미지 왜곡)
              _imageWidthRatio = newWidth / previewWidth;
              _imageHeightRatio = newHeight / previewHeight;
              // _originalImageAspectRatio는 변경하지 않음 (원본 비율 유지)
            } else {
              // 모서리 핸들: 비율 유지
              _imageWidthRatio = newWidth / previewWidth;
              _imageHeightRatio = newHeight / previewHeight;
            }
            
            // 이미지가 미리보기 화면을 벗어나지 않도록 크기 제한
            _imageWidthRatio = _imageWidthRatio.clamp(0.0, 1.0);
            _imageHeightRatio = _imageHeightRatio.clamp(0.0, 1.0);
            
            // 이미지 위치를 미리보기 화면 내로 제한
            _imageLeftRatio = (newLeft / previewWidth).clamp(0.0, 1.0 - _imageWidthRatio);
            _imageTopRatio = (newTop / previewHeight).clamp(0.0, 1.0 - _imageHeightRatio);
            debugPrint('[RESIZE_HANDLE] onPanUpdate - new size: (${newWidth.toStringAsFixed(1)}, ${newHeight.toStringAsFixed(1)}), new pos: (${newLeft.toStringAsFixed(1)}, ${newTop.toStringAsFixed(1)}), ratios: (${_imageWidthRatio.toStringAsFixed(3)}, ${_imageHeightRatio.toStringAsFixed(3)})');
          });
        },
        onPanEnd: (_) {
          debugPrint('[RESIZE_HANDLE] onPanEnd called, handleType: $handleType');
          setState(() {
            _resizeHandle = null;
            debugPrint('[RESIZE_HANDLE] onPanEnd - _resizeHandle cleared');
          });
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(size / 2),
          ),
        ),
      ),
    );
  }

  // 문제 카드 빌드
  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    
    // 디버그 로그
    final imagePath = question['imagePath'] != null ? question['imagePath'] as String : null;
    final imageBytes = question['imageBytes'] != null ? question['imageBytes'] as Uint8List : null;
    debugPrint('문제 ${index + 1} 이미지 로드: imagePath=${imagePath != null ? "있음 (${imagePath.length} chars)" : "null"}, imageBytes=${imageBytes != null ? "있음 (${imageBytes.length} bytes)" : "null"}');
    
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
                  MouseRegion(
                    onEnter: (_) => SoundManager().playHover(),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                      onPressed: () {
                        SoundManager().playClick();
                        _editQuestion(index);
                      },
                      tooltip: '수정',
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) => SoundManager().playHover(),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        SoundManager().playClick();
                        _showDeleteConfirmDialog(index);
                      },
                      tooltip: '삭제',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(
              imagePath,
              imageBytes,
              height: 150,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 20),
                const SizedBox(width: 8),
                Text(
                  '정답: ${question['answer']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            color: Color(0xFF1976D2),
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
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
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
              backgroundColor: const Color(0xFF1976D2),
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
            color: Color(0xFF1976D2),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(), // 왼쪽 공간
            ),
            // 텍스트 위치 미세 조정: SizedBox의 width 값을 조절하여 오른쪽(양수) 또는 왼쪽(음수)으로 이동 가능
            const SizedBox(width: 0), // 이 값을 조절하세요 (기본값: 8, 오른쪽으로 이동하려면 증가, 왼쪽으로 이동하려면 감소)
            const Text(
              '게임 화면 미리보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    onEnter: (_) => SoundManager().playHover(),
                    child: GestureDetector(
                      onTap: () => SoundManager().playClick(),
                      child: Row(
                        children: [
                          const Text(
                            '가이드라인',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _showGuideLines,
                            onChanged: (value) {
                              SoundManager().playClick();
                              setState(() {
                                _showGuideLines = value;
                              });
                            },
                            activeColor: const Color(0xFF1976D2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGamePreview(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                label: const Text(
                  '이미지 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _currentImageBytes != null ? () {
                setState(() {
                  _isCropMode = !_isCropMode;
                  if (_isCropMode) {
                    // 자르기 모드 시작 시 기본 자를 영역 설정 (이미지 전체)
                    _cropArea = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
                  } else {
                    _cropArea = null;
                    _cropResizeHandle = null;
                    _cropResizeStartPoint = null;
                    _cropResizeStartGlobalPoint = null;
                    _cropResizeStartArea = null;
                  }
                });
              } : null,
              icon: Icon(_isCropMode ? Icons.crop_free : Icons.crop, color: Colors.white),
              label: Text(
                _isCropMode ? '자르기 취소' : '이미지 자르기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCropMode ? Colors.orange : const Color(0xFF1976D2),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            if (_isCropMode && _cropArea != null) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _cropImage,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  '자르기 적용',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answerController,
          maxLength: 20, // 최대 20글자 제한
          decoration: InputDecoration(
            hintText: '정답을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: '', // 글자 수 카운터 숨기기
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _currentImagePath != null && _answerController.text.trim().isNotEmpty
                ? _addQuestion
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
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
        const Spacer(), // 남은 공간 채우기
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
                color: Color(0xFF1976D2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_questions.length}개',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 문제 목록 스크롤 영역 (하단 버튼은 고정)
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
        // 하단 고정 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_questions.length >= 3 && !_isSaving) ? _saveQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
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
            color: const Color(0xFF1976D2), // 파란색 계열
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
                  '이미지 퀴즈 만들기',
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
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Color(0xFF1976D2)),
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
                indicatorColor: const Color(0xFF1976D2),
                indicatorWeight: 3,
                labelColor: const Color(0xFF1976D2),
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
                    child: _buildAnimatedTab(
                      0,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category, size: 20),
                          const SizedBox(width: 8),
                          const Text('카테고리'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: _buildAnimatedTab(
                      1,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate, size: 20),
                          const SizedBox(width: 8),
                          const Text('문제 추가'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: _buildAnimatedTab(
                      2,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.list, size: 20),
                          const SizedBox(width: 8),
                          Text('문제 목록 (${_questions.length})'),
                        ],
                      ),
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
