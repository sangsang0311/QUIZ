import 'package:flutter/material.dart';
import 'image_quiz_popup.dart';
import 'text_quiz_popup.dart';
import 'voice_quiz_popup.dart';
import 'settings_popup.dart';
import 'quiz_management_screen.dart';
import '../utils/sound_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _titleAnimationController;
  late List<Animation<double>> _buttonAnimations;
  late Animation<double> _titleScaleAnimation;
  late Animation<double> _titleRotationAnimation;
  bool _isReady = false; // 폰트 로드 및 텍스트 렌더링 완료 플래그

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 앱 이름용 애니메이션 컨트롤러 (최초 1회만 실행)
    _titleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 각 버튼에 대한 애니메이션 생성 (순차적으로 나타나도록)
    _buttonAnimations = List.generate(
      4,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.15,
            0.6 + (index * 0.1),
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );

    // 튀기기 효과 (스케일 애니메이션)
    _titleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_titleAnimationController);

    // 살짝 회전 효과
    _titleRotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _titleAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // 첫 프레임 렌더링 후 텍스트가 완전히 로드될 시간을 주고 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 텍스트 렌더링 및 폰트 로드를 위한 충분한 시간 확보 (500ms)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isReady = true;
          });
          _animationController.forward();
          _titleAnimationController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerWidth = screenWidth * 0.60; // 중앙 60% 영역
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent, // 배경 투명 (main.dart에서 처리)
          body: Center(
            child: SizedBox(
              width: centerWidth, // 중앙 60%만 사용
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent, // 배경 투명
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 200),
                        
                        // 앱 이름 "정답은?"
                        _buildAppTitle(),
                        
                        const SizedBox(height: 2),
                        
                        // 서브 타이틀 "MT, 술자리, 레크레이션 필수템!"
                        _buildSubTitle(),
                    
                        const SizedBox(height: 50),
                        
                        // 버튼 4개 가로 배열 (가운데 정렬, 오버플로우 방지)
                        LayoutBuilder(
                          builder: (context, constraints) {
                    // 기본 크기 (전체 모드에서 설정한 크기)
                    const defaultButtonSize = 200.0;
                    const defaultSpacing = 36.0;
                    const defaultIconSize = 100.0;
                    const defaultFontSize = 25.0;
                    const horizontalPadding = 48.0; // 좌우 패딩 24 * 2
                    
                    final screenWidth = constraints.maxWidth;
                    final availableWidth = screenWidth - horizontalPadding;
                    
                    // 기본 크기로 필요한 너비 계산
                    final requiredWidth = (defaultButtonSize * 4) + (defaultSpacing * 3);
                    
                    // 화면이 충분히 크면 기본 크기 사용
                    if (availableWidth >= requiredWidth) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAnimatedButton(
                            index: 0,
                            icon: Icons.image,
                            label: '이미지 퀴즈',
                            color: Colors.blue,
                            buttonSize: defaultButtonSize,
                            iconSize: defaultIconSize,
                            fontSize: defaultFontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const ImageQuizPopup(),
                              );
                            },
                          ),
                          
                          const SizedBox(width: defaultSpacing),
                          
                          _buildAnimatedButton(
                            index: 1,
                            icon: Icons.text_fields,
                            label: '텍스트 퀴즈',
                            color: Colors.purple,
                            buttonSize: defaultButtonSize,
                            iconSize: defaultIconSize,
                            fontSize: defaultFontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const TextQuizPopup(),
                              );
                            },
                          ),
                          
                          const SizedBox(width: defaultSpacing),
                          
                          _buildAnimatedButton(
                            index: 2,
                            icon: Icons.mic,
                            label: '음성퀴즈',
                            color: Colors.orange,
                            buttonSize: defaultButtonSize,
                            iconSize: defaultIconSize,
                            fontSize: defaultFontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const VoiceQuizPopup(),
                              );
                            },
                          ),
                          
                          const SizedBox(width: defaultSpacing),
                          
                          _buildAnimatedButton(
                            index: 3,
                            icon: Icons.settings,
                            label: '설 정',
                            color: Colors.grey,
                            buttonSize: defaultButtonSize,
                            iconSize: defaultIconSize,
                            fontSize: defaultFontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const SettingsPopup(),
                              );
                            },
                          ),
                        ],
                      );
                    }
                    
                    // 화면이 작으면 자동으로 줄어들도록 계산
                    const minButtonSize = 120.0;
                    const minSpacing = 8.0;
                    
                    final calculatedButtonSize = (availableWidth - (minSpacing * 3)) / 4;
                    final buttonSize = calculatedButtonSize < minButtonSize 
                        ? minButtonSize 
                        : calculatedButtonSize;
                    
                    final spacing = buttonSize == minButtonSize 
                        ? minSpacing 
                        : (availableWidth - (buttonSize * 4)) / 3;
                    
                    final iconSize = (buttonSize * 0.5).clamp(32.0, defaultIconSize);
                    final fontSize = (buttonSize * 0.125).clamp(12.0, defaultFontSize);
                    
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAnimatedButton(
                            index: 0,
                            icon: Icons.image,
                            label: '이미지 퀴즈',
                            color: Colors.blue,
                            buttonSize: buttonSize,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const ImageQuizPopup(),
                              );
                            },
                          ),
                          
                          SizedBox(width: spacing),
                          
                          _buildAnimatedButton(
                            index: 1,
                            icon: Icons.text_fields,
                            label: '텍스트 퀴즈',
                            color: Colors.purple,
                            buttonSize: buttonSize,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const TextQuizPopup(),
                              );
                            },
                          ),
                          
                          SizedBox(width: spacing),
                          
                          _buildAnimatedButton(
                            index: 2,
                            icon: Icons.mic,
                            label: '음성퀴즈',
                            color: Colors.orange,
                            buttonSize: buttonSize,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const VoiceQuizPopup(),
                              );
                            },
                          ),
                          
                          SizedBox(width: spacing),
                          
                          _buildAnimatedButton(
                            index: 3,
                            icon: Icons.settings,
                            label: '설 정',
                            color: Colors.grey,
                            buttonSize: buttonSize,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
                                builder: (context) => const SettingsPopup(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                      },
                    ),
                    
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 모든 팝업과 화면의 텍스트를 미리 렌더링 (화면 밖에 숨김)
        _buildPreRenderWidgets(),
      ],
    );
  }

  // 모든 팝업과 화면의 텍스트를 미리 렌더링하는 위젯
  Widget _buildPreRenderWidgets() {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: Stack(
          children: [
            // 팝업들 미리 렌더링
            const ImageQuizPopup(),
            const TextQuizPopup(),
            const VoiceQuizPopup(),
            const SettingsPopup(),
            // 퀴즈 관리 화면 미리 렌더링
            QuizManagementScreen(quizType: 'image'),
            QuizManagementScreen(quizType: 'text'),
            QuizManagementScreen(quizType: 'voice'),
            // 공통 텍스트들 미리 렌더링
            _buildCommonTexts(),
          ],
        ),
      ),
    );
  }

  // 공통으로 사용되는 텍스트들을 미리 렌더링
  Widget _buildCommonTexts() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 버튼 텍스트들
        Text('이미지 퀴즈', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        Text('텍스트 퀴즈', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        Text('음성퀴즈', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        Text('설 정', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        // 서브타이틀
        Text('MT, 술자리, 레크레이션 필수템!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, fontFamily: 'Jalnan2')),
        // 팝업 관련 텍스트들
        Text('카테고리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('문제 추가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('문제 목록', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('퀴즈 내보내기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('퀴즈 불러오기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('사운드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text('전체모드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text('설정', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text('확인', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        // 퀴즈 관리 화면 텍스트들
        Text('등록된 퀴즈가 없습니다', style: TextStyle(fontSize: 18)),
        Text('문제', style: TextStyle(fontSize: 14)),
        Text('수정', style: TextStyle()),
        Text('삭제', style: TextStyle()),
        // 기타 공통 텍스트
        Text('다음', style: TextStyle()),
        Text('정답', style: TextStyle()),
        Text('시작', style: TextStyle()),
        Text('결과', style: TextStyle()),
      ],
    );
  }

  Widget _buildAppTitle() {
    // 텍스트를 미리 렌더링하되, 애니메이션 시작 전에는 숨김
    return AnimatedBuilder(
      animation: _titleAnimationController,
      builder: (context, child) {
        // _isReady가 false면 완전히 숨김 (렌더링은 하지만 보이지 않음)
        if (!_isReady) {
          return Opacity(
            opacity: 0.0,
            child: Image.asset(
              'assets/images/App_Name.png',
              height: 200,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          );
        }
        
        return Transform.rotate(
          angle: _titleRotationAnimation.value,
          child: Transform.scale(
            scale: _titleScaleAnimation.value,
            filterQuality: FilterQuality.high,
            child: Opacity(
              opacity: _titleScaleAnimation.value.clamp(0.0, 1.0),
              child: Image.asset(
                'assets/images/App_Name.png',
                height: 200, // 이 숫자를 조절하면 이미지 크기가 변경됩니다
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubTitle() {
    // 텍스트를 미리 렌더링하되, 애니메이션 시작 전에는 숨김
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _isReady ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        // 값이 null이거나 범위를 벗어나면 0으로 설정
        final safeValue = (value.isNaN || value.isInfinite) ? 0.0 : value;
        final clampedValue = safeValue.clamp(0.0, 1.0);
        
        // 텍스트를 미리 렌더링하되 opacity로 숨김 (폰트 로드 보장)
        return Opacity(
          opacity: _isReady ? clampedValue : 0.0,
          child: Transform.translate(
            offset: Offset(0, _isReady ? 10 * (1 - clampedValue) : 0),
            child: Text(
              'MT, 술자리, 레크레이션 필수템!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                fontFamily: 'Jalnan2',
                color: const Color(0xFF4AA0A9),
                letterSpacing: 0.8,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.15),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedButton({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    required double buttonSize,
    required double iconSize,
    required double fontSize,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _buttonAnimations[index],
      builder: (context, child) {
        final animationValue = _isReady ? _buttonAnimations[index].value : 0.0;
        // 텍스트를 미리 렌더링하되 opacity로 숨김 (폰트 로드 보장)
        return Transform.scale(
          scale: _isReady ? animationValue : 0.0,
          child: Opacity(
            opacity: _isReady ? animationValue.clamp(0.0, 1.0) : 0.0,
            child: _buildButton(
              icon: icon,
              label: label,
              color: color,
              buttonSize: buttonSize,
              iconSize: iconSize,
              fontSize: fontSize,
              onPressed: onPressed,
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required double buttonSize,
    required double iconSize,
    required double fontSize,
    required VoidCallback onPressed,
  }) {
    return _AnimatedButton(
      icon: icon,
      label: label,
      color: color,
      buttonSize: buttonSize,
      iconSize: iconSize,
      fontSize: fontSize,
      onPressed: onPressed,
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double buttonSize;
  final double iconSize;
  final double fontSize;
  final VoidCallback onPressed;

  const _AnimatedButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.buttonSize,
    required this.iconSize,
    required this.fontSize,
    required this.onPressed,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

    // 각 버튼별 색상 설정 (테마색에 맞춰서)
    final Map<Color, Map<String, Color>> buttonColors = {
      Colors.blue: {
        'bg': const Color(0xFFE3F2FD),
        'border': const Color(0xFF1976D2), // 파란색 계열
        'icon': const Color(0xFF1976D2),
        'text': const Color(0xFF1565C0),
      },
      Colors.purple: {
        'bg': const Color(0xFFF3E5F5),
        'border': const Color(0xFF7B1FA2), // 보라색 계열
        'icon': const Color(0xFF7B1FA2),
        'text': const Color(0xFF6A1B9A),
      },
      Colors.orange: {
        'bg': const Color(0xFFFFF3E0),
        'border': const Color(0xFFF57C00), // 주황색 계열
        'icon': const Color(0xFFF57C00),
        'text': const Color(0xFFE65100),
      },
      Colors.grey: {
        'bg': const Color(0xFFF5F5F5),
        'border': Colors.grey.shade600, // 회색 계열
        'icon': const Color(0xFF616161),
        'text': const Color(0xFF424242),
      },
    };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _elevationAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = buttonColors[widget.color] ?? buttonColors[Colors.grey]!;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        _controller.forward();
        SoundManager().playHover();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _controller.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _isPressed = true;
          });
          SoundManager().playClick();
        },
        onTapUp: (_) {
          setState(() {
            _isPressed = false;
          });
          widget.onPressed();
        },
        onTapCancel: () {
          setState(() {
            _isPressed = false;
          });
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double scale = 1.0;
            if (_isPressed) {
              scale = 0.95; // 클릭 시 살짝 축소
            } else if (_isHovered) {
              scale = _scaleAnimation.value; // 호버 시 확대
            }
            final elevation = _isHovered ? _elevationAnimation.value : 1.0;

            return Transform.scale(
              scale: scale,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // 원근감
                  ..rotateX(0.1) // 약간의 X축 회전
                  ..rotateY(-0.1), // 약간의 Y축 회전
                alignment: Alignment.center,
                child: Container(
                  width: widget.buttonSize,
                  height: widget.buttonSize,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.buttonSize * 0.1,
                    horizontal: widget.buttonSize * 0.08,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (colors['bg'] as Color).withOpacity(0.95),
                        (colors['bg'] as Color).withOpacity(0.85),
                      ],
                    ),
                    border: Border.all(
                      color: colors['border'] as Color,
                      width: 4.0,
                    ),
                    boxShadow: [
                      // 오른쪽 하단 그림자 (아주 진하게, 선명하게)
                      BoxShadow(
                        color: Colors.black.withOpacity((0.8 * elevation).clamp(0.0, 1.0)),
                        blurRadius: 8 * elevation,
                        offset: Offset(8 * elevation, 8 * elevation),
                        spreadRadius: 0,
                      ),
                      // 클레이모피즘 내부 그림자
                      BoxShadow(
                        color: Colors.white.withOpacity((0.8 * elevation).clamp(0.0, 1.0)),
                        blurRadius: 20 * elevation,
                        offset: Offset(-6 * elevation, -6 * elevation),
                        spreadRadius: 0,
                      ),
                      // 클레이모피즘 외부 그림자 (아주 진하게, 선명하게)
                      BoxShadow(
                        color: (colors['border'] as Color).withOpacity((0.9 * elevation).clamp(0.0, 1.0)),
                        blurRadius: 8 * elevation,
                        offset: Offset(4 * elevation, 4 * elevation),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          // 360도 전방향 그림자 (흐릿하게)
                          BoxShadow(
                            color: (colors['icon'] as Color)
                                .withOpacity((0.2 * elevation).clamp(0.0, 1.0)),
                            blurRadius: 12 * elevation,
                            spreadRadius: 2 * elevation,
                          ),
                          BoxShadow(
                            color: (colors['icon'] as Color)
                                .withOpacity((0.15 * elevation).clamp(0.0, 1.0)),
                            blurRadius: 8 * elevation,
                            spreadRadius: 1 * elevation,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.iconSize * 0.7,
                        color: colors['icon'] as Color,
                      ),
                    ),
                    SizedBox(height: widget.buttonSize * 0.08),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.bold,
                        color: colors['text'] as Color,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                          Shadow(
                            color: Colors.white.withOpacity(0.8),
                            offset: const Offset(-1, -1),
                            blurRadius: 2,
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
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 전체 화면 어둡게
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '준비 중',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('$feature 기능은 곧 출시될 예정입니다!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
} 