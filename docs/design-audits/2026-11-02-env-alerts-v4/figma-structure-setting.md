# Figma 구조 덤프 — 온습도 설정 & 온도 보정 (`1635:6166`)

> talk-to-figma 채널 v7jokd73에서 2026-11-02 추출. 좌표는 각 최상위 프레임 기준(x,y w×h), 색은 fill hex, 글자는 크기/굵기 lh줄높이 ls자간. 이미지는 `figma/<코드>_*.png`. Figma가 바뀌면 다시 추출할 것.


## S34 · TempHumid_Setting · `1635:6216`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 268×21)
            - TEXT `보정 온도` (36,200 268×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (304,200 53×21)
            - TEXT `27.2℃` (304,200 53×21) **"27.2℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 318` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Enabled` (157,299 96×40) fill #F4F4F4 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - FRAM `Button/Selected` (261,299 96×40) fill #C00306 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/700 lh19.1 ls-0.32 #FAFAFA
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `1.0` (36,366 23×21) **"1.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 38×6) fill #C00306
        - RECT `Button` (192,358 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S36 · TempHumid_Setting · `1635:6330`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 268×21)
            - TEXT `보정 온도` (36,200 268×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (304,200 53×21)
            - TEXT `27.2℃` (304,200 53×21) **"27.2℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 318` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Enabled` (157,299 96×40) fill #F4F4F4 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - FRAM `Button/Selected` (261,299 96×40) fill #C00306 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/700 lh19.1 ls-0.32 #FAFAFA
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `1.0` (36,366 23×21) **"1.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 38×6) fill #C00306
        - RECT `Button` (192,358 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S37 · TempHumid_Setting · `1635:6387`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 265×21)
            - TEXT `보정 온도` (36,200 265×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,200 56×21)
            - TEXT `22.2℃` (301,200 56×21) **"22.2℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 319` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Selected` (157,299 96×40) fill #C00306 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/700 lh19.1 ls-0.32 #FAFAFA
          - FRAM `Button/Enabled` (261,299 96×40) fill #F4F4F4 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `4.0` (36,366 27×21) **"4.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 150×6) fill #C00306
        - RECT `Button` (305,358 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S23 · Brightness · `1636:6473`

- FRAM `Brightness` (0,0 345×48) fill #FFFFFF
  - TEXT `1.0` (12,14 23×21) **"1.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
  - FRAM `Slider` (133,21 200×6) fill #E3E3E3 r22
    - RECT `Percent` (133,21 38×6) fill #C00306
  - RECT `Button` (168,6 52×32) fill #FFFFFF r16

## S33 · TempHumid_Setting · `1635:6264`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 269×21)
            - TEXT `보정 온도` (36,200 269×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (305,200 52×21)
            - TEXT `26.1℃` (305,200 52×21) **"26.1℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 318` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Selected` (157,299 96×40) fill #C00306 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/700 lh19.1 ls-0.32 #FAFAFA
          - FRAM `Button/Enabled` (261,299 96×40) fill #F4F4F4 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `0.1` (36,366 22×21) **"0.1"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 10×6) fill #C00306
        - RECT `Button` (163,360 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S32 · TempHumid_Setting · `1635:5827`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 317` (24,130 345×498)
    - FRAM `Frame 313` (24,130 345×150)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,157 345×97) r16
        - FRAM `OnOff` (24,157 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,165 80×32) fill #C00306 r16
            - RECT `Button` (309,167 50×28) fill #FAFAFA r14
        - FRAM `List` (24,206 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,220 240×21)
            - TEXT `보정 값` (36,220 240×21) **"보정 값"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (280,220 77×19)
            - TEXT `설정하기` (280,220 55×19) **"설정하기"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,221 18×18)
              - RECT `Bounding box` (339,221 18×18) fill #3C3C3C
      - FRAM `Sub` (24,262 345×18)
        - TEXT `Label` (36,262 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,304 345×150)
      - FRAM `Title` (24,304 345×19)
        - TEXT `Label` (36,304 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,331 345×97) r16
        - FRAM `OnOff` (24,331 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,344 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,339 80×32) fill #C00306 r16
            - RECT `Button` (309,341 50×28) fill #FAFAFA r14
        - FRAM `List` (24,380 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,394 207×21)
            - TEXT `적정 온도` (36,394 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,394 110×19)
            - TEXT `18℃ ~ 26℃` (247,394 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,395 18×18)
              - RECT `Bounding box` (339,395 18×18) fill #3C3C3C
      - FRAM `Sub` (24,436 345×18)
        - TEXT `Label` (36,436 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,478 345×150)
      - FRAM `Title` (24,478 345×19)
        - TEXT `Label` (36,478 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,505 345×97) r16
        - FRAM `OnOff` (24,505 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,518 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,513 80×32) fill #C00306 r16
            - RECT `Button` (309,515 50×28) fill #FAFAFA r14
        - FRAM `List` (24,554 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,568 211×21)
            - TEXT `적정 습도` (36,568 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,568 106×19)
            - TEXT `40% ~ 80%` (251,568 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,569 18×18)
              - RECT `Bounding box` (339,569 18×18) fill #3C3C3C
      - FRAM `Sub` (24,610 345×18)
        - TEXT `Label` (36,610 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090

## S35 · TempHumid_Setting · `1635:5700`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 317` (24,130 345×498)
    - FRAM `Frame 313` (24,130 345×150)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,157 345×97) r16
        - FRAM `OnOff` (24,157 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,165 80×32) fill #C00306 r16
            - RECT `Button` (309,167 50×28) fill #FAFAFA r14
        - FRAM `List` (24,206 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,220 216×21)
            - TEXT `보정 값` (36,220 216×21) **"보정 값"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (256,220 101×19)
            - TEXT `측정값 +1℃` (256,220 79×19) **"측정값 +1℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,221 18×18)
              - RECT `Bounding box` (339,221 18×18) fill #3C3C3C
      - FRAM `Sub` (24,262 345×18)
        - TEXT `Label` (36,262 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,304 345×150)
      - FRAM `Title` (24,304 345×19)
        - TEXT `Label` (36,304 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,331 345×97) r16
        - FRAM `OnOff` (24,331 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,344 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,339 80×32) fill #C00306 r16
            - RECT `Button` (309,341 50×28) fill #FAFAFA r14
        - FRAM `List` (24,380 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,394 207×21)
            - TEXT `적정 온도` (36,394 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,394 110×19)
            - TEXT `18℃ ~ 26℃` (247,394 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,395 18×18)
              - RECT `Bounding box` (339,395 18×18) fill #3C3C3C
      - FRAM `Sub` (24,436 345×18)
        - TEXT `Label` (36,436 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,478 345×150)
      - FRAM `Title` (24,478 345×19)
        - TEXT `Label` (36,478 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,505 345×97) r16
        - FRAM `OnOff` (24,505 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,518 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,513 80×32) fill #C00306 r16
            - RECT `Button` (309,515 50×28) fill #FAFAFA r14
        - FRAM `List` (24,554 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,568 211×21)
            - TEXT `적정 습도` (36,568 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,568 106×19)
            - TEXT `40% ~ 80%` (251,568 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,569 18×18)
              - RECT `Bounding box` (339,569 18×18) fill #3C3C3C
      - FRAM `Sub` (24,610 345×18)
        - TEXT `Label` (36,610 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090

## S45 · (메모) · `1635:6017`

- FRAM `` (0,0 834×104) fill #192553
  - TEXT `온도 보정 토글을 켜도, 설정을 저장하기 전까지 보정값이 들어가지 않음,` (10,10 814×84) **"온도 보정 토글을 켜도, 설정을 저장하기 전까지 보정값이 들어가지 않음, ⏎  ⏎ 설정하기를 누르면 최초진입 시 빼기 0.1이 디폴트로 되어있지만 저장을 누르기전까지 설정되지않음"** 20/500 lh28 ls-0.4 #FFFFFF

## S44 · (메모) · `1657:5408`

- FRAM `` (0,0 834×132) fill #192553
  - TEXT `온습도 min, max 값에 따라 - 자동환기, 자동분무가 작동 습도 {` (10,10 814×112) **"온습도 min, max 값에 따라 - 자동환기, 자동분무가 작동 ⏎  ⏎ 습도 {Max}% 초과 또는 온도 {Max}℃ 초과 시 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다 ⏎ 습도가 {Min}% 미만으로 내려가면 자동으로 1회 분무"** 20/500 lh28 ls-0.4 #FFFFFF

## S46 · (메모) · `1635:6013`

- FRAM `` (0,0 394×76) fill #DA4A6A
  - TEXT `최초 진입 시 설정값을 건드린뒤에 취소하면 디폴트 값으로 되돌아감` (34,10 327×56) **"최초 진입 시 설정값을 건드린뒤에 취소하면 ⏎ 디폴트 값으로 되돌아감"** 20/500 lh28 ls-0.4 #FFFFFF

## S38 · (메모) · `1657:5673`

- FRAM `` (0,0 842×48) fill #DA4A6A
  - TEXT `알림 설정에서도 진입할 수 있게` (302,10 238×28) **"알림 설정에서도 진입할 수 있게"** 20/500 lh28 ls-0.4 #FFFFFF

## S47 · (메모) · `1635:6144`

- FRAM `` (0,0 394×104) fill #DA4A6A
  - TEXT `최초 진입 이 아니고, 한번 설정한 뒤 수정하는 경우는 취소누르면 이전에` (10,10 374×84) **"최초 진입 이 아니고, 한번 설정한 뒤 ⏎ 수정하는 경우는 취소누르면  ⏎ 이전에 설정해 놓은 값으로 되돌아감"** 20/500 lh28 ls-0.4 #FFFFFF

## S03 · TempHumid_Detail · `1610:7653`

- FRAM `TempHumid_Detail` (0,0 393×852) fill #FFFFFF
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 상세` (160,74 72×19) **"온습도 상세"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Toggle_L` (12,124 369×32) fill #E3E3E3 r18
    - FRAM `Left` (14,126 180×28) fill #FFFFFF r14
      - TEXT `일간` (92,132 24×17) **"일간"** 14/700 lh16.7 ls-0.28 #3C3C3C
    - FRAM `Right` (198,126 180×28) r14
      - TEXT `주간` (277,132 24×17) **"주간"** 14/600 lh16.7 ls-0.28 #626262
  - FRAM `DatePicker` (12,172 369×40)
    - FRAM `arrow_back_ios_new` (12,172 40×40)
    - FRAM `DatePicker-Modal` (142,172 108×40)
      - TEXT `2026. 8. 28` (150,182 92×21) **"2026. 8. 28"** 18/600 lh21.5 ls-0.36 #3C3C3C
    - FRAM `arrow_forward_ios` (341,172 40×40)
  - FRAM `Frame 281` (-143,228 679×349)
    - FRAM `BarGraph` (15,228 363×70)
      - FRAM `TempBar` (15,228 363×29)
        - FRAM `Left` (15,228 110×29)
          - FRAM `thermometer` (15,230 24×24) fill #C00306 r14
          - TEXT `22.0℃` (47,228 78×29) **"22.0℃"** 24/600 lh28.6 ls-0.48 #C00306
        - FRAM `Right` (141,228 237×29)
          - TEXT `15` (141,228 30×29) **"15"** 24/500 lh28.6 ls-0.48 #949090
          - RECT `Rectangle 203` (179,236 161×12) fill GRADIENT_LINEAR r10
          - TEXT `26` (348,228 30×29) **"26"** 24/500 lh28.6 ls-0.48 #3C3C3C
          - RECT `Rectangle 203` (233,236 54×12) fill #F4F4F4
          - ELLI `Ellipse 39` (264,236 12×12) fill #D61619 stroke #FAFAFA/
          - TEXT `18` (227,248 11×12) **"18"** 10/500 lh11.9 ls-0.2 #B4AEAE
          - TEXT `24` (280,248 12×12) **"24"** 10/500 lh11.9 ls-0.2 #B4AEAE
      - FRAM `HumidBar` (15,269 363×29)
        - FRAM `Left` (15,269 110×29)
          - FRAM `humidity_high` (15,272 24×24) fill #192553 r14
          - TEXT `59.4%` (47,269 78×29) **"59.4%"** 24/600 lh28.6 ls-0.48 #192553
        - FRAM `Right` (141,269 237×29)
          - TEXT `34` (141,269 30×29) **"34"** 24/500 lh28.6 ls-0.48 #949090
          - RECT `Rectangle 203` (179,278 161×12) fill GRADIENT_LINEAR r10
          - TEXT `80` (348,269 30×29) **"80"** 24/500 lh28.6 ls-0.48 #3C3C3C
          - RECT `Rectangle 203` (219,278 80×12) fill #F4F4F4
          - ELLI `Ellipse 39` (274,278 12×12) fill #2E408C stroke #FAFAFA/
          - TEXT `40` (213,290 13×12) **"40"** 10/500 lh11.9 ls-0.2 #B4AEAE
          - TEXT `80` (293,290 13×12) **"80"** 10/500 lh11.9 ls-0.2 #B4AEAE
    - GROU `GraphGroup` (-143,318 679×259)
      - FRAM `LineX` (-143,319 524×256)
      - FRAM `LineY` (12,319 524×256)
        - FRAM `Line` (12,319 524×256)
        - FRAM `X` (12,553 524×22)
          - FRAM `X` (12,553 130×14)
            - TEXT `오전 12시` (16,553 46×14) **"오전 12시"** 12/500 lh14.3 ls-0.24 #B4AEAE
          - FRAM `X` (143,553 130×14)
            - TEXT `오전 6시` (147,553 41×14) **"오전 6시"** 12/500 lh14.3 ls-0.24 #B4AEAE
          - FRAM `X` (275,553 130×14)
            - TEXT `오후 12시` (279,553 46×14) **"오후 12시"** 12/500 lh14.3 ls-0.24 #B4AEAE
          - FRAM `X` (406,553 130×14)
            - TEXT `오후 6시` (410,553 41×14) **"오후 6시"** 12/500 lh14.3 ls-0.24 #949090
      - RECT `Hide` (0,318 12×258) fill #FFFFFF
      - FRAM `Y_humid` (355,351 26×192)
        - TEXT `75%` (355,351 26×32) **"75%"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `70%` (355,383 26×32) **"70%"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `65%` (355,415 26×32) **"65%"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `60%` (355,447 26×32) **"60%"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `55%` (355,479 26×32) **"55%"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `50%` (355,511 26×32) **"50%"** 12/500 lh14.3 ls-0.24 #B4AEAE
      - FRAM `Y_temp` (12,351 26×192)
        - TEXT `40°` (12,351 26×32) **"40°"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `35°` (12,383 26×32) **"35°"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `25°` (12,415 26×32) **"25°"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `20°` (12,447 26×32) **"20°"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `15°` (12,479 26×32) **"15°"** 12/500 lh14.3 ls-0.24 #B4AEAE
        - TEXT `10°` (12,511 26×32) **"10°"** 12/500 lh14.3 ls-0.24 #B4AEAE
      - FRAM `humidity_high` (255,321 28×28) fill #2A97DB stroke #FFFFFF/ r14
      - FRAM `Frame 79` (299,321 92×28)
        - FRAM `light_off` (299,321 28×28) fill #B4AEAE stroke #FAFAFA/ r14
        - FRAM `mode_cool_off` (331,321 28×28) fill #B4AEAE stroke #FAFAFA/ r14
        - FRAM `mode_fan_off` (363,321 28×28) fill #B4AEAE stroke #FAFAFA/ r14
      - FRAM `Frame 78` (161,321 72×28)
        - FRAM `lightbulb` (161,321 28×28) fill #E39B00 stroke #FAFAFA/ r14
        - FRAM `mode_cool` (183,321 28×28) fill #636DDB stroke #FAFAFA/ r14
        - FRAM `mode_fan_2` (205,321 28×28) fill #228C73 stroke #FAFAFA/ r14
      - RECT `Hide` (381,319 12×258) fill #FFFFFF
  - FRAM `Frame 110` (0,601 393×500) fill #FAFAFA
    - TEXT `사육장 제어 기록` (20,621 353×20) **"사육장 제어 기록"** 18/700 lh20 ls-0.36 #1E1E1E
    - FRAM `Frame 104` (20,661 353×40)
      - FRAM `Frame 103` (20,661 120×40)
        - FRAM `mode_cool_off` (20,663 36×36) fill #B4AEAE r18.000001907348633
        - FRAM `Frame 101` (68,661 72×40)
          - TEXT `냉각팬 꺼짐` (68,661 72×19) **"냉각팬 꺼짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오후 12:59` (68,684 62×17) **"오후 12:59"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (298,661 75×40)
        - TEXT `32℃ 52%` (298,661 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `-5℃ +2%` (311,684 62×17) **"-5℃ +2%"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 105` (20,721 353×40)
      - FRAM `Frame 103` (20,721 120×40)
        - FRAM `mode_fan_off` (20,723 36×36) fill #B4AEAE r18
        - FRAM `Frame 101` (68,721 72×40)
          - TEXT `환기팬 꺼짐` (68,721 72×19) **"환기팬 꺼짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오후 12:59` (68,744 62×17) **"오후 12:59"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (298,721 75×40)
        - TEXT `32℃ 52%` (298,721 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `-3℃ +2%` (311,744 62×17) **"-3℃ +2%"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 106` (20,781 353×40)
      - FRAM `Frame 103` (20,781 110×40)
        - FRAM `light_off` (20,783 36×36) fill #B4AEAE r18
        - FRAM `Frame 101` (68,781 62×40)
          - TEXT `LED 꺼짐` (68,781 59×19) **"LED 꺼짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오후 12:59` (68,804 62×17) **"오후 12:59"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (283,781 90×40)
        - TEXT `32℃ 52%` (298,781 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `작동 시점 온습도` (283,804 90×17) **"작동 시점 온습도"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 107` (20,841 353×40)
      - FRAM `Frame 103` (20,841 106×40)
        - FRAM `humidity_high` (20,843 36×36) fill #2A97DB r18
        - FRAM `Frame 101` (68,841 58×40)
          - TEXT `분무 작동` (68,841 58×19) **"분무 작동"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오후 1:30` (68,864 54×17) **"오후 1:30"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (283,841 90×40)
        - TEXT `32℃ 52%` (298,841 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `작동 시점 온습도` (283,864 90×17) **"작동 시점 온습도"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 109` (20,901 353×40)
      - FRAM `Frame 103` (20,901 120×40)
        - FRAM `mode_fan_2` (20,903 36×36) fill #228C73 r18
        - FRAM `Frame 101` (68,901 72×40)
          - TEXT `환기팬 켜짐` (68,901 72×19) **"환기팬 켜짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오전 8:40` (68,924 56×17) **"오전 8:40"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (283,901 90×40)
        - TEXT `32℃ 52%` (298,901 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `작동 시점 온습도` (283,924 90×17) **"작동 시점 온습도"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 108` (20,961 353×40)
      - FRAM `Frame 103` (20,961 120×40)
        - FRAM `mode_cool` (20,963 36×36) fill #636DDB r18
        - FRAM `Frame 101` (68,961 72×40)
          - TEXT `냉각팬 켜짐` (68,961 72×19) **"냉각팬 켜짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오전 8:35` (68,984 56×17) **"오전 8:35"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (283,961 90×40)
        - TEXT `32℃ 52%` (298,961 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `작동 시점 온습도` (283,984 90×17) **"작동 시점 온습도"** 14/500 lh16.7 ls-0.28 #949090
    - FRAM `Frame 110` (20,1021 353×40)
      - FRAM `Frame 103` (20,1021 107×40)
        - FRAM `lightbulb` (20,1023 36×36) fill #E39B00 r18
        - FRAM `Frame 101` (68,1021 59×40)
          - TEXT `LED 켜짐` (68,1021 59×19) **"LED 켜짐"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `오전 8:30` (68,1044 56×17) **"오전 8:30"** 14/500 lh16.7 ls-0.28 #949090
      - FRAM `Frame 102` (283,1021 90×40)
        - TEXT `32℃ 52%` (298,1021 75×19) **"32℃ 52%"** 16/600 lh19.1 ls-0.32 #1E1E1E
        - TEXT `작동 시점 온습도` (283,1044 90×17) **"작동 시점 온습도"** 14/500 lh16.7 ls-0.28 #949090
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `close` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `discover_tune` (337,62 44×44)

## S01 · (메모) · `1610:7851`

- FRAM `` (0,0 1776×100) fill #1E1E1E r12
  - TEXT `온습도 설정 & 온도 보정` (660,20 456×60) **"온습도 설정 & 온도 보정"** 50/500 lh59.7 ls-1 #FFFFFF

## S30 · (메모) · `1657:5406`

- FRAM `` (0,0 1776×100) fill #1E1E1E r12
  - TEXT `자동 환기, 자동 분무` (696,20 385×60) **"자동 환기, 자동 분무"** 50/500 lh59.7 ls-1 #FFFFFF

## S02 · (메모) · `1635:6148`

- FRAM `` (0,0 3010×100) fill #1E1E1E r12
  - TEXT `온습도 설정 & 온도 보정 상세` (1229,20 552×60) **"온습도 설정 & 온도 보정 상세"** 50/500 lh59.7 ls-1 #FFFFFF

## S04 · TempHumid_Setting · `1623:8553`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 316` (24,130 345×449)
    - FRAM `Frame 313` (24,130 345×101)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `OnOff` (24,157 345×48) fill #FFFFFF r16
        - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Toggle_off` (281,165 80×32) fill #B4AEAE r16
          - RECT `Button` (283,167 50×28) fill #FAFAFA r14
      - FRAM `Sub` (24,213 345×18)
        - TEXT `Label` (36,213 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,255 345×150)
      - FRAM `Title` (24,255 345×19)
        - TEXT `Label` (36,255 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,282 345×97) r16
        - FRAM `OnOff` (24,282 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `적정 온도 이탈 알림` (36,296 134×21) **"적정 온도 이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,290 80×32) fill #C00306 r16
            - RECT `Button` (309,292 50×28) fill #FAFAFA r14
        - FRAM `List` (24,331 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,344 207×21)
            - TEXT `적정 온도` (36,344 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,346 110×19)
            - TEXT `18℃ ~ 26℃` (247,346 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,346 18×18)
              - RECT `Bounding box` (339,346 18×18) fill #3C3C3C
      - FRAM `Sub` (24,387 345×18)
        - TEXT `Label` (36,387 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,429 345×150)
      - FRAM `Title` (24,429 345×19)
        - TEXT `Label` (36,429 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,456 345×97) r16
        - FRAM `OnOff` (24,456 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `적정 습도 이탈 알림` (36,470 134×21) **"적정 습도 이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,464 80×32) fill #C00306 r16
            - RECT `Button` (309,466 50×28) fill #FAFAFA r14
        - FRAM `List` (24,505 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,518 211×21)
            - TEXT `적정 습도` (36,518 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,520 106×19)
            - TEXT `40% ~ 80%` (251,520 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,520 18×18)
              - RECT `Bounding box` (339,520 18×18) fill #3C3C3C
      - FRAM `Sub` (24,561 345×18)
        - TEXT `Label` (36,561 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090

## S05 · TempHumid_Setting · `1623:8671`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 317` (24,130 345×498)
    - FRAM `Frame 313` (24,130 345×150)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,157 345×97) r16
        - FRAM `OnOff` (24,157 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,165 80×32) fill #C00306 r16
            - RECT `Button` (309,167 50×28) fill #FAFAFA r14
        - FRAM `List` (24,206 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,220 240×21)
            - TEXT `보정 값` (36,220 240×21) **"보정 값"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (280,220 77×19)
            - TEXT `설정하기` (280,220 55×19) **"설정하기"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,221 18×18)
              - RECT `Bounding box` (339,221 18×18) fill #3C3C3C
      - FRAM `Sub` (24,262 345×18)
        - TEXT `Label` (36,262 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,304 345×150)
      - FRAM `Title` (24,304 345×19)
        - TEXT `Label` (36,304 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,331 345×97) r16
        - FRAM `OnOff` (24,331 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,344 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,339 80×32) fill #C00306 r16
            - RECT `Button` (309,341 50×28) fill #FAFAFA r14
        - FRAM `List` (24,380 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,394 207×21)
            - TEXT `적정 온도` (36,394 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,394 110×19)
            - TEXT `18℃ ~ 26℃` (247,394 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,395 18×18)
              - RECT `Bounding box` (339,395 18×18) fill #3C3C3C
      - FRAM `Sub` (24,436 345×18)
        - TEXT `Label` (36,436 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,478 345×150)
      - FRAM `Title` (24,478 345×19)
        - TEXT `Label` (36,478 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,505 345×97) r16
        - FRAM `OnOff` (24,505 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,518 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,513 80×32) fill #C00306 r16
            - RECT `Button` (309,515 50×28) fill #FAFAFA r14
        - FRAM `List` (24,554 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,568 211×21)
            - TEXT `적정 습도` (36,568 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,568 106×19)
            - TEXT `40% ~ 80%` (251,568 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,569 18×18)
              - RECT `Bounding box` (339,569 18×18) fill #3C3C3C
      - FRAM `Sub` (24,610 345×18)
        - TEXT `Label` (36,610 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090

## S06 · TempHumid_Setting · `1623:8751`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 317` (24,130 345×498)
    - FRAM `Frame 313` (24,130 345×150)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,157 345×97) r16
        - FRAM `OnOff` (24,157 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,165 80×32) fill #C00306 r16
            - RECT `Button` (309,167 50×28) fill #FAFAFA r14
        - FRAM `List` (24,206 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,220 217×21)
            - TEXT `보정 값` (36,220 217×21) **"보정 값"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (257,220 100×19)
            - TEXT `측정값 -2℃` (257,220 78×19) **"측정값 -2℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,221 18×18)
              - RECT `Bounding box` (339,221 18×18) fill #3C3C3C
      - FRAM `Sub` (24,262 345×18)
        - TEXT `Label` (36,262 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,304 345×150)
      - FRAM `Title` (24,304 345×19)
        - TEXT `Label` (36,304 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,331 345×97) r16
        - FRAM `OnOff` (24,331 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,344 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,339 80×32) fill #C00306 r16
            - RECT `Button` (309,341 50×28) fill #FAFAFA r14
        - FRAM `List` (24,380 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,394 207×21)
            - TEXT `적정 온도` (36,394 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,394 110×19)
            - TEXT `18℃ ~ 26℃` (247,394 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,395 18×18)
              - RECT `Bounding box` (339,395 18×18) fill #3C3C3C
      - FRAM `Sub` (24,436 345×18)
        - TEXT `Label` (36,436 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,478 345×150)
      - FRAM `Title` (24,478 345×19)
        - TEXT `Label` (36,478 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,505 345×97) r16
        - FRAM `OnOff` (24,505 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `이탈 알림` (36,518 66×21) **"이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,513 80×32) fill #C00306 r16
            - RECT `Button` (309,515 50×28) fill #FAFAFA r14
        - FRAM `List` (24,554 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,568 211×21)
            - TEXT `적정 습도` (36,568 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,568 106×19)
            - TEXT `40% ~ 80%` (251,568 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,569 18×18)
              - RECT `Bounding box` (339,569 18×18) fill #3C3C3C
      - FRAM `Sub` (24,610 345×18)
        - TEXT `Label` (36,610 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090

## S08 · TempHumid_Setting · `1635:5123`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `적정 온도 설정` (152,74 89×19) **"적정 온도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×399)
    - FRAM `TopWrap` (24,130 345×211)
      - FRAM `Top` (24,130 345×167) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 222×21)
            - TEXT `적정 온도` (36,146 222×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (258,146 99×21)
            - TEXT `18℃ ~ 26℃` (258,146 99×21) **"18℃ ~ 26℃"** 18/500 lh21.5 ls-0.36 #C00306
        - FRAM `OnOff` (24,184 345×57) fill #FFFFFF stroke #E3E3E3/
          - TEXT `최소` (36,202 31×21) **"최소"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,196 120×32)
            - FRAM `StepMinus` (237,196 32×32) fill #3C3C3C r12
            - TEXT `18` (285,202 24×21) **"18"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus` (325,196 32×32) fill #3C3C3C r12
        - FRAM `OnOff` (24,241 345×56) fill #FFFFFF
          - TEXT `최대` (36,258 31×21) **"최대"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,253 120×32)
            - FRAM `StepMinus` (237,253 32×32) fill #3C3C3C r12
            - TEXT `26` (285,258 24×21) **"26"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus` (325,253 32×32) fill #3C3C3C r12
      - FRAM `Sub` (24,305 345×36)
        - TEXT `Label` (36,305 333×36) **"실시간 온도, 주간 그래프, 이탈 안내 및 알림, 사육장 자동 작동 기준으로 사용됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Guide` (24,365 345×164)
      - FRAM `Title` (24,365 345×19)
        - TEXT `Label` (36,365 321×19) **"적정 온도 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,392 345×137) fill #FFFFFF r16
        - TEXT `주간은 20~26°C, 야간에는 주간보다 3~5°C 떨어지게 유지하면 좋` (36,404 321×63) **"주간은 20~26°C, 야간에는 주간보다 3~5°C 떨어지게 유지하면 좋습니다. 특히 주간 온도는 여름같이 더울 때는 26~28°C, 추울 때는 20~24°C를 권장합니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `온도 보정 사용 시, 실제 측정값이 아닌 보정된 온도가 적정 범위 판정에` (36,475 321×42) **"온도 보정 사용 시, 실제 측정값이 아닌 보정된 온도가 적정 범위 판정에 적용됩니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
    - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA

## S11 · TempHumid_Setting · `1635:5165`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `적정 습도 설정` (152,74 89×19) **"적정 습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×407)
    - FRAM `TopWrap` (24,130 345×211)
      - FRAM `Top` (24,130 345×167) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 226×21)
            - TEXT `적정 습도` (36,146 226×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (262,146 95×21)
            - TEXT `40% ~ 80%` (262,146 95×21) **"40% ~ 80%"** 18/500 lh21.5 ls-0.36 #C00306
        - FRAM `OnOff` (24,184 345×57) fill #FFFFFF stroke #E3E3E3/
          - TEXT `최소` (36,202 31×21) **"최소"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,196 120×32)
            - FRAM `StepMinus` (237,196 32×32) fill #3C3C3C r12
            - TEXT `40` (285,202 24×21) **"40"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `add` (325,196 32×32) fill #3C3C3C r12
        - FRAM `OnOff` (24,241 345×56) fill #FFFFFF
          - TEXT `최대` (36,258 31×21) **"최대"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,253 120×32)
            - FRAM `StepMinus` (237,253 32×32) fill #3C3C3C r12
            - TEXT `80` (285,258 24×21) **"80"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `add` (325,253 32×32) fill #3C3C3C r12
      - FRAM `Sub` (24,305 345×36)
        - TEXT `Label` (36,305 333×36) **"실시간 온도, 주간 그래프, 이탈 안내 및 알림, 사육장 자동 작동 기준으로 사용됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Guide` (24,365 345×172)
      - FRAM `Title` (24,365 345×19)
        - TEXT `Label` (36,365 321×19) **"적정 습도 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,392 345×145) fill #FFFFFF r16
        - TEXT `습기는 60~80%, 건기는 40~60%를 유지해 주세요. 분무 후 6시` (36,404 321×42) **"습기는 60~80%, 건기는 40~60%를 유지해 주세요. 분무 후 6시간 이내에 건기에 진입하는 습도 사이클을 권장합니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `최대 습도는 분무 직후 측정된 습도에 맞춰 설정해 주세요` (36,454 321×21) **"최대 습도는 분무 직후 측정된 습도에 맞춰 설정해 주세요"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `최저 습도 미만으로 떨어지면 즉시 알림을 보내고, 최고 습도를 1시간 이` (36,483 321×42) **"최저 습도 미만으로 떨어지면 즉시 알림을 보내고, 최고 습도를 1시간 이상 초과하면 알림을 보냅니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
    - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA

## S27 · Stepper · `1635:5116`

- SECT `Stepper` (0,0 390×182) fill #FFFFFF stroke #FFFFFF@0.10/
  - FRAM `StepPlus` (310,28 32×32) fill #3C3C3C r12
  - FRAM `StepPlus_pressed` (310,67 32×32) fill #1E1E1E r12
  - FRAM `StepMinus` (268,28 32×32) fill #3C3C3C r12
  - FRAM `StepMinus_pressed` (268,67 32×32) fill #1E1E1E r12
  - FRAM `Stepper` (24,27 120×32)
    - FRAM `StepMinus` (24,27 32×32) fill #3C3C3C r12
    - TEXT `17.5` (64,32 40×21) **"17.5"** 18/600 lh21.5 ls-0.36 #1E1E1E
    - FRAM `StepPlus` (112,27 32×32) fill #3C3C3C r12
  - FRAM `Stepper` (24,75 120×32)
    - FRAM `StepMinus_disabled` (24,75 32×32) fill #E3E3E3 r12
    - TEXT `17.5` (64,80 40×21) **"17.5"** 18/600 lh21.5 ls-0.36 #1E1E1E
    - FRAM `StepPlus` (112,75 32×32) fill #3C3C3C r12
  - FRAM `StepMinus_disabled` (268,105 32×32) fill #E3E3E3 r12
  - FRAM `Stepper` (24,123 120×32)
    - FRAM `StepMinus` (24,123 32×32) fill #3C3C3C r12
    - TEXT `17.5` (64,128 40×21) **"17.5"** 18/600 lh21.5 ls-0.36 #1E1E1E
    - FRAM `StepPlus_disabled` (112,123 32×32) fill #E3E3E3 r12
  - FRAM `StepPlus_disabled` (310,105 32×32) fill #E3E3E3 r12

## S10 · TempHumid_Setting · `1623:8882`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `적정 온도 설정` (152,74 89×19) **"적정 온도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×399)
    - FRAM `TopWrap` (24,130 345×211)
      - FRAM `Top` (24,130 345×167) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 222×21)
            - TEXT `적정 온도` (36,146 222×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (258,146 99×21)
            - TEXT `18℃ ~ 26℃` (258,146 99×21) **"18℃ ~ 26℃"** 18/500 lh21.5 ls-0.36 #C00306
        - FRAM `OnOff` (24,184 345×57) fill #FFFFFF stroke #E3E3E3/
          - TEXT `최소` (36,202 31×21) **"최소"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,196 120×32)
            - FRAM `StepMinus` (237,196 32×32) fill #3C3C3C r12
            - TEXT `17.5` (277,202 40×21) **"17.5"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus` (325,196 32×32) fill #3C3C3C r12
        - FRAM `OnOff` (24,241 345×56) fill #FFFFFF
          - TEXT `최대` (36,258 31×21) **"최대"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,253 120×32)
            - FRAM `StepMinus` (237,253 32×32) fill #3C3C3C r12
            - TEXT `29` (277,258 40×21) **"29"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus_disabled` (325,253 32×32) fill #E3E3E3 r12
      - FRAM `Sub` (24,305 345×36)
        - TEXT `Label` (36,305 333×36) **"실시간 온도, 주간 그래프, 이탈 안내 및 알림, 사육장 자동 작동 기준으로 사용됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Guide` (24,365 345×164)
      - FRAM `Title` (24,365 345×19)
        - TEXT `Label` (36,365 321×19) **"적정 온도 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,392 345×137) fill #FFFFFF r16
        - TEXT `주간은 20~26°C, 야간에는 주간보다 3~5°C 떨어지게 유지하면 좋` (36,404 321×63) **"주간은 20~26°C, 야간에는 주간보다 3~5°C 떨어지게 유지하면 좋습니다. 특히 주간 온도는 여름같이 더울 때는 26~28°C, 추울 때는 20~24°C를 권장합니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `온도 보정 사용 시, 실제 측정값이 아닌 보정된 온도가 적정 범위 판정에` (36,475 321×42) **"온도 보정 사용 시, 실제 측정값이 아닌 보정된 온도가 적정 범위 판정에 적용됩니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `변경 사항 취소` (146,765 100×28) **"변경 사항 취소"** 18/600 lh28 ls-0.36 #C00306

## S13 · TempHumid_Setting · `1623:9103`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `적정 습도 설정` (152,74 89×19) **"적정 습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×407)
    - FRAM `TopWrap` (24,130 345×211)
      - FRAM `Top` (24,130 345×167) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 226×21)
            - TEXT `적정 습도` (36,146 226×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (262,146 95×21)
            - TEXT `40% ~ 80%` (262,146 95×21) **"40% ~ 80%"** 18/500 lh21.5 ls-0.36 #C00306
        - FRAM `OnOff` (24,184 345×57) fill #FFFFFF stroke #E3E3E3/
          - TEXT `최소` (36,202 31×21) **"최소"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,196 120×32)
            - FRAM `StepMinus_disabled` (237,196 32×32) fill #E3E3E3 r12
            - TEXT `35` (277,202 40×21) **"35"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus` (325,196 32×32) fill #3C3C3C r12
        - FRAM `OnOff` (24,241 345×56) fill #FFFFFF
          - TEXT `최대` (36,258 31×21) **"최대"** 18/500 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Stepper` (237,253 120×32)
            - FRAM `StepMinus` (237,253 32×32) fill #3C3C3C r12
            - TEXT `80` (277,258 40×21) **"80"** 18/600 lh21.5 ls-0.36 #1E1E1E
            - FRAM `StepPlus` (325,253 32×32) fill #3C3C3C r12
      - FRAM `Sub` (24,305 345×36)
        - TEXT `Label` (36,305 333×36) **"실시간 온도, 주간 그래프, 이탈 안내 및 알림, 사육장 자동 작동 기준으로 사용됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Guide` (24,365 345×172)
      - FRAM `Title` (24,365 345×19)
        - TEXT `Label` (36,365 321×19) **"적정 습도 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,392 345×145) fill #FFFFFF r16
        - TEXT `습기는 60~80%, 건기는 40~60%를 유지해 주세요. 분무 후 6시` (36,404 321×42) **"습기는 60~80%, 건기는 40~60%를 유지해 주세요. 분무 후 6시간 이내에 건기에 진입하는 습도 사이클을 권장합니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `최대 습도는 분무 직후 측정된 습도에 맞춰 설정해 주세요` (36,454 321×21) **"최대 습도는 분무 직후 측정된 습도에 맞춰 설정해 주세요"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `최저 습도 미만으로 떨어지면 즉시 알림을 보내고, 최고 습도를 1시간 이` (36,483 321×42) **"최저 습도 미만으로 떨어지면 즉시 알림을 보내고, 최고 습도를 1시간 이상 초과하면 알림을 보냅니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `변경 사항 취소` (146,765 100×28) **"변경 사항 취소"** 18/600 lh28 ls-0.36 #C00306

## S24 · (메모) · `1635:5398`

- FRAM `` (0,0 345×48) fill #192553
  - TEXT `0.1~4까지 0.1단위` (10,10 325×28) **"0.1~4까지 0.1단위"** 20/500 lh28 ls-0.4 #FFFFFF

## S28 · (메모) · `1643:6678`

- FRAM `` (0,0 345×48) fill #192553
  - TEXT `0.5 단위` (10,10 325×28) **"0.5 단위"** 20/500 lh28 ls-0.4 #FFFFFF

## S29 · (메모) · `1643:6680`

- FRAM `` (0,0 345×48) fill #192553
  - TEXT `5 단위` (10,10 325×28) **"5 단위"** 20/500 lh28 ls-0.4 #FFFFFF

## S17 · Button/Enabled · `1635:5413`

- FRAM `Button/Enabled` (0,0 96×40) fill #F4F4F4 r16
  - TEXT `− 빼기` (28,10 41×19) **"− 빼기"** 16/600 lh19.1 ls-0.32 #3C3C3C

## S20 · Button/Enabled · `1635:5423`

- FRAM `Button/Enabled` (0,0 96×40) fill #F4F4F4 r16
  - TEXT `+ 더하기` (20,10 55×19) **"+ 더하기"** 16/600 lh19.1 ls-0.32 #3C3C3C

## S18 · Button/Selected · `1635:5417`

- FRAM `Button/Selected` (0,0 96×40) fill #C00306 r16
  - TEXT `− 빼기` (28,10 41×19) **"− 빼기"** 16/700 lh19.1 ls-0.32 #FAFAFA

## S21 · Button/Selected · `1635:5415`

- FRAM `Button/Selected` (0,0 96×40) fill #C00306 r16
  - TEXT `+ 더하기` (20,10 55×19) **"+ 더하기"** 16/700 lh19.1 ls-0.32 #FAFAFA

## S16 · TempHumid_Setting · `1635:5551`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 268×21)
            - TEXT `보정 온도` (36,200 268×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (304,200 53×21)
            - TEXT `27.2℃` (304,200 53×21) **"27.2℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 318` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Enabled` (157,299 96×40) fill #F4F4F4 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - FRAM `Button/Selected` (261,299 96×40) fill #C00306 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/700 lh19.1 ls-0.32 #FAFAFA
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `1.0` (36,366 23×21) **"1.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 38×6) fill #C00306
        - RECT `Button` (192,358 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S14 · TempHumid_Setting · `1635:5603`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `보정값 설정` (160,74 72×19) **"보정값 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `ContentsWrap` (24,130 345×508)
    - FRAM `Top Wrap` (24,130 345×133)
      - FRAM `Top` (24,130 345×107) r16
        - FRAM `List` (24,130 345×54) fill #FFFFFF stroke #E3E3E3/
          - FRAM `Frame 101` (36,146 265×21)
            - TEXT `현재 측정 온도` (36,146 265×21) **"현재 측정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (301,146 56×21)
            - TEXT `26.2℃` (301,146 56×21) **"26.2℃"** 18/500 lh21.5 ls-0.36 #1E1E1E
        - FRAM `List` (24,184 345×53) fill #FFFFFF
          - FRAM `Frame 101` (36,200 269×21)
            - TEXT `보정 온도` (36,200 269×21) **"보정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (305,200 52×21)
            - TEXT `26.1℃` (305,200 52×21) **"26.1℃"** 18/500 lh21.5 ls-0.36 #C00306
      - FRAM `Sub` (24,245 345×18)
        - TEXT `Label` (36,245 333×18) **"실시간 온도와 주간 그래프에 보정 온도로 반영됩니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 318` (24,287 345×113) r16
      - FRAM `OnOff` (24,287 345×65) fill #FFFFFF stroke #E3E3E3/
        - TEXT `아래 값을` (36,308 66×21) **"아래 값을"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Buttons` (157,299 200×40)
          - FRAM `Button/Selected` (157,299 96×40) fill #C00306 r16
            - TEXT `− 빼기` (184,310 41×19) **"− 빼기"** 16/700 lh19.1 ls-0.32 #FAFAFA
          - FRAM `Button/Enabled` (261,299 96×40) fill #F4F4F4 r16
            - TEXT `+ 더하기` (282,310 55×19) **"+ 더하기"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Brightness` (24,352 345×48) fill #FFFFFF
        - TEXT `0.1` (36,366 22×21) **"0.1"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Slider` (157,373 200×6) fill #E3E3E3 r22
          - RECT `Percent` (157,373 10×6) fill #C00306
        - RECT `Button` (163,360 52×32) fill #FFFFFF r16
    - FRAM `Guide` (24,424 345×214)
      - FRAM `Title` (24,424 345×19)
        - TEXT `Label` (36,424 321×19) **"온도차 보정 가이드"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Info` (24,451 345×187) fill #FFFFFF r16
        - TEXT `모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환` (36,463 321×84) **"모듈박스 밑에는 온습도 센서가 부착되어있습니다. 따뜻한 공기가 위로 순환되므로 하단보다 상단 온도가 높게 측정될 수 있습니다. 이는 자연스러운 온도 차이이며, 센서의 측정 오류나 고장이 아닙니다."** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 ` (36,555 321×42) **"사육장 내부에 사용하는 백업의 배치나 밀도, 환기 상태에 따라 온도차의 정도가 달라집니다"** 14/500 lh21 ls-0.28 #3C3C3C
        - TEXT `보정 이전의 데이터에는 영향을 미치지 않습니다` (36,605 321×21) **"보정 이전의 데이터에는 영향을 미치지 않습니다"** 14/500 lh21 ls-0.28 #3C3C3C
  - FRAM `Buttons` (12,695 369×112)
    - FRAM `CTA` (12,695 369×56) fill #1E1E1E r12
      - TEXT `저장` (181,709 31×28) **"저장"** 18/600 lh28 ls-0.36 #FAFAFA
    - FRAM `TextButton` (12,751 369×56) r12
      - TEXT `취소` (181,765 31×28) **"취소"** 18/600 lh28 ls-0.36 #C00306

## S19 · Brightness · `1635:5673`

- FRAM `Brightness` (0,0 345×48) fill #FFFFFF
  - TEXT `0.1` (12,14 22×21) **"0.1"** 18/600 lh21.5 ls-0.36 #3C3C3C
  - FRAM `Slider` (133,21 200×6) fill #E3E3E3 r22
    - RECT `Percent` (133,21 6×6) fill #C00306
  - RECT `Button` (137,6 52×32) fill #FFFFFF r16

## S25 · Brightness · `1635:5683`

- FRAM `Brightness` (0,0 345×48) fill #FFFFFF
  - TEXT `4.0` (12,14 27×21) **"4.0"** 18/600 lh21.5 ls-0.36 #3C3C3C
  - FRAM `Slider` (133,21 200×6) fill #E3E3E3 r22
    - RECT `Percent` (133,21 150×6) fill #C00306
  - RECT `Button` (281,6 52×32) fill #FFFFFF r16

## S22 · (메모) · `1635:6150`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `1` (19,10 9×28) **"1"** 20/500 lh28 ls-0.4 #FFFFFF

## S09 · (메모) · `1635:6157`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `1` (19,10 9×28) **"1"** 20/500 lh28 ls-0.4 #FFFFFF

## S26 · (메모) · `1635:6153`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `2` (18,10 12×28) **"2"** 20/500 lh28 ls-0.4 #FFFFFF

## S12 · (메모) · `1635:6159`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `2` (18,10 12×28) **"2"** 20/500 lh28 ls-0.4 #FFFFFF

## S07 · (메모) · `1635:6155`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `3` (17,10 13×28) **"3"** 20/500 lh28 ls-0.4 #FFFFFF

## S15 · (메모) · `1635:6161`

- FRAM `` (0,0 47×48) fill #DA4A6A
  - TEXT `3` (17,10 13×28) **"3"** 20/500 lh28 ls-0.4 #FFFFFF

## S41 · BottomSheet · `1635:6168`

- FRAM `BottomSheet` (0,0 393×410) fill #F4F4F4
  - FRAM `Toggle_L` (24,24 345×32) fill #E3E3E3 r18
    - FRAM `Left` (26,26 168×28) fill #FFFFFF r14
      - TEXT `일반` (98,32 24×17) **"일반"** 14/700 lh16.7 ls-0.28 #3C3C3C
    - FRAM `Right` (198,26 168×28) r14
      - TEXT `예약` (271,32 24×17) **"예약"** 14/600 lh16.7 ls-0.28 #626262
  - FRAM `OnOff` (24,80 345×48) fill #FFFFFF r16
    - TEXT `전원 · 꺼짐` (36,94 74×21) **"전원 · 꺼짐 "** 18/600 lh21.5 ls-0.36 #3C3C3C
    - FRAM `Toggle_off` (281,88 80×32) fill #B4AEAE r16
      - RECT `Button` (283,90 50×28) fill #F4F4F4 r14
  - FRAM `BrightnessGroup` (24,152 345×71)
    - FRAM `Title` (24,152 345×19)
      - TEXT `Label` (36,152 321×19) **"작동 시간"** 16/600 lh19.1 ls-0.32 #949090
    - FRAM `Buttons` (24,179 345×44)
      - FRAM `Button/Enabled` (24,179 62×44) fill #FFFFFF r16
        - TEXT `10분` (40,192 31×19) **"10분"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Button/Enabled` (90,179 62×44) fill #FFFFFF r16
        - TEXT `30분` (104,192 34×19) **"30분"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Button/Enabled` (156,179 62×44) fill #FFFFFF r16
        - TEXT `1시간` (170,192 35×19) **"1시간"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Button/Enabled` (223,179 62×44) fill #FFFFFF r16
        - TEXT `2시간` (235,192 37×19) **"2시간"** 16/600 lh19.1 ls-0.32 #3C3C3C
      - FRAM `Button/Enabled` (289,179 80×44) fill #228C73 r16
        - TEXT `계속` (315,192 28×19) **"계속"** 16/700 lh19.1 ls-0.32 #FAFAFA
  - FRAM `Frame 319` (24,247 345×111) stroke #E3E3E3/
    - FRAM `OnOff` (24,268 345×48) fill #FFFFFF r16
      - TEXT `자동 환기` (36,282 74×21) **"자동 환기"** 18/600 lh21.5 ls-0.36 #3C3C3C
      - FRAM `Toggle_off` (281,276 80×32) fill #B4AEAE r16
        - RECT `Button` (283,278 50×28) fill #F4F4F4 r14
    - FRAM `Title` (24,324 345×34)
      - TEXT `Label` (36,324 321×34) **"습도 80% 초과 또는 온도 26℃ 초과 시 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다"** 14/500 lh16.7 ls-0.28 #949090

## S31 · BottomSheet · `1657:5326`

- FRAM `BottomSheet` (0,0 393×521) fill #F4F4F4
  - FRAM `Toggle_L` (24,24 345×32) fill #E3E3E3 r18
    - FRAM `Left` (26,26 168×28) fill #FFFFFF r14
      - TEXT `즉시 작동` (85,32 51×17) **"즉시 작동"** 14/700 lh16.7 ls-0.28 #3C3C3C
    - FRAM `Right` (198,26 168×28) r14
      - TEXT `예약 작동` (257,32 51×17) **"예약 작동"** 14/600 lh16.7 ls-0.28 #626262
  - FRAM `OnOff` (24,80 345×87) fill #FFFFFF r16
    - TEXT `예약 일정이 작동 중입니다` (36,92 321×21) **"예약 일정이 작동 중입니다"** 18/600 lh21.5 ls-0.36 #3C3C3C
    - TEXT `예약을 일정을 중지하면 즉시 작동 기능을 다시 사용할 수 있습니다` (36,121 321×34) **"예약을 일정을 중지하면  ⏎ 즉시 작동 기능을 다시 사용할 수 있습니다"** 14/600 lh16.7 ls-0.28 #949090
  - FRAM `OnOff_N` (24,191 345×48) fill #E3E3E3 r16
    - TEXT `전원 · 꺼짐` (36,204 74×21) **"전원 · 꺼짐 "** 18/600 lh21.5 ls-0.36 #949090
    - FRAM `Toggle_off` (281,199 80×32) fill #B4AEAE r16
      - RECT `Button` (283,201 50×28) fill #F4F4F4 r14
  - FRAM `BrightnessGroup` (24,263 345×71)
    - FRAM `Title` (24,263 345×19)
      - TEXT `Label` (36,263 321×19) **"작동 시간"** 16/600 lh19.1 ls-0.32 #949090
    - FRAM `Buttons` (24,290 345×44)
      - FRAM `Button/Enabled` (24,290 62×44) fill #E3E3E3 r16
        - TEXT `10분` (40,302 31×19) **"10분"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Button/Enabled` (90,290 62×44) fill #E3E3E3 r16
        - TEXT `30분` (104,302 34×19) **"30분"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Button/Enabled` (156,290 62×44) fill #E3E3E3 r16
        - TEXT `1시간` (170,302 35×19) **"1시간"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Button/Enabled` (223,290 62×44) fill #E3E3E3 r16
        - TEXT `2시간` (235,302 37×19) **"2시간"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `Button/Enabled` (289,290 80×44) fill #B4AEAE r16
        - TEXT `계속` (315,302 28×19) **"계속"** 16/700 lh19.1 ls-0.32 #FAFAFA
  - FRAM `Frame 319` (24,358 345×111) stroke #E3E3E3/
    - FRAM `OnOff` (24,379 345×48) fill #E3E3E3 r16
      - TEXT `자동 환기` (36,392 74×21) **"자동 환기"** 18/600 lh21.5 ls-0.36 #949090
      - FRAM `Toggle_off` (281,387 80×32) fill #B4AEAE r16
        - RECT `Button` (283,389 50×28) fill #F4F4F4 r14
    - FRAM `Title` (24,435 345×34)
      - TEXT `Label` (36,435 321×34) **"습도 80% 초과 또는 온도 26℃ 초과 시 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다"** 14/500 lh16.7 ls-0.28 #949090

## S42 · BottomSheet · `1657:5353`

- FRAM `BottomSheet` (0,0 393×273) fill #F4F4F4
  - FRAM `Toggle_L` (24,24 345×32) fill #E3E3E3 r18
    - FRAM `Left` (26,26 168×28) fill #FFFFFF r14
      - TEXT `즉시 작동` (85,32 51×17) **"즉시 작동"** 14/700 lh16.7 ls-0.28 #3C3C3C
    - FRAM `Right` (198,26 168×28) r14
      - TEXT `예약 작동` (257,32 51×17) **"예약 작동"** 14/600 lh16.7 ls-0.28 #626262
  - FRAM `Frame 319` (24,80 345×73)
    - FRAM `OnOff` (24,80 345×48) fill #FFFFFF r16
      - TEXT `자동 분무` (36,94 74×21) **"자동 분무"** 18/600 lh21.5 ls-0.36 #3C3C3C
      - FRAM `Toggle_off` (281,88 80×32) fill #B4AEAE r16
        - RECT `Button` (283,90 50×28) fill #F4F4F4 r14
    - FRAM `Title` (24,136 345×17)
      - TEXT `Label` (36,136 321×17) **"습도가 40% 미만으로 내려가면 자동으로 1회 분무"** 14/500 lh16.7 ls-0.28 #949090
  - FRAM `CTA` (24,177 345×44) fill #2E408C r12
    - TEXT `1회 분사 시작` (156,185 82×28) **"1회 분사 시작"** 16/600 lh28 ls-0.32 #FAFAFA

## S43 · BottomSheet · `1657:5361`

- FRAM `BottomSheet` (0,0 393×384) fill #F4F4F4
  - FRAM `Toggle_L` (24,24 345×32) fill #E3E3E3 r18
    - FRAM `Left` (26,26 168×28) fill #FFFFFF r14
      - TEXT `즉시 작동` (85,32 51×17) **"즉시 작동"** 14/700 lh16.7 ls-0.28 #3C3C3C
    - FRAM `Right` (198,26 168×28) r14
      - TEXT `예약 작동` (257,32 51×17) **"예약 작동"** 14/600 lh16.7 ls-0.28 #626262
  - FRAM `OnOff` (24,80 345×87) fill #FFFFFF r16
    - TEXT `예약 일정이 작동 중입니다` (36,92 321×21) **"예약 일정이 작동 중입니다"** 18/600 lh21.5 ls-0.36 #3C3C3C
    - TEXT `예약을 일정을 중지하면 즉시 작동 기능을 다시 사용할 수 있습니다` (36,121 321×34) **"예약을 일정을 중지하면  ⏎ 즉시 작동 기능을 다시 사용할 수 있습니다"** 14/600 lh16.7 ls-0.28 #949090
  - FRAM `Frame 319` (24,191 345×73)
    - FRAM `OnOff` (24,191 345×48) fill #E3E3E3 r16
      - TEXT `자동 분무` (36,204 74×21) **"자동 분무"** 18/600 lh21.5 ls-0.36 #949090
      - FRAM `Toggle_off` (281,199 80×32) fill #B4AEAE r16
        - RECT `Button` (283,201 50×28) fill #F4F4F4 r14
    - FRAM `Title` (24,247 345×17)
      - TEXT `Label` (36,247 321×17) **"습도가 40% 미만으로 내려가면 자동으로 1회 분무"** 14/500 lh16.7 ls-0.28 #949090
  - FRAM `CTA` (24,288 345×44) fill #E3E3E3 r12
    - TEXT `1회 분사 시작` (156,296 82×28) **"1회 분사 시작"** 16/600 lh28 ls-0.32 #FAFAFA

## S39 · PushAlarm · `1657:5547`

- FRAM `PushAlarm` (0,0 393×852) fill #F4F4F4
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - TEXT `알림` (182,74 28×19) **"알림"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Frame 249` (12,118 372×557)
    - FRAM `Alarm_func` (12,118 372×339)
      - FRAM `Title` (12,118 372×19)
        - TEXT `Label` (24,118 348×19) **"기능 설정"** 16/500 lh19.1 ls-0.32 #949090
      - FRAM `Button/Abled` (12,146 372×72) fill #FFFFFF r12
        - FRAM `Frame 12` (28,162 252×40)
          - TEXT `하이라이트 영상` (28,162 252×19) **"하이라이트 영상"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `하이라이트가 도착했을 때 받는 알림` (28,184 252×17) **"하이라이트가 도착했을 때 받는 알림"** 14/500 lh16.7 ls-0.28 #949090
        - FRAM `Toggle_on` (288,166 80×32) fill #C00306 r16
          - RECT `Button` (316,168 50×28) fill #F4F4F4 r14
      - FRAM `Button/Abled` (12,226 372×72) fill #FFFFFF r12
        - FRAM `Frame 12` (28,242 254×40)
          - TEXT `온습도 이탈 알림` (28,242 254×19) **"온습도 이탈 알림"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `적정 온습도에서 이탈했을 때 받는 알림` (28,264 254×17) **"적정 온습도에서 이탈했을 때 받는 알림"** 14/500 lh16.7 ls-0.28 #949090
        - FRAM `Right` (290,252 77×19)
          - TEXT `설정하기` (290,252 55×19) **"설정하기"** 16/500 lh19.1 ls-0.32 #949090
          - GROU `arrow_forward_ios` (350,252 18×18)
            - RECT `Bounding box` (350,252 18×18) fill #3C3C3C
      - FRAM `Button/Abled` (12,306 372×72) fill #FFFFFF r12
        - FRAM `Frame 12` (28,322 252×40)
          - TEXT `커뮤니티 댓글` (28,322 252×19) **"커뮤니티 댓글"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `내가 쓴 게시물에 댓글이 달렸을 때 받는 알림` (28,344 252×17) **"내가 쓴 게시물에 댓글이 달렸을 때 받는 알림"** 14/500 lh16.7 ls-0.28 #949090
        - FRAM `Toggle_off` (288,326 80×32) fill #B4AEAE r16
          - RECT `Button` (290,328 50×28) fill #F4F4F4 r14
      - FRAM `Button/Abled` (12,386 372×72) fill #FFFFFF r12
        - FRAM `Frame 12` (28,402 252×40)
          - TEXT `커뮤니티 좋아요` (28,402 252×19) **"커뮤니티 좋아요"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `내가 쓴 게시물에 좋아요를 받았을 때 받는 알림` (28,424 252×17) **"내가 쓴 게시물에 좋아요를 받았을 때 받는 알림"** 14/500 lh16.7 ls-0.28 #949090
        - FRAM `Toggle_on` (288,406 80×32) fill #C00306 r16
          - RECT `Button` (316,408 50×28) fill #F4F4F4 r14
    - FRAM `Alarm_market` (12,482 372×194)
      - FRAM `Title` (12,482 372×19)
        - TEXT `Label` (24,482 348×19) **"수신 동의 관리"** 16/500 lh19.1 ls-0.32 #949090
      - FRAM `Button/Abled` (12,508 372×72) fill #FFFFFF r12
        - FRAM `Frame 12` (28,524 252×40)
          - TEXT `비바나트에서 보내는 소식` (28,524 252×19) **"비바나트에서 보내는 소식"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `업데이트, 공지사항 등 운영 이벤트 알림` (28,548 252×17) **"업데이트, 공지사항 등 운영 이벤트 알림"** 14/500 lh16.7 ls-0.28 #949090
        - FRAM `Toggle_on` (288,528 80×32) fill #C00306 r16
          - RECT `Button` (316,530 50×28) fill #F4F4F4 r14
      - FRAM `Button/Abled` (12,588 372×87) fill #FFFFFF r12
        - FRAM `Frame 12` (28,604 252×55)
          - TEXT `마케팅 수신 동의` (28,604 252×19) **"마케팅 수신 동의"** 16/600 lh19.1 ls-0.32 #3C3C3C
          - TEXT `수신 동의 2026. 9. 16 개인정보 수집 이용 및 광고성 정보 수신` (28,628 252×32) **"수신 동의 2026. 9. 16 ⏎ 개인정보 수집 이용 및 광고성 정보 수신에 동의합니다"** 12/500 lh16 ls-0.24 #949090
        - FRAM `Toggle_on` (288,616 80×32) fill #C00306 r16
          - RECT `Button` (316,618 50×28) fill #F4F4F4 r14

## S40 · TempHumid_Setting · `1657:5600`

- FRAM `TempHumid_Setting` (0,0 393×852) fill #F4F4F4
  - RECT `Rectangle 113` (0,0 393×106) fill #FAFAFA stroke #E3E3E3/
  - INST `Status bar` (0,0 393×62)
    - FRAM `Time` (16,21 104×22)
      - TEXT `Time` (49,22 37×22) **"9:41"** 17/590 lh22 #000000
    - FRAM `Levels` (274,21 104×22)
      - GROU `Battery` (337,26 27×13)
        - RECT `Border` (337,26 25×13) stroke #000000/ r4.300000190734863
        - RECT `Capacity` (339,28 21×9) fill #000000 r2.5
  - TEXT `온습도 설정` (160,74 72×19) **"온습도 설정"** 16/700 lh19.1 ls-0.32 #1E1E1E
  - FRAM `Button/Enabled` (12,62 44×44) r22
    - GROU `arrow_back_ios_new` (22,72 24×24)
      - RECT `Bounding box` (22,72 24×24) fill #3C3C3C
  - FRAM `Frame 316` (24,130 345×449)
    - FRAM `Frame 313` (24,130 345×101)
      - FRAM `Title` (24,130 345×19)
        - TEXT `Label` (36,130 321×19) **"온도 보정"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `OnOff` (24,157 345×48) fill #FFFFFF r16
        - TEXT `온도 보정` (36,170 66×21) **"온도 보정"** 18/600 lh21.5 ls-0.36 #3C3C3C
        - FRAM `Toggle_off` (281,165 80×32) fill #B4AEAE r16
          - RECT `Button` (283,167 50×28) fill #FAFAFA r14
      - FRAM `Sub` (24,213 345×18)
        - TEXT `Label` (36,213 333×18) **"사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 314` (24,255 345×150)
      - FRAM `Title` (24,255 345×19)
        - TEXT `Label` (36,255 321×19) **"온도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,282 345×97) r16
        - FRAM `OnOff` (24,282 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `적정 온도 이탈 알림` (36,296 134×21) **"적정 온도 이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,290 80×32) fill #C00306 r16
            - RECT `Button` (309,292 50×28) fill #FAFAFA r14
        - FRAM `List` (24,331 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,344 207×21)
            - TEXT `적정 온도` (36,344 207×21) **"적정 온도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (247,346 110×19)
            - TEXT `18℃ ~ 26℃` (247,346 88×19) **"18℃ ~ 26℃"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,346 18×18)
              - RECT `Bounding box` (339,346 18×18) fill #3C3C3C
      - FRAM `Sub` (24,387 345×18)
        - TEXT `Label` (36,387 333×18) **"18℃ 미만이거나 26℃ 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
    - FRAM `Frame 315` (24,429 345×150)
      - FRAM `Title` (24,429 345×19)
        - TEXT `Label` (36,429 321×19) **"습도"** 16/600 lh19.1 ls-0.32 #949090
      - FRAM `List` (24,456 345×97) r16
        - FRAM `OnOff` (24,456 345×49) fill #FFFFFF stroke #E3E3E3/
          - TEXT `적정 습도 이탈 알림` (36,470 134×21) **"적정 습도 이탈 알림"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Toggle_on` (281,464 80×32) fill #C00306 r16
            - RECT `Button` (309,466 50×28) fill #FAFAFA r14
        - FRAM `List` (24,505 345×48) fill #FFFFFF
          - FRAM `Frame 101` (36,518 211×21)
            - TEXT `적정 습도` (36,518 211×21) **"적정 습도"** 18/600 lh21.5 ls-0.36 #3C3C3C
          - FRAM `Right` (251,520 106×19)
            - TEXT `40% ~ 80%` (251,520 84×19) **"40% ~ 80%"** 16/500 lh19.1 ls-0.32 #949090
            - GROU `arrow_forward_ios` (339,520 18×18)
              - RECT `Bounding box` (339,520 18×18) fill #3C3C3C
      - FRAM `Sub` (24,561 345×18)
        - TEXT `Label` (36,561 333×18) **"40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다"** 14/500 lh18 ls-0.28 #949090
