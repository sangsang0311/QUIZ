import '../models/animal.dart';
import 'package:flutter/foundation.dart';

class AnimalService {
  // 동물 리스트 반환
  static List<Animal> getAnimals() {
    // 웹과 모바일에서 모두 작동하도록 경로 설정
    final String basePath = kIsWeb ? 'assets/' : 'assets/images/';
    
    return [
      Animal(
        id: '01',
        name: '토끼',
        imagePath: '${basePath}animal_01.jpg',
      ),
      Animal(
        id: '02',
        name: '고슴도치',
        imagePath: '${basePath}animal_02.jpg',
      ),
      Animal(
        id: '03',
        name: '래서판다',
        imagePath: '${basePath}animal_03.jpg',
      ),
      Animal(
        id: '04',
        name: '고양이',
        imagePath: '${basePath}animal_04.jpg',
      ),
      Animal(
        id: '05',
        name: '기린',
        imagePath: '${basePath}animal_05.jpg',
      ),
      Animal(
        id: '06',
        name: '코알라',
        imagePath: '${basePath}animal_06.jpg',
      ),
      Animal(
        id: '07',
        name: '팬더',
        imagePath: '${basePath}animal_07.jpg',
      ),
      Animal(
        id: '08',
        name: '다람쥐',
        imagePath: '${basePath}animal_08.jpg',
      ),
      Animal(
        id: '09',
        name: '사자',
        imagePath: '${basePath}animal_09.jpg',
      ),
      Animal(
        id: '10',
        name: '개',
        imagePath: '${basePath}animal_10.jpg',
      ),
    ];
  }
} 