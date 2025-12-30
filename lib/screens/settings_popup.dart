import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html if (dart.library.html) 'dart:html';
import '../utils/sound_manager.dart';
import '../utils/storage_manager.dart';

class SettingsPopup extends StatefulWidget {
  const SettingsPopup({super.key});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup>
    with SingleTickerProviderStateMixin {
  bool soundEnabled = true;
  bool fullscreenMode = false;
  double soundVolume = 1.0;
  bool isLandscapeMode = false; // false = 세로모드 (기본값), true = 가로모드
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      soundEnabled = prefs.getBool('soundEnabled') ?? true;
      soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      isLandscapeMode = prefs.getBool('isLandscapeMode') ?? false; // 기본값: 세로모드
      // 웹에서만 전체화면 상태 확인
      if (kIsWeb) {
        fullscreenMode = prefs.getBool('fullscreenMode') ?? false;
        _checkFullscreenState();
      }
    });
    // SoundManager에 볼륨 적용
    await SoundManager().setVolume(soundVolume);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', soundEnabled);
    await prefs.setDouble('soundVolume', soundVolume);
    await prefs.setBool('isLandscapeMode', isLandscapeMode);
    if (kIsWeb) {
      await prefs.setBool('fullscreenMode', fullscreenMode);
    }
    // SoundManager에 설정 적용 (soundEnabled 상태도 업데이트됨)
    await SoundManager().loadSettings();
  }

  void _checkFullscreenState() {
    if (kIsWeb) {
      try {
        // 현재 전체화면 상태 확인
        final isFullscreen = html.document.fullscreenElement != null;
        if (isFullscreen != fullscreenMode) {
          setState(() {
            fullscreenMode = isFullscreen;
          });
        }
      } catch (e) {
        // 전체화면 API가 지원되지 않는 경우
        print('전체화면 상태 확인 오류: $e');
      }
    }
  }

  Future<void> _toggleFullscreen(bool value) async {
    if (!kIsWeb) return;
    
    try {
      if (value) {
        // 전체화면 진입
        await html.document.documentElement?.requestFullscreen();
      } else {
        // 전체화면 종료
        html.document.exitFullscreen();
      }
      setState(() {
        fullscreenMode = value;
      });
      await _saveSettings();
    } catch (e) {
      // 전체화면 API가 지원되지 않거나 오류 발생 시
      print('전체화면 전환 오류: $e');
    }
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
            color: Colors.grey.shade600,
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.grey,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
              const SizedBox(height: 32),
              // 전체모드 (웹 전용) - 맨 위로 이동
              if (kIsWeb) ...[
                _buildSettingItem(
                  icon: Icons.fullscreen,
                  title: '전체모드',
                  value: fullscreenMode,
                  onChanged: _toggleFullscreen,
                ),
                const SizedBox(height: 24),
              ],
              // 사운드
              _buildSettingItem(
                icon: Icons.volume_up,
                title: '사운드',
                value: soundEnabled,
                onChanged: (value) {
                  setState(() {
                    soundEnabled = value;
                    if (value) {
                      // 사운드 ON 시 볼륨을 100%로 설정
                      soundVolume = 1.0;
                    } else {
                      // 사운드 OFF 시 볼륨을 0%로 설정
                      soundVolume = 0.0;
                    }
                  });
                  _saveSettings();
                },
              ),
              // 볼륨 조절 (사운드가 켜져 있을 때만 표시)
              if (soundEnabled) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.volume_down,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '볼륨: ${(soundVolume * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF4AA0A9),
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbColor: const Color(0xFF4AA0A9),
                          overlayColor: const Color(0xFF4AA0A9).withOpacity(0.2),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: soundVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(soundVolume * 100).toInt()}%',
                          onChangeStart: (_) {
                            // onChangeStart에서는 사운드 재생하지 않음
                          },
                          onChanged: (value) {
                            final newValue = (value * 10).round() / 10.0; // 10% 단위로 반올림
                            if ((newValue * 10).round() != (soundVolume * 10).round()) {
                              // 값이 변경될 때만 호버 사운드 재생
                              SoundManager().playHover();
                            }
                            setState(() {
                              soundVolume = newValue;
                            });
                            _saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 화면 모드 (가로모드/세로모드)
              const SizedBox(height: 24),
              _buildScreenModeSelector(),
              // 퀴즈 내보내기/불러오기
              const SizedBox(height: 24),
              _buildExportImportSection(),
              const SizedBox(height: 32),
              // 확인 버튼
              _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final color = Colors.grey.shade700;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
            color.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Center(
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 5.0,
                    shadows: [
                      Shadow(
                        color: color.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.screen_rotation,
                color: Colors.grey.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '진행 화면 모드',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  icon: Icons.phone_android,
                  label: '세로모드',
                  isSelected: !isLandscapeMode,
                  isLandscape: false,
                  onTap: () {
                    SoundManager().playClick();
                    setState(() {
                      isLandscapeMode = false;
                    });
                    _saveSettings();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeOption(
                  icon: Icons.phone_android,
                  label: '가로모드',
                  isSelected: isLandscapeMode,
                  isLandscape: true,
                  onTap: () {
                    SoundManager().playClick();
                    setState(() {
                      isLandscapeMode = true;
                    });
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isLandscape,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: (_) => SoundManager().playHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4AA0A9).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4AA0A9)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: isLandscape ? 4.7124 : 0.0, // 270도 회전 (라디안: 3π/2 = 4.7124)
                child: Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF4AA0A9)
                      : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4AA0A9)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MouseRegion(
      onEnter: (_) => SoundManager().playHover(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.grey.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                SoundManager().playClick();
                onChanged(!value);
              },
              child: Switch(
                value: value,
                activeColor: const Color(0xFF4AA0A9),
                onChanged: (newValue) {
                  SoundManager().playClick();
                  onChanged(newValue);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportImportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.import_export,
                color: Colors.grey.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '퀴즈 관리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildExportImportButton(
                  icon: Icons.upload,
                  label: '퀴즈 내보내기',
                  color: const Color(0xFF4AA0A9),
                  onPressed: _exportQuizzes,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExportImportButton(
                  icon: Icons.download,
                  label: '퀴즈 불러오기',
                  color: const Color(0xFF7B1FA2),
                  onPressed: _importQuizzes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportImportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      onEnter: (_) => SoundManager().playHover(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            SoundManager().playClick();
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Future<void> _exportQuizzes() async {
    try {
      if (!kIsWeb) {
        _showToastMessage('웹 환경에서만 사용 가능합니다.');
        return;
      }

      // 모든 퀴즈 가져오기
      final jsonString = await StorageManager.exportAllQuizzesToJson();
      
      // 파일 다운로드
      final blob = html.Blob([jsonString], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'quizzes_export_${DateTime.now().millisecondsSinceEpoch}.json')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        _showToastMessage('퀴즈가 성공적으로 내보내졌습니다.');
      }
    } catch (e) {
      debugPrint('퀴즈 내보내기 오류: $e');
      if (mounted) {
        _showToastMessage('퀴즈 내보내기 중 오류가 발생했습니다: $e');
      }
    }
  }

  Future<void> _importQuizzes() async {
    try {
      if (!kIsWeb) {
        _showToastMessage('웹 환경에서만 사용 가능합니다.');
        return;
      }

      // 파일 선택
      final input = html.FileUploadInputElement()..accept = '.json';
      input.click();

      input.onChange.listen((e) async {
        final file = input.files!.first;
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) async {
          try {
            final jsonString = reader.result as String;
            
            // 퀴즈 불러오기
            final importedQuizzes = await StorageManager.importQuizzesFromJson(jsonString);
            
            if (mounted) {
              _showToastMessage('${importedQuizzes.length}개의 퀴즈가 성공적으로 불러와졌습니다.');
            }
          } catch (e) {
            debugPrint('퀴즈 불러오기 오류: $e');
            if (mounted) {
              _showToastMessage('퀴즈 불러오기 중 오류가 발생했습니다: $e');
            }
          }
        });

        reader.readAsText(file);
      });
    } catch (e) {
      debugPrint('퀴즈 불러오기 오류: $e');
      if (mounted) {
        _showToastMessage('퀴즈 불러오기 중 오류가 발생했습니다: $e');
      }
    }
  }
}
