import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/quiz_provider.dart';
import 'screens/home_screen.dart';
import 'utils/sound_manager.dart';
import 'utils/storage_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundManager().init();
  // IndexedDB 초기화 (앱 시작 시 자동으로 데이터베이스 열기)
  await StorageManager.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => QuizProvider(),
      child: MaterialApp(
        title: '정답은?',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          // 시스템 기본 폰트 사용 (한글 깜빡임 완전 해결)
          // fontFamily 제거하여 시스템 기본 폰트 사용
          appBarTheme: const AppBarTheme(
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
        builder: (context, child) {
          // child는 Navigator를 포함한 전체 위젯 트리 (다이얼로그 포함)
          // child를 제한하지 않아서 다이얼로그 barrier가 전체 화면을 덮을 수 있도록 함
          // 각 화면에서 중앙 60%만 사용하도록 레이아웃 설정
          return LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              
              // 배경 레이어 (전체 화면)
              return Container(
                width: screenWidth,
                height: screenHeight,
                color: const Color(0xFFCFF1EF), // 전체 배경색 (파란색)
                child: child, // child는 제한 없이 전체 화면에 배치 (다이얼로그가 전체 화면을 덮을 수 있도록)
              );
            },
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
