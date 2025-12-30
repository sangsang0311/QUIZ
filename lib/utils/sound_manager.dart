import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _hoverPlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _beepPlayer = AudioPlayer();
  final AudioPlayer _answerPlayer = AudioPlayer();
  bool _soundEnabled = true;
  double _volume = 1.0; // 기본 볼륨 (0.0 ~ 1.0)
  bool _userInteracted = false; // 사용자가 상호작용했는지 여부 (웹 자동 재생 정책 대응)

  Future<void> init() async {
    try {
      await _hoverPlayer.setAsset('assets/sounds/hover.wav');
      await _clickPlayer.setAsset('assets/sounds/click.wav');
      await _beepPlayer.setAsset('assets/sounds/beep.flac');
      await _answerPlayer.setAsset('assets/sounds/answer.wav');
      
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _volume = prefs.getDouble('soundVolume') ?? 1.0;
      
      // 볼륨은 0.0 ~ 1.0 범위로 제한 (HTMLMediaElement 제약)
      // 호버 사운드는 기본적으로 더 크게 (최대 1.0으로 제한)
      await _hoverPlayer.setVolume((_volume * 1.5).clamp(0.0, 1.0));
      await _clickPlayer.setVolume(_volume);
      await _beepPlayer.setVolume(_volume);
      await _answerPlayer.setVolume(_volume);
    } catch (e) {
      debugPrint('사운드 초기화 오류: $e');
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _volume = prefs.getDouble('soundVolume') ?? 1.0;
    
    // 볼륨 적용 (0.0 ~ 1.0 범위로 제한)
    await _hoverPlayer.setVolume((_volume * 1.5).clamp(0.0, 1.0));
    await _clickPlayer.setVolume(_volume);
    await _beepPlayer.setVolume(_volume);
    await _answerPlayer.setVolume(_volume);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('soundVolume', _volume);
    
    // 볼륨 적용 (0.0 ~ 1.0 범위로 제한)
    await _hoverPlayer.setVolume((_volume * 1.5).clamp(0.0, 1.0));
    await _clickPlayer.setVolume(_volume);
    await _beepPlayer.setVolume(_volume);
    await _answerPlayer.setVolume(_volume);
  }

  double getVolume() => _volume;

  Future<void> playHover() async {
    if (!_soundEnabled || !_userInteracted) return; // 사용자가 상호작용하기 전에는 재생하지 않음
    try {
      // 재생 중이면 중지하고 처음부터 재생
      if (_hoverPlayer.playing) {
        await _hoverPlayer.stop();
      }
      await _hoverPlayer.seek(Duration.zero);
      // 볼륨이 0이 아닌 경우에만 재생
      if (_volume > 0) {
        await _hoverPlayer.setSpeed(1.5); // 1.5배 빠르게 재생
        await _hoverPlayer.play();
      }
    } catch (e) {
      // 오류를 조용히 무시 (자동 재생 정책 오류는 정상)
      // debugPrint('호버 사운드 재생 오류: $e');
    }
  }

  Future<void> playClick() async {
    if (!_soundEnabled) return;
    // 클릭은 사용자 상호작용이므로 항상 허용됨
    _userInteracted = true;
    try {
      // 재생 중이면 중지하고 처음부터 재생
      if (_clickPlayer.playing) {
        await _clickPlayer.stop();
      }
      await _clickPlayer.seek(Duration.zero);
      await _clickPlayer.setSpeed(1.5); // 1.5배 빠르게 재생
      await _clickPlayer.play();
    } catch (e) {
      debugPrint('클릭 사운드 재생 오류: $e');
    }
  }

  Future<void> playBeep() async {
    if (!_soundEnabled) return;
    try {
      // 재생 중이면 중지하고 처음부터 재생
      if (_beepPlayer.playing) {
        await _beepPlayer.stop();
      }
      await _beepPlayer.seek(Duration.zero);
      await _beepPlayer.setSpeed(1.5); // 1.5배 빠르게 재생
      await _beepPlayer.play();
    } catch (e) {
      debugPrint('비프 사운드 재생 오류: $e');
    }
  }

  Future<void> playAnswer() async {
    if (!_soundEnabled) return;
    try {
      // 재생 중이면 중지하고 처음부터 재생
      if (_answerPlayer.playing) {
        await _answerPlayer.stop();
      }
      await _answerPlayer.seek(Duration.zero);
      await _answerPlayer.setSpeed(1.0); // 정상 속도로 재생
      await _answerPlayer.play();
    } catch (e) {
      debugPrint('정답 사운드 재생 오류: $e');
    }
  }

  void dispose() {
    _hoverPlayer.dispose();
    _clickPlayer.dispose();
    _beepPlayer.dispose();
    _answerPlayer.dispose();
  }
}

