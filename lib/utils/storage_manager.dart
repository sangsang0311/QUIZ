import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb.dart' show idbModeReadWrite, idbModeReadOnly;
import '../models/custom_quiz.dart';

/// 통합 저장소 매니저
/// 웹: IndexedDB 사용, 앱: SQLite 사용
class StorageManager {
  static sql.Database? _database;
  static dynamic _idbDatabase; // idb.Database from idb_shim
  static const String _dbName = 'quiz_storage';
  static const String _storeName = 'quizzes';
  static const int _dbVersion = 1;

  /// 저장소 초기화
  static Future<void> init() async {
    if (kIsWeb) {
      if (_idbDatabase == null) {
        try {
          final idbFactory = getIdbFactory();
          if (idbFactory == null) {
            throw Exception('IndexedDB is not supported');
          }
          
          // 데이터베이스 열기 - 기존 데이터베이스가 있으면 그대로 열기
          // onUpgradeNeeded는 데이터베이스가 처음 생성될 때만 호출됨
          // 기존 데이터베이스가 있으면 onUpgradeNeeded가 호출되지 않음
          bool upgradeNeededCalled = false;
          
          _idbDatabase = await idbFactory.open(
            _dbName,
            version: _dbVersion,
            onUpgradeNeeded: (e) {
              upgradeNeededCalled = true;
              final db = e.database;
              // oldVersion이 0이면 새로 생성되는 경우만 objectStore 생성
              if (e.oldVersion == 0) {
                print('⚠️ IndexedDB 새로 생성 중... 버전: ${e.oldVersion} -> ${e.newVersion} (기존 데이터베이스 없음)');
                if (!db.objectStoreNames.contains(_storeName)) {
                  db.createObjectStore(_storeName, keyPath: 'id');
                  print('IndexedDB objectStore 생성: $_storeName');
                }
              } else {
                // 업그레이드인 경우 - 기존 데이터 보존, objectStore는 그대로 유지
                print('⚠️ IndexedDB 업그레이드 중... 버전: ${e.oldVersion} -> ${e.newVersion} (기존 데이터 보존)');
                if (!db.objectStoreNames.contains(_storeName)) {
                  db.createObjectStore(_storeName, keyPath: 'id');
                  print('IndexedDB objectStore 생성: $_storeName (업그레이드 중)');
                } else {
                  print('IndexedDB objectStore 이미 존재: $_storeName (업그레이드 중, 데이터 보존)');
                }
              }
            },
          );
          
          // onUpgradeNeeded가 호출되었는지 확인
          if (upgradeNeededCalled) {
            print('⚠️ 경고: onUpgradeNeeded가 호출되었습니다. 데이터베이스가 새로 생성되었거나 업그레이드되었습니다.');
          } else {
            print('✅ IndexedDB 기존 데이터베이스를 그대로 열었습니다: $_dbName (업그레이드 없음)');
          }
          
          // objectStore 확인
          final hasStore = _idbDatabase!.objectStoreNames.contains(_storeName);
          print('IndexedDB 초기화 완료. 데이터베이스 이름: $_dbName, objectStore 존재: $hasStore');
          print('IndexedDB objectStore 목록: ${_idbDatabase!.objectStoreNames.toList()}');
          
          // 기존 데이터 확인 (데이터베이스가 이미 존재하는지 확인)
          if (hasStore) {
            try {
              final checkTransaction = _idbDatabase!.transaction([_storeName], idbModeReadOnly);
              final checkStore = checkTransaction.objectStore(_storeName);
              final existingData = await checkStore.getAll();
              await checkTransaction.completed;
              print('IndexedDB 기존 데이터 확인: ${existingData.length}개 항목 존재');
            } catch (e) {
              print('IndexedDB 기존 데이터 확인 오류: $e');
            }
          }
          
          if (!hasStore) {
            print('경고: IndexedDB objectStore가 없습니다. 데이터베이스를 다시 열어야 할 수 있습니다.');
          } else {
            print('IndexedDB $_dbName 데이터베이스가 성공적으로 열렸습니다.');
          }
        } catch (e) {
          print('IndexedDB 초기화 오류: $e');
          _idbDatabase = null;
          rethrow;
        }
      } else {
        // 이미 초기화된 경우 objectStore 확인
        if (!_idbDatabase!.objectStoreNames.contains(_storeName)) {
          print('경고: IndexedDB objectStore가 없습니다. 재초기화 필요.');
          _idbDatabase!.close();
          _idbDatabase = null;
          await init(); // 재귀 호출로 재초기화
        }
      }
    } else {
      if (_database == null) {
        final databasesPath = await sql.getDatabasesPath();
        final dbPath = path.join(databasesPath, '$_dbName.db');
        _database = await sql.openDatabase(
          dbPath,
          version: _dbVersion,
          onCreate: (db, version) {
            db.execute('''
              CREATE TABLE quizzes (
                id TEXT PRIMARY KEY,
                quizType TEXT NOT NULL,
                title TEXT NOT NULL,
                category TEXT,
                subCategory TEXT,
                questions TEXT NOT NULL,
                createdAt TEXT NOT NULL
              )
            ''');
          },
        );
      }
    }
  }

