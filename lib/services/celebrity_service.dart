import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/celebrity.dart';

class CelebrityService {
  static final Random _random = Random();
  
  // 인스턴스 생성 없이 직접 호출 가능한 정적 메서드
  static List<Celebrity> getCelebrities() {
    // 웹과 모바일에서 모두 작동하도록 경로 설정
    final String basePath = kIsWeb ? 'assets/' : 'assets/images/';
    
    return [
      Celebrity(
        id: '01',
        name: '아이유', 
        imagePath: '${basePath}celebrity_01.jpg',
      ),
      Celebrity(
        id: '02',
        name: '박보검', 
        imagePath: '${basePath}celebrity_02.jpg',
      ),
      Celebrity(
        id: '03',
        name: '송혜교', 
        imagePath: '${basePath}celebrity_03.jpg',
      ),
      Celebrity(
        id: '04',
        name: '장동건', 
        imagePath: '${basePath}celebrity_04.jpg',
      ),
      Celebrity(
        id: '05',
        name: '이영애', 
        imagePath: '${basePath}celebrity_05.jpg',
      ),
      Celebrity(
        id: '06',
        name: '빅뱅 지드래곤', 
        imagePath: '${basePath}celebrity_06.jpg',
      ),
      Celebrity(
        id: '07',
        name: '김태희', 
        imagePath: '${basePath}celebrity_07.jpg',
      ),
      Celebrity(
        id: '08',
        name: '전지현', 
        imagePath: '${basePath}celebrity_08.jpg',
      ),
      Celebrity(
        id: '09',
        name: '이민호', 
        imagePath: '${basePath}celebrity_09.jpg',
      ),
      Celebrity(
        id: '10',
        name: '손예진', 
        imagePath: '${basePath}celebrity_10.jpg',
      ),
      Celebrity(
        id: '11',
        name: '박서준', 
        imagePath: '${basePath}celebrity_11.jpg',
      ),
      Celebrity(
        id: '12',
        name: '수지', 
        imagePath: '${basePath}celebrity_12.jpg',
      ),
      Celebrity(
        id: '13',
        name: '정해인', 
        imagePath: '${basePath}celebrity_13.jpg',
      ),
      Celebrity(
        id: '14',
        name: '한소희', 
        imagePath: '${basePath}celebrity_14.jpg',
      ),
      Celebrity(
        id: '15',
        name: '잔나비 최정훈', 
        imagePath: '${basePath}celebrity_15.jpg',
      ),
      Celebrity(
        id: '16',
        name: '마마무 화사', 
        imagePath: '${basePath}celebrity_16.jpg',
      ),
      Celebrity(
        id: '17',
        name: '방탄소년단 정국', 
        imagePath: '${basePath}celebrity_17.jpg',
      ),
      Celebrity(
        id: '18',
        name: '이하이', 
        imagePath: '${basePath}celebrity_18.jpg',
      ),
      Celebrity(
        id: '19',
        name: '에스파 카리나', 
        imagePath: '${basePath}celebrity_19.jpg',
      ),
      Celebrity(
        id: '20',
        name: '유재석', 
        imagePath: '${basePath}celebrity_20.jpg',
      ),
    ];
  }
  
  // JSON 파일에서 연예인 데이터 가져오기
  Future<List<Celebrity>> fetchCelebrities() async {
    // 샘플 데이터 반환
    return getCelebrities();
  }
  
  // 랜덤 연예인 가져오기
  Future<Celebrity?> getRandomCelebrity() async {
    final celebrities = await fetchCelebrities();
    if (celebrities.isEmpty) return null;
    
    return celebrities[_random.nextInt(celebrities.length)];
  }

  // Get a random subset of 10 celebrities for the quiz
  Future<List<Celebrity>> getQuizCelebrities() async {
    final List<Celebrity> allCelebrities = await fetchCelebrities();
    allCelebrities.shuffle();
    return allCelebrities.take(10).toList();
  }
} 