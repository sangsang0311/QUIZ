import os
import requests
import shutil
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse

# 이미지 저장 경로 설정
output_dir = "assets/images"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# 한국 연예인 목록과 이미지 URL (Wikimedia Commons에서 가져온 무료 이미지 예시)
celebrities = [
    {"name": "아이유 (IU)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/191215_IU_at_2019_MMA.jpg/800px-191215_IU_at_2019_MMA.jpg"},
    {"name": "배용준 (Bae Yong-joon)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Bae_Yong-joon_in_2009.jpg/800px-Bae_Yong-joon_in_2009.jpg"},
    {"name": "송혜교 (Song Hye-kyo)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Song_Hye-kyo_at_Bottega_Veneta_Seoul_Hyundai_Department_Store_opening.jpg/800px-Song_Hye-kyo_at_Bottega_Veneta_Seoul_Hyundai_Department_Store_opening.jpg"},
    {"name": "장동건 (Jang Dong-gun)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Jang_Dong-gun_at_Busan_International_Film_Festival_on_October_6%2C_2016.jpg/800px-Jang_Dong-gun_at_Busan_International_Film_Festival_on_October_6%2C_2016.jpg"},
    {"name": "이영애 (Lee Young-ae)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Lee_Young-ae_from_acrofan.jpg/800px-Lee_Young-ae_from_acrofan.jpg"},
    {"name": "빅뱅 지드래곤 (G-Dragon)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/G-Dragon_in_Paris%2C_2014.jpg/800px-G-Dragon_in_Paris%2C_2014.jpg"},
    {"name": "김태희 (Kim Tae-hee)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Kim_Tae-hee_in_2008.jpg/800px-Kim_Tae-hee_in_2008.jpg"},
    {"name": "전지현 (Jun Ji-hyun)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Jun_Ji-hyun_at_Alexander_McQueen_Savage_Beauty_exhibition_in_London_-_20150316.jpg/800px-Jun_Ji-hyun_at_Alexander_McQueen_Savage_Beauty_exhibition_in_London_-_20150316.jpg"},
    {"name": "이민호 (Lee Min-ho)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Lee_Min-ho_on_October_2%2C_2020.jpg/800px-Lee_Min-ho_on_October_2%2C_2020.jpg"},
    {"name": "손예진 (Son Ye-jin)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Son_Ye-jin_at_BIFF_2018_-_Son_Ye-jin_Guestshowcase.jpg/800px-Son_Ye-jin_at_BIFF_2018_-_Son_Ye-jin_Guestshowcase.jpg"},
    {"name": "박서준 (Park Seo-joon)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Park_Seo-joon_at_Gucci_Pop-Up_Fashion_Show.jpg/800px-Park_Seo-joon_at_Gucci_Pop-Up_Fashion_Show.jpg"},
    {"name": "수지 (Suzy)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5d/Suzy_at_the_2019_Lancome_My_Wishes_My_Love_Event.jpg/800px-Suzy_at_the_2019_Lancome_My_Wishes_My_Love_Event.jpg"},
    {"name": "정해인 (Jung Hae-in)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Jung_Hae-in_for_Cartier_Clash_de_Cartier_2019_01.jpg/800px-Jung_Hae-in_for_Cartier_Clash_de_Cartier_2019_01.jpg"},
    {"name": "한소희 (Han So-hee)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c4/Han_So-hee_in_December_2019.jpg/800px-Han_So-hee_in_December_2019.jpg"},
    {"name": "잔나비 최정훈 (Choi Jung-hoon)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Jannabi_2019.jpg/800px-Jannabi_2019.jpg"},
    {"name": "마마무 화사 (Hwasa)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/HWASA_on_April_26%2C_2019.jpg/800px-HWASA_on_April_26%2C_2019.jpg"},
    {"name": "방탄소년단 정국 (Jungkook)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Jungkook_for_Dispatch_%22Boy_With_Luv%22_MV_behind_the_scene_shooting%2C_15_March_2019_01.jpg/800px-Jungkook_for_Dispatch_%22Boy_With_Luv%22_MV_behind_the_scene_shooting%2C_15_March_2019_01.jpg"},
    {"name": "이하이 (Lee Hi)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Lee_Hi_in_August_2020.jpg/800px-Lee_Hi_in_August_2020.jpg"},
    {"name": "에스파 카리나 (Karina)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Karina_at_the_MAMAxMnet_in_December_2020_02.png/800px-Karina_at_the_MAMAxMnet_in_December_2020_02.png"},
    {"name": "유재석 (Yoo Jae-suk)", "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Yoo_Jae-suk_Hangzhou_May_2016.jpg/800px-Yoo_Jae-suk_Hangzhou_May_2016.jpg"},
]

def download_image(idx, celebrity):
    try:
        # 파일 번호 생성 (01, 02, ...)
        file_number = str(idx+1).zfill(2)
        filename = f"celebrity_{file_number}.jpg"
        filepath = os.path.join(output_dir, filename)
        
        # 이미지 다운로드
        response = requests.get(celebrity["url"], stream=True)
        
        if response.status_code == 200:
            with open(filepath, 'wb') as f:
                response.raw.decode_content = True
                shutil.copyfileobj(response.raw, f)
            print(f"다운로드 성공: {celebrity['name']} -> {filename}")
            return True
        else:
            print(f"다운로드 실패: {celebrity['name']} - 응답 코드: {response.status_code}")
            return False
    except Exception as e:
        print(f"오류 발생: {celebrity['name']} - {str(e)}")
        return False

def main():
    print(f"한국 연예인 이미지 다운로드 시작! 총 {len(celebrities)}개 이미지")
    
    # 다중 스레드로 이미지 다운로드
    with ThreadPoolExecutor(max_workers=5) as executor:
        results = list(executor.map(
            lambda args: download_image(*args), 
            enumerate(celebrities)
        ))
    
    success_count = sum(results)
    print(f"다운로드 완료! 성공: {success_count}/{len(celebrities)}")

if __name__ == "__main__":
    main() 