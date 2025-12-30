// 텍스트 퀴즈 데이터
class TextQuizData {
  // 수도 퀴즈
  static List<Map<String, String>> get capitalQuizzes => [
    {'question': '한국의 수도는?', 'answer': '서울'},
    {'question': '일본의 수도는?', 'answer': '도쿄'},
    {'question': '미국의 수도는?', 'answer': '워싱턴 D.C'},
    {'question': '중국의 수도는?', 'answer': '베이징'},
    {'question': '프랑스의 수도는?', 'answer': '파리'},
    {'question': '영국의 수도는?', 'answer': '런던'},
    {'question': '독일의 수도는?', 'answer': '베를린'},
    {'question': '이탈리아의 수도는?', 'answer': '로마'},
    {'question': '스페인의 수도는?', 'answer': '마드리드'},
    {'question': '러시아의 수도는?', 'answer': '모스크바'},
  ];

  // 속담 퀴즈
  static List<Map<String, String>> get proverbQuizzes => [
    {'question': '말을 좋게 하면 상대도 좋게 말함', 'answer': '가는 말이 고와야 오는 말이 곱다'},
    {'question': '평소에 하던 말이나 행동이 결국 드러남', 'answer': '호랑이도 제 말하면 온다'},
    {'question': '일이 이미 잘못된 뒤에야 후회하며 고침', 'answer': '소 잃고 외양간 고친다'},
    {'question': '고생을 많이 한 뒤에는 좋은 일이 옴', 'answer': '고생 끝에 낙이 온다'},
    {'question': '자신의 과거를 잊고 남을 탓함', 'answer': '개구리 올챙이 적 생각 못한다'},
    {'question': '가까운 곳에 있는 것을 오히려 알아보지 못함', 'answer': '등잔 밑이 어둡다'},
    {'question': '직접 보는 것이 백 번 듣는 것보다 나음', 'answer': '백문이 불여 일견'},
    {'question': '아무리 쉬운 말이라도 말 한마디로 큰 이익이나 손해가 생김', 'answer': '말 한마디로 천 냥 빚 갚는다'},
    {'question': '항상 함께 따라다니는 관계', 'answer': '바늘 가는 데 실 간다'},
    {'question': '하기 매우 어려운 일', 'answer': '하늘의 별 따기'},
  ];

  // 초성 퀴즈 (서브 카테고리별)
  static Map<String, List<Map<String, String>>> get initialQuizzes => {
    '영화제목': [
      {'question': 'ㄱㅅㅊ', 'answer': '기생충'},
      {'question': 'ㅇㅅ', 'answer': '암살'},
      {'question': 'ㄷㄷㄷ', 'answer': '도둑들'},
      {'question': 'ㅂㅅㅎ', 'answer': '부산행'},
      {'question': 'ㄱㅈㅅㅈ', 'answer': '국제시장'},
      {'question': 'ㅅㄱㅎㄲ', 'answer': '신과함께'},
      {'question': 'ㄴㅂㅈㄷ', 'answer': '내부자들'},
      {'question': 'ㅊㅈㅎ ㄱㅈㅆ', 'answer': '친절한 금자씨'},
      {'question': 'ㅂㅈㄷㅅ', 'answer': '범죄도시'},
      {'question': 'ㄱㅎㅈㅇ', 'answer': '극한직업'},
    ],
    '드라마제목': [
      {'question': 'ㅇㅈㅇㄱㅇ', 'answer': '오징어게임'},
      {'question': 'ㄷㄲㅂ', 'answer': '도깨비'},
      {'question': 'ㅇㅌㅇ ㅋㄹㅆ', 'answer': '이태원 클라쓰'},
      {'question': 'ㅂㅂㅇ ㅅㄱ', 'answer': '부부의 세계'},
      {'question': 'ㅁㅅㅌ ㅅㅅㅇ', 'answer': '미스터 선샤인'},
      {'question': 'ㅈㄱㄷㅅ', 'answer': '조각도시'},
      {'question': 'ㅂㅇㅅ ㅇ ㄱㄷ', 'answer': '별에서 온 그대'},
      {'question': 'ㅁㅂㅌㅅ', 'answer': '모범택시'},
      {'question': 'ㅈㅂㅈ ㅁㄴㅇㄷ', 'answer': '재벌집 막내아들'},
      {'question': 'ㅎㅌ ㄷㄹㄴ', 'answer': '호텔 델루나'},
    ],
    '음식': [
      {'question': 'ㄱㅂ', 'answer': '김밥'},
      {'question': 'ㄸㅂㅇ', 'answer': '떡볶이'},
      {'question': 'ㅂㅂㅂ', 'answer': '비빔밥'},
      {'question': 'ㅉㅈㅁ', 'answer': '짜장면'},
      {'question': 'ㄹㅁ', 'answer': '라면'},
      {'question': 'ㅅㄱㅅ', 'answer': '삼겹살'},
      {'question': 'ㄷㄲㅅ', 'answer': '돈까스'},
      {'question': 'ㅌㄱ', 'answer': '튀김'},
      {'question': 'ㅍㅈ', 'answer': '피자'},
      {'question': 'ㅊㅋ', 'answer': '치킨'},
    ],
    '동물': [
      {'question': 'ㄱㅇㅈ', 'answer': '강아지'},
      {'question': 'ㄱㅇㅇ', 'answer': '고양이'},
      {'question': 'ㅎㄹㅇ', 'answer': '호랑이'},
      {'question': 'ㅅㅈ', 'answer': '사자'},
      {'question': 'ㅋㄲㄹ', 'answer': '코끼리'},
      {'question': 'ㄱㄹ', 'answer': '기린'},
      {'question': 'ㅇㅅㅇ', 'answer': '원숭이'},
      {'question': 'ㅍㄷ', 'answer': '팬더'},
      {'question': 'ㄷㄱㄹ', 'answer': '돌고래'},
      {'question': 'ㄴㄱㄹ', 'answer': '너구리'},
    ],
  };

  // 사자성어 퀴즈
  static List<Map<String, String>> get idiomQuizzes => [
    {'question': '같은 배를 타고 함께 간다', 'answer': '동주공제'},
    {'question': '한 번에 두 가지 이익을 얻는다', 'answer': '일석이조'},
    {'question': '위기를 기회로 바꾼다', 'answer': '전화위복'},
    {'question': '노력한 만큼 결과를 얻는다', 'answer': '자업자득'},
    {'question': '말과 행동이 같다', 'answer': '언행일치'},
    {'question': '매우 간절한 마음', 'answer': '절박지심'},
    {'question': '때를 놓치면 소용없다', 'answer': '후회막급'},
    {'question': '서로 돕고 의지한다', 'answer': '상부상조'},
    {'question': '계속 노력하면 결국 성공한다', 'answer': '유종의미'},
    {'question': '많은 노력 끝에 성과를 이룬다', 'answer': '고진감래'},
  ];
}