  /// 퀴즈 저장
  static Future<void> saveQuiz(CustomQuiz quiz) async {
    if (kIsWeb) {
      await _saveQuizWeb(quiz);
    } else {
      await _saveQuizApp(quiz);
    }
  }

  /// 웹용 저장 (IndexedDB)
  static Future<void> _saveQuizWeb(CustomQuiz quiz) async {
    // 초기화 확인 및 재시도
    int retryCount = 0;
    while (_idbDatabase == null && retryCount < 3) {
      await init();
      retryCount++;
      if (_idbDatabase == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    if (_idbDatabase == null) {
      print('IndexedDB가 초기화되지 않았습니다. 저장 실패.');
      throw Exception('IndexedDB 초기화 실패');
    }

    if (!_idbDatabase!.objectStoreNames.contains(_storeName)) {
      print('IndexedDB objectStore가 없습니다. 재초기화 시도...');
      _idbDatabase!.close();
      _idbDatabase = null;
      await init();
      
      if (_idbDatabase == null || !_idbDatabase!.objectStoreNames.contains(_storeName)) {
        print('IndexedDB objectStore 생성 실패. 저장 불가.');
        throw Exception('IndexedDB objectStore 생성 실패');
      }
    }

    try {
      // 새로운 트랜잭션 생성 (명시적으로 커밋되도록)
      final transaction = _idbDatabase!.transaction([_storeName], idbModeReadWrite);
      final store = transaction.objectStore(_storeName);
      final quizJson = quiz.toJson();
      
      print('저장 시작: ${quiz.id}, 카테고리: ${quiz.category}');
      print('저장할 데이터 크기: ${quizJson.toString().length} bytes');
      print('저장할 데이터 키: ${quizJson['id']}');
      
      // 저장 실행 - put 메서드 호출
      // idb_shim의 put은 Future를 반환하지 않으므로 트랜잭션 완료를 기다려야 함
      // 하지만 put 자체도 await 가능한 경우가 있으므로 시도
      try {
        // put이 Future를 반환하는지 확인
        final putResult = store.put(quizJson);
        if (putResult is Future) {
          await putResult;
          print('store.put() 완료 (Future 반환)');
        } else {
          print('store.put() 호출 완료 (동기)');
        }
      } catch (e) {
        // put이 Future를 반환하지 않는 경우
        store.put(quizJson);
        print('store.put() 호출 완료 (동기, 예외 처리)');
      }
      
      // 트랜잭션 완료 대기 (중요: 이게 완료되어야 실제로 저장됨)
      // transaction.completed는 트랜잭션이 커밋될 때까지 기다림
      await transaction.completed;
      print('트랜잭션 완료 (커밋됨): ${quiz.id}, 카테고리: ${quiz.category}');
      
      // 데이터베이스 연결을 명시적으로 유지 (닫지 않음)
      // IndexedDB는 연결이 열려있을 때만 데이터가 영구 저장됨
      // 브라우저가 닫힐 때까지 연결을 유지해야 함
      
      // IndexedDB가 디스크에 쓰기를 완료할 때까지 짧은 지연
      // 브라우저가 닫히기 전에 저장이 완료되도록 함
      // IndexedDB는 비동기적으로 디스크에 쓰므로 짧은 시간 필요
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 저장 완료 (검증 로직 제거로 저장 시간 단축)
      print('퀴즈 저장 완료: ${quiz.id}, 카테고리: ${quiz.category}');
    } catch (e) {
      print('퀴즈 저장 오류: $e');
      rethrow;
    }
  }

  /// 앱용 저장 (SQLite)
  static Future<void> _saveQuizApp(CustomQuiz quiz) async {
    if (_database == null) {
      await init();
    }

    final existingQuiz = await _database!.query(
      'quizzes',
      where: 'id = ?',
      whereArgs: [quiz.id],
    );

    if (existingQuiz.isNotEmpty) {
      // 업데이트
      await _database!.update(
        'quizzes',
        {
          'quizType': quiz.quizType,
          'title': quiz.title,
          'category': quiz.category,
          'subCategory': quiz.subCategory,
          'questions': jsonEncode(quiz.questions.map((q) => q.toJson()).toList()),
          'createdAt': quiz.createdAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quiz.id],
      );
    } else {
      // 새로 추가
      await _database!.insert(
        'quizzes',
        {
          'id': quiz.id,
          'quizType': quiz.quizType,
          'title': quiz.title,
          'category': quiz.category,
          'subCategory': quiz.subCategory,
          'questions': jsonEncode(quiz.questions.map((q) => q.toJson()).toList()),
          'createdAt': quiz.createdAt.toIso8601String(),
        },
      );
    }
  }

  /// 모든 퀴즈 로드
  static Future<List<CustomQuiz>> loadQuizzes({String? quizType}) async {
    if (kIsWeb) {
      return await _loadQuizzesWeb(quizType: quizType);
    } else {
      return await _loadQuizzesApp(quizType: quizType);
    }
  }

  /// 웹용 로드 (IndexedDB)
  static Future<List<CustomQuiz>> _loadQuizzesWeb({String? quizType}) async {
    // 초기화 확인 및 재시도
    int retryCount = 0;
    while (_idbDatabase == null && retryCount < 3) {
      await init();
      retryCount++;
      if (_idbDatabase == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    if (_idbDatabase == null) {
      print('IndexedDB가 초기화되지 않았습니다.');
      return [];
    }

    if (!_idbDatabase!.objectStoreNames.contains(_storeName)) {
      print('IndexedDB objectStore가 없습니다. 재초기화 시도...');
      _idbDatabase!.close();
      _idbDatabase = null;
      await init();
      
      if (_idbDatabase == null || !_idbDatabase!.objectStoreNames.contains(_storeName)) {
        print('IndexedDB objectStore 생성 실패. 빈 리스트 반환.');
        return [];
      }
    }

    try {
      final transaction = _idbDatabase!.transaction([_storeName], idbModeReadOnly);
      final store = transaction.objectStore(_storeName);
      final allData = await store.getAll();
      
      print('IndexedDB에서 ${allData.length}개의 데이터 로드 (quizType: $quizType)');
      
      final List<CustomQuiz> quizzes = [];
      for (final quizJson in allData) {
        if (quizJson is Map<String, dynamic>) {
          if (quizType == null || quizJson['quizType'] == quizType) {
            try {
              quizzes.add(CustomQuiz.fromJson(quizJson));
            } catch (e) {
              print('퀴즈 로드 오류: $e, 데이터: $quizJson');
            }
          }
        }
      }

      print('로드된 퀴즈 수: ${quizzes.length}');
      return quizzes;
    } catch (e) {
      print('퀴즈 로드 오류: $e');
      return [];
    }
  }

  /// 앱용 로드 (SQLite)
  static Future<List<CustomQuiz>> _loadQuizzesApp({String? quizType}) async {
    if (_database == null) {
      await init();
    }

    List<Map<String, dynamic>> maps;
    if (quizType != null) {
      maps = await _database!.query(
        'quizzes',
        where: 'quizType = ?',
        whereArgs: [quizType],
        orderBy: 'createdAt DESC',
      );
    } else {
      maps = await _database!.query(
        'quizzes',
        orderBy: 'createdAt DESC',
      );
    }

    return maps.map((map) {
      return CustomQuiz(
        id: map['id'],
        quizType: map['quizType'],
        title: map['title'],
        category: map['category'],
        subCategory: map['subCategory'],
        questions: (jsonDecode(map['questions']) as List)
            .map((q) => CustomQuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(map['createdAt']),
      );
    }).toList();
  }

  /// 퀴즈를 JSON 문자열로 내보내기 (단일)
  static String exportQuizToJson(CustomQuiz quiz) {
    return jsonEncode(quiz.toJson());
  }

  /// 모든 퀴즈를 JSON 문자열로 내보내기
  static Future<String> exportAllQuizzesToJson() async {
    final allQuizzes = await loadQuizzes();
    return jsonEncode({
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'quizzes': allQuizzes.map((q) => q.toJson()).toList(),
    });
  }

  /// JSON 문자열에서 퀴즈 불러오기 (단일)
  static CustomQuiz importQuizFromJson(String jsonString) {
    final json = jsonDecode(jsonString);
    if (json is Map && json.containsKey('quizzes')) {
      // 내보내기 형식 (version 포함)
      final quizzes = (json['quizzes'] as List);
      if (quizzes.isEmpty) {
        throw Exception('퀴즈가 없습니다.');
      }
      return CustomQuiz.fromJson(quizzes.first);
    } else {
      // 단일 퀴즈 형식
      return CustomQuiz.fromJson(json);
    }
  }

  /// JSON 문자열에서 여러 퀴즈 불러오기
  static Future<List<CustomQuiz>> importQuizzesFromJson(String jsonString) async {
    final json = jsonDecode(jsonString);
    List<CustomQuiz> quizzes = [];
    
    if (json is List) {
      // 단순 배열 형식
      quizzes = json.map((q) => CustomQuiz.fromJson(q as Map<String, dynamic>)).toList();
    } else if (json is Map && json.containsKey('quizzes')) {
      // 내보내기 형식 (version 포함)
      quizzes = (json['quizzes'] as List)
          .map((q) => CustomQuiz.fromJson(q as Map<String, dynamic>))
          .toList();
    } else {
      // 단일 퀴즈 형식
      quizzes = [CustomQuiz.fromJson(json as Map<String, dynamic>)];
    }
    
    // 중복 확인 및 저장
    final existingQuizzes = await loadQuizzes();
    final existingIds = existingQuizzes.map((q) => q.id).toSet();
    
    int importedCount = 0;
    
    for (final quiz in quizzes) {
      if (existingIds.contains(quiz.id)) {
        // ID가 같으면 새 ID 생성
        final newId = DateTime.now().millisecondsSinceEpoch.toString() + '_imported';
        final newQuiz = CustomQuiz(
          id: newId,
          quizType: quiz.quizType,
          title: '${quiz.title} (가져옴)',
          category: quiz.category,
          subCategory: quiz.subCategory,
          questions: quiz.questions,
          createdAt: DateTime.now(),
        );
        await saveQuiz(newQuiz);
        importedCount++;
      } else {
        await saveQuiz(quiz);
        importedCount++;
      }
    }
    
    return quizzes;
  }

  /// 퀴즈 삭제
  static Future<void> deleteQuiz(String id, String quizType) async {
    if (kIsWeb) {
      await _deleteQuizWeb(id);
    } else {
      await _deleteQuizApp(id);
    }
  }

  /// 웹용 삭제 (IndexedDB)
  static Future<void> _deleteQuizWeb(String id) async {
    if (_idbDatabase == null) {
      await init();
    }
    if (_idbDatabase == null) return;

    if (!_idbDatabase!.objectStoreNames.contains(_storeName)) {
      return;
    }

    final transaction = _idbDatabase!.transaction([_storeName], idbModeReadWrite);
    final store = transaction.objectStore(_storeName);
    await store.delete(id);
    await transaction.completed;
  }

  /// 앱용 삭제 (SQLite)
  static Future<void> _deleteQuizApp(String id) async {
    if (_database == null) {
      await init();
    }

    await _database!.delete(
      'quizzes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 저장소 닫기
  static Future<void> close() async {
    if (!kIsWeb && _database != null) {
      await _database!.close();
      _database = null;
    } else if (kIsWeb && _idbDatabase != null) {
      _idbDatabase!.close();
      _idbDatabase = null;
    }
  }
}
