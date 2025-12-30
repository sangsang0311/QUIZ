import '../models/fruit.dart';
import 'package:flutter/foundation.dart';

class FruitService {
  // 과일 리스트 반환
  static List<Fruit> getFruits() {
    // 웹과 모바일에서 모두 작동하도록 경로 설정
    final String basePath = kIsWeb ? 'assets/' : 'assets/images/';
    
    return [
      Fruit(
        id: '01',
        name: '바나나',
        imagePath: '${basePath}fruit_01.jpg',
      ),
      Fruit(
        id: '02',
        name: '레몬',
        imagePath: '${basePath}fruit_02.jpg',
      ),
      Fruit(
        id: '03',
        name: '딸기',
        imagePath: '${basePath}fruit_03.jpg',
      ),
      Fruit(
        id: '04',
        name: '오렌지',
        imagePath: '${basePath}fruit_04.jpg',
      ),
      Fruit(
        id: '05',
        name: '키위',
        imagePath: '${basePath}fruit_05.jpg',
      ),
      Fruit(
        id: '06',
        name: '사과',
        imagePath: '${basePath}fruit_06.jpg',
      ),
      Fruit(
        id: '07',
        name: '수박',
        imagePath: '${basePath}fruit_07.jpg',
      ),
      Fruit(
        id: '08',
        name: '포도',
        imagePath: '${basePath}fruit_08.jpg',
      ),
      Fruit(
        id: '09',
        name: '파인애플',
        imagePath: '${basePath}fruit_09.jpg',
      ),
      Fruit(
        id: '10',
        name: '체리',
        imagePath: '${basePath}fruit_10.jpg',
      ),
    ];
  }
} 