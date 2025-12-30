import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final VoidCallback? onRestartQuiz;

  const ResultScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    this.onRestartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final int wrongAnswers = totalQuestions - correctAnswers;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final centerWidth = screenWidth * 0.60;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // 메인화면과 동일한 배경색
        color: const Color(0xFFCFF1EF),
        child: Center(
          child: SizedBox(
            width: centerWidth,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 화면 높이에 맞춰 크기 조정
                  final availableHeight = constraints.maxHeight;
                  final isSmallScreen = availableHeight < 700;
                  
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: availableHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 모든 위젯을 감싸는 큰 흰색 카드
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 28 : 36),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFB8E5E2), // 메인화면 배경색보다 조금 더 진한 색
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 상단 타이틀
                                  _AnimatedTitle(isSmallScreen: isSmallScreen),
                                  
                                  SizedBox(height: isSmallScreen ? 30 : 40),
                                  
                                  // 통계 카드들 (Wrap 사용)
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      // 전체 문제 수
                                      _AnimatedStatCard(
                                        icon: Icons.help_outline_rounded,
                                        label: '전체',
                                        value: totalQuestions.toString(),
                                        color: const Color(0xFF5C6BC0),
                                        isSmallScreen: isSmallScreen,
                                        delay: 0,
                                      ),
                                      
                                      // 정답 수
                                      _AnimatedStatCard(
                                        icon: Icons.check_circle_rounded,
                                        label: '정답',
                                        value: correctAnswers.toString(),
                                        color: const Color(0xFF4CAF50),
                                        isSmallScreen: isSmallScreen,
                                        delay: 200,
                                      ),
                                      
                                      // 오답 수
                                      _AnimatedStatCard(
                                        icon: Icons.cancel_rounded,
                                        label: '오답',
                                        value: wrongAnswers.toString(),
                                        color: const Color(0xFFE53935),
                                        isSmallScreen: isSmallScreen,
                                        delay: 400,
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: isSmallScreen ? 30 : 40),
                                  
                                  // 홈 버튼
                                  _AnimatedHomeButton(isSmallScreen: isSmallScreen),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: isSmallScreen ? 20 : 30),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 애니메이션 타이틀 위젯
class _AnimatedTitle extends StatefulWidget {
  final bool isSmallScreen;
  
  const _AnimatedTitle({required this.isSmallScreen});
  
  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Column(
              children: [
                Icon(
                  Icons.quiz_rounded,
                  size: widget.isSmallScreen ? 60 : 70,
                  color: const Color(0xFF4AA0A9),
                ),
                SizedBox(height: widget.isSmallScreen ? 12 : 16),
                Text(
                  '퀴즈 결과',
                  style: TextStyle(
                    fontSize: widget.isSmallScreen ? 36 : 42,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2C3E50),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 애니메이션 통계 카드 위젯
class _AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isSmallScreen;
  final int delay;
  
  const _AnimatedStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isSmallScreen,
    required this.delay,
  });
  
  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // 딜레이 후 애니메이션 시작
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.isSmallScreen ? 140.0 : 160.0;
    final iconSize = widget.isSmallScreen ? 24.0 : 28.0;
    final valueFontSize = widget.isSmallScreen ? 36.0 : 42.0;
    final labelFontSize = widget.isSmallScreen ? 16.0 : 18.0;
    final padding = widget.isSmallScreen ? 24.0 : 28.0;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // scale이 0이 되지 않도록 최소값 설정
        final scale = _scaleAnimation.value.clamp(0.01, 1.0);
        final opacity = _fadeAnimation.value.clamp(0.0, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: cardWidth,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: padding, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: widget.isSmallScreen ? 50 : 56,
                      height: widget.isSmallScreen ? 50 : 56,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(height: widget.isSmallScreen ? 12 : 16),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w900,
                        color: widget.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: widget.isSmallScreen ? 6 : 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 애니메이션 홈 버튼 위젯
class _AnimatedHomeButton extends StatefulWidget {
  final bool isSmallScreen;
  
  const _AnimatedHomeButton({required this.isSmallScreen});
  
  @override
  State<_AnimatedHomeButton> createState() => _AnimatedHomeButtonState();
}

class _AnimatedHomeButtonState extends State<_AnimatedHomeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // 딜레이 후 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final buttonHeight = widget.isSmallScreen ? 60.0 : 65.0;
    final fontSize = widget.isSmallScreen ? 20.0 : 22.0;
    final iconSize = widget.isSmallScreen ? 24.0 : 26.0;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // scale이 0이 되지 않도록 최소값 설정
        final scale = _scaleAnimation.value.clamp(0.01, 1.0);
        final opacity = _fadeAnimation.value.clamp(0.0, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              height: buttonHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4AA0A9),
                    Color(0xFF3A8A93),
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.isSmallScreen ? 30 : 32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4AA0A9).withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  borderRadius: BorderRadius.circular(widget.isSmallScreen ? 30 : 32),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.isSmallScreen ? 30 : 32),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: widget.isSmallScreen ? 44 : 48,
                          height: widget.isSmallScreen ? 44 : 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: widget.isSmallScreen ? 14 : 16),
                        Text(
                          '메인화면으로',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
