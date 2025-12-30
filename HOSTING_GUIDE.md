# Flutter 웹 앱 호스팅 가이드

이 가이드는 Flutter 웹 앱을 호스팅하는 여러 방법을 안내합니다.

## 📋 사전 준비

### 1. 웹 빌드 생성

먼저 Flutter 웹 앱을 빌드해야 합니다:

```bash
flutter build web --release
```

빌드가 완료되면 `build/web` 폴더에 정적 파일들이 생성됩니다.

---

## 🚀 호스팅 방법

### 방법 1: Firebase Hosting (추천) ⭐

**장점:**
- Google의 안정적인 인프라
- 무료 플랜 제공 (충분한 용량)
- HTTPS 자동 설정
- CDN 제공으로 빠른 속도
- 커스텀 도메인 지원

**설정 방법:**

1. **Firebase CLI 설치**
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase 로그인**
   ```bash
   firebase login
   ```

3. **프로젝트 초기화**
   ```bash
   firebase init hosting
   ```
   - "Use an existing project" 선택 또는 새 프로젝트 생성
   - Public directory: `build/web` 입력
   - Single-page app: `Yes`
   - Set up automatic builds: `No` (선택사항)

4. **배포**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

5. **결과**
   - `https://your-project-id.web.app` 또는 `https://your-project-id.firebaseapp.com`에서 접속 가능

---

### 방법 2: Netlify

**장점:**
- 매우 간단한 설정
- 무료 플랜 제공
- 자동 HTTPS
- 드래그 앤 드롭 배포 가능

**설정 방법:**

1. **Netlify 사이트 접속**
   - https://www.netlify.com 접속
   - 회원가입/로그인

2. **배포 방법 A: 드래그 앤 드롭**
   - `flutter build web --release` 실행
   - `build/web` 폴더를 Netlify 대시보드에 드래그 앤 드롭

3. **배포 방법 B: Netlify CLI**
   ```bash
   npm install -g netlify-cli
   netlify login
   flutter build web --release
   netlify deploy --prod --dir=build/web
   ```

4. **결과**
   - `https://random-name-12345.netlify.app` 같은 URL 제공
   - 커스텀 도메인 설정 가능

---

### 방법 3: GitHub Pages

**장점:**
- GitHub 사용자에게 친숙
- 완전 무료
- 버전 관리와 통합

**설정 방법:**

1. **GitHub 저장소 생성**
   - GitHub에 새 저장소 생성

2. **프로젝트 설정**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/yourusername/your-repo.git
   git push -u origin main
   ```

3. **GitHub Actions 워크플로우 생성**
   - `.github/workflows/deploy.yml` 파일 생성:

   ```yaml
   name: Deploy Flutter Web to GitHub Pages
   
   on:
     push:
       branches: [ main ]
   
   jobs:
     build-and-deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: subosito/flutter-action@v2
           with:
             flutter-version: '3.24.0'
         - run: flutter pub get
         - run: flutter build web --release
         - uses: peaceiris/actions-gh-pages@v3
           with:
             github_token: ${{ secrets.GITHUB_TOKEN }}
             publish_dir: ./build/web
   ```

4. **GitHub Pages 활성화**
   - 저장소 Settings > Pages
   - Source: `gh-pages` 브랜치 선택

5. **결과**
   - `https://yourusername.github.io/your-repo/` 에서 접속 가능

---

### 방법 4: Vercel

**장점:**
- 매우 빠른 배포
- 자동 HTTPS
- 무료 플랜 제공
- GitHub 연동 쉬움

**설정 방법:**

1. **Vercel CLI 설치**
   ```bash
   npm install -g vercel
   ```

2. **배포**
   ```bash
   flutter build web --release
   cd build/web
   vercel --prod
   ```

3. **또는 Vercel 웹사이트에서**
   - https://vercel.com 접속
   - GitHub 저장소 연결
   - Build Command: `flutter build web --release`
   - Output Directory: `build/web`

---

## 🔧 추가 설정

### base href 설정

일부 호스팅 환경에서는 `base href`를 설정해야 할 수 있습니다.

`web/index.html`에서 확인:
```html
<base href="/">
```

서브디렉토리에 배포하는 경우:
```html
<base href="/your-app-path/">
```

### 빌드 명령어 최적화

더 작은 번들 크기를 원한다면:
```bash
flutter build web --release --web-renderer canvaskit
# 또는
flutter build web --release --web-renderer html
```

---

## 📝 추천 순서

1. **처음 시작하는 경우**: **Netlify** (가장 간단)
2. **장기적으로 운영**: **Firebase Hosting** (안정적)
3. **GitHub 사용자**: **GitHub Pages** (통합 편리)
4. **빠른 배포**: **Vercel** (속도 빠름)

---

## 🎯 빠른 시작 (Netlify 예시)

```bash
# 1. 웹 빌드
flutter build web --release

# 2. Netlify 사이트 접속
# https://www.netlify.com

# 3. build/web 폴더를 드래그 앤 드롭
# 끝!
```

---

## ❓ 문제 해결

### CORS 오류
- 호스팅 서비스의 CORS 설정 확인
- `web/index.html`의 base href 확인

### 라우팅 문제
- SPA(Single Page Application) 설정 확인
- 모든 경로를 `index.html`로 리다이렉트 설정

### 빌드 실패
- Flutter 버전 확인: `flutter --version`
- 의존성 업데이트: `flutter pub get`
- 캐시 클리어: `flutter clean`

---

## 🔗 유용한 링크

- [Flutter Web 공식 문서](https://docs.flutter.dev/platform-integration/web)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Netlify 문서](https://docs.netlify.com/)
- [GitHub Pages](https://pages.github.com/)
- [Vercel 문서](https://vercel.com/docs)

