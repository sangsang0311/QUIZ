# GitHub Pages 배포 단계별 가이드

## 1단계: GitHub 저장소 생성 ✅

현재 화면에서:
- ✅ Repository name: "QUIZ" (이미 입력됨)
- ✅ Public 선택 (이미 선택됨)
- **"Create repository" 버튼 클릭!**

---

## 2단계: 로컬 프로젝트를 Git에 연결

저장소 생성 후, 터미널에서 다음 명령어를 실행하세요:

```bash
# 프로젝트 폴더로 이동 (이미 있다면 생략)
cd C:\Users\cc412\Desktop\flutter_app\Quiz

# Git 초기화 (이미 되어있다면 생략)
git init

# 모든 파일 추가
git add .

# 첫 커밋
git commit -m "Initial commit: Quiz app"

# GitHub 저장소 연결 (yourusername을 본인 GitHub 사용자명으로 변경)
git remote add origin https://github.com/sang-sang97/QUIZ.git

# 메인 브랜치 이름 확인 및 설정
git branch -M main

# GitHub에 푸시
git push -u origin main
```

**주의사항:**
- GitHub 사용자명이 `sang-sang97`이 맞는지 확인하세요
- 저장소 이름이 `QUIZ`가 맞는지 확인하세요
- 첫 푸시 시 GitHub 로그인을 요구할 수 있습니다

---

## 3단계: GitHub Actions 워크플로우 파일 생성

프로젝트 루트에 다음 경로와 파일을 생성하세요:

**파일 경로:** `.github/workflows/deploy.yml`

**파일 내용:**

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
      - run: flutter build web --release --base-href "/QUIZ/"
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

**파일 생성 방법:**
1. 프로젝트 루트에 `.github` 폴더 생성
2. 그 안에 `workflows` 폴더 생성
3. `workflows` 폴더 안에 `deploy.yml` 파일 생성
4. 위 내용을 복사해서 붙여넣기

---

## 4단계: 파일을 GitHub에 푸시

워크플로우 파일을 생성한 후:

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions workflow for deployment"
git push
```

---

## 5단계: GitHub Pages 활성화

1. GitHub 저장소 페이지로 이동
2. **Settings** 탭 클릭
3. 왼쪽 메뉴에서 **Pages** 클릭
4. **Source** 섹션에서:
   - Branch: `gh-pages` 선택
   - Folder: `/ (root)` 선택
5. **Save** 버튼 클릭

---

## 6단계: 배포 확인

1. 저장소의 **Actions** 탭으로 이동
2. 워크플로우가 실행 중인지 확인 (약 2-5분 소요)
3. 완료되면 **Settings > Pages**에서 사이트 URL 확인
4. 접속 URL: `https://sang-sang97.github.io/QUIZ/`

---

## ⚠️ 문제 해결

### 워크플로우가 실패하는 경우
- Flutter 버전 확인: `flutter --version`으로 현재 버전 확인 후 `deploy.yml`의 `flutter-version` 수정
- Actions 탭에서 에러 로그 확인

### 사이트가 404 에러인 경우
- `base-href` 설정 확인
- GitHub Pages가 완전히 배포될 때까지 몇 분 기다리기
- 브라우저 캐시 삭제 후 다시 시도

### 파일이 푸시되지 않는 경우
- Git이 설치되어 있는지 확인: `git --version`
- GitHub 인증 확인 (Personal Access Token 필요할 수 있음)

---

## 🎉 완료!

배포가 완료되면:
- URL: `https://sang-sang97.github.io/QUIZ/`
- 이후 코드를 수정하고 `git push`만 하면 자동으로 배포됩니다!


