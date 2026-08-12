# 워카웃 (WorkoutApp) — 프로젝트 가이드

SwiftUI iOS 운동 기록 앱. 흰색 + 연한 파란색 테마. 언어는 한국어.

## 위치 · 빌드
- Xcode 프로젝트: `~/Desktop/WorkoutApp/WorkoutApp/WorkoutApp.xcodeproj` (Xcode 16, iOS 18.x)
- 앱 소스: `~/Desktop/WorkoutApp/WorkoutApp/WorkoutApp/` — **동기화 폴더 그룹**이라 새 `.swift`는 자동으로 앱 타겟에 포함됨
- 위젯 소스: `~/Desktop/WorkoutApp/WorkoutApp/WorkoutWidget/`
- 번들 ID: `com.oddong.WorkoutApp` / 위젯 `com.oddong.WorkoutApp.WorkoutWidget`
- **App Group**: `group.com.oddong.WorkoutApp` (코드 `SharedStore.appGroup`와 두 타겟 설정이 일치해야 함)
- 표시 이름: `워카웃` (`INFOPLIST_KEY_CFBundleDisplayName`)
- 타입체크(코드 확인용, 앱 타겟):
  ```
  cd ~/Desktop/WorkoutApp/WorkoutApp/WorkoutApp
  SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
  swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
    WorkoutApp.swift DataStore.swift Models.swift StatsView.swift ExercisePickerView.swift \
    WorkoutSessionView.swift MainView.swift RadarChart.swift \
    WorkoutActivityAttributes.swift WorkoutActivityController.swift 2>&1 | grep error:
  ```

## 파일 구조 (앱)
- `WorkoutApp.swift` — `@main` App, RootView(TabView 홈/리포트), `Theme`(블루 팔레트), `.cardShadow()`, `SplashView`(스플래시)
- `Models.swift` — `Exercise`, `BodyPart`(+`cardio`, `subRegions`, `subRegion(of:)`), `EquipmentType`, `PlannedSet`(+`duration`/`distance`, `defaults(for:)`, `summary(cardio:)`), `PlannedExercise`, `WorkoutPlan`, `WorkoutRecord`, `KoName`(번역기+사전), `AICoach`/`WorkoutAdvice`, `Fatigue`(회복 모델), `SharedStore`(App Group I/O)
- `DataStore.swift` — `ObservableObject`. exercises/plans/records. App Group 저장 + 레거시 Documents 자동 이관 + `WidgetCenter.reloadAllTimelines()`
- `MainView.swift` — 홈(인사·추천카드·시작버튼·플랜목록·플랜선택시트[빈 플랜 포함]), `PlanEditorView`, `SetField`
- `ExercisePickerView.swift` — 운동 선택(검색+**소스 칩[기본/최근 운동(2주)/즐겨찾기]**+부위/세부부위/기구 필터, 행에 **썸네일**(`ExerciseThumb`, AsyncImage GIF 첫 프레임)+**북마크 토글**), `ExerciseDetailView`(GIF+내기록 그래프/PR+AI가이드), **이미지 추상화**(`ExerciseImageProvider`/`HasanGIFProvider`/`ExerciseMedia`), `GIFView`, `ExerciseMotionView`. 즐겨찾기는 `DataStore.favorites`(Set<String>, favorites.json), 최근은 `recentExerciseIDs(days:)`
- `BodyFatigueView.swift` — "부위별 피로도" 인체 근육맵(전면/후면, 매끈한 실루엣 스타일) — `Fatigue.levels()` 기반 부위별 파란 틴트(진할수록 피로). 벡터 데이터는 **react-native-body-highlighter(MIT)** 의 SVG 패스를 절대좌표 M/L/C/Z로 오프라인 변환해 파일에 내장(viewBox 724×1448, 미니 파서 + Canvas 렌더링, 이미지 에셋 불필요). **앱+위젯 공용**(pbxproj membershipExceptions 포함, Theme 참조 금지)
- `WorkoutSessionView.swift` — 세션(운동 네비게이터·GIF·세트·휴식타이머·AI코치·지난기록·유산소입력), `WorkoutResultView`(종료 결과창)
- `StatsView.swift` — 리포트(스트릭·주간추이차트·부위밸런스[기간토글]·달력·일별상세)
- `RadarChart.swift` — 레이더 차트
- `InBodyView.swift` — 인바디 탭(CSV 업로드→`fileImporter`, 최근 측정 요약+증감, **AI 코치 조언**, 추이 차트[체중/골격근량/체지방률], 측정 목록). 파서는 `InBodyRecord.parse(csv:)`(Models.swift) — 헤더 키워드 자동 감지(열 순서 무관), EUC-KR 폴백, 날짜 정규식(압축 `20260709` 포함), **중복 날짜는 제외**하고 새 날짜만 추가(`DataStore.mergeInBody`). `InBodyCoach.advice()`(Models.swift) — 직전 측정 대비 골격근×체지방 4분면 판정(오차 임계 근육±0.3kg/체지방률±0.5%p) + 급격 체중 변화(주1%↑) 경고, 첫 측정/체중만 있는 경우 별도 처리
- `WorkoutActivityAttributes.swift`(앱+위젯 공용), `WorkoutActivityController.swift`(앱 전용, Live Activity 제어)
- `exercises.json` — 운동 1,081개 (아래 데이터셋 참고)

## 파일 구조 (위젯)
- `WorkoutWidgetBundle.swift`(`@main`, 위젯 공용 색 `wOrange` 등), `FatigueWidget.swift`(홈/잠금 7일 피로도 — 홈 소형/중형은 **인체 그림**(`BodyFatigueView`), 잠금 액세서리는 텍스트/게이지), `WorkoutLiveActivity.swift`(다이나믹 아일랜드/잠금 Live Activity)

## 데이터 & 이미지
- **데이터셋**: `hasaneyldrm/exercises-dataset` (ExerciseDB/GymVisual 계열)을 앱 스키마로 **변환**해 사용. 이름은 `KoName`으로 한글 음차. 기존 free-exercise-db 백업: `~/Desktop/WorkoutApp/exercises.free-db.bak.json`
- 변환 매핑: `target`(delts/pectorals/quads…) → free-db 근육 어휘(shoulders/chest/quadriceps…)로 바꿔 넣어 `BodyPart.of()` 무수정. `equipment`는 5대 기구 문자열로 매핑.
- **이미지/GIF**: hasaneyldrm GitHub raw(`videos/xxx.gif`). 소스 교체 지점은 **`ExerciseMedia.provider` 한 줄**.
  - ⚠️ **라이선스**: 이미지는 GymVisual 소유(비상업/180×180/출처표기 필수). GIF에 `© Gym visual` 표기 있음. **상업 출시 전 반드시 다른 소스로 교체.**

## 핵심 로직
- `BodyPart`: 6개 근육부위 + `cardio`. `primaryMuscles`(free-db 어휘)로 매핑. 세부부위(중분류)는 어깨/가슴/등/하체만, 이름 키워드로 자동 분류.
- `Fatigue`: 근육별 지수 회복 모델. 완전회복 하체·등 72h / 가슴·어깨 48h / 이두·삼두 40h / 유산소 24h. `levels()` 0~1.
- `MuscleMap.stimuli(for:)` + `MuscleRegion(part, sub)`: 운동→자극 부위 매핑(주동근 1.0 + 협응근 0.2~0.6, 예: 벤치=가슴·중부 1.0/삼두 0.5/어깨·전면 0.3). `Fatigue.regionLevels()`가 세부부위 단위 피로도 dict 반환(sub=nil은 부위 집계). 매칭은 AICoach와 동일한 `hit()`(영문+한글 음차). 신체 모델·리포트 칩·결과창·위젯이 모두 이걸 사용.
- 피로도 색: `BodyFatigueView.heat(level)` 히트 램프(연하늘→블루→진남색) — 투명도 대신 색상 보간이라 44% vs 100% 대비가 또렷. 신체 모델·리포트 칩 공용.
- 피로/자세 모델은 2026-07 문헌 검토 완료: 회복 시간 상수·볼륨(세트) 기반이 ACSM/NSCA·MEV/MAV 연구와 정합(Models.swift `Fatigue` 주석). AICoach의 "무릎이 발끝을 넘지 않게"(런지) 통설은 Fry 2003/Schoenfeld 2010 근거로 "무릎=발끝 방향 정렬"로 수정함.
- `PlannedSet`: 웨이트는 weight/reps, **유산소는 duration(초)/distance(km)** (옵셔널, 기존 기록 호환). `defaults(for:)`로 부위별 기본 구성.
- `KoName`: 단어 음차 사전 + 하이픈/슬래시/언더스코어 분리 + 불용어 제거. 새 운동 이름 추가 시 미번역 단어를 사전에 보충.
- `AICoach`: 동작별 전용 조언(웨이트 25+패턴, 유산소 8패턴+기본, 커버리지 ~77%) + **변형 노트**(`WorkoutAdvice.variation`, 최대 2개 — 그립/각도/자세/기구 차이 설명, 예: 해머컬=상완근·측면 두께 vs 일반 컬=이두 전체. 웨이트의 ~74% 부착). ⚠️ 현 데이터셋 id가 **숫자**라 `id+표시이름(한글 음차)`에서 단어 추출, 영문 키워드를 `KoName.dict`로 음차까지 대조(`hit()`). 키워드 추가 시 해당 단어가 KoName 사전에 있어야 한글 매칭됨.

## 구현 완료 기능
- 운동 카탈로그(GIF), 검색, 3단계 필터(부위/세부부위/기구), 유산소 분리(시간·거리)
- 플랜 생성/편집/삭제, 빈 플랜(일회용) 시작
- 세션: 운동 네비게이터(완료운동 재진행/수정), GIF, AI 자세코치, **휴식 타이머(±10초·종료·햅틱)**, **지난 기록 표시**, 종료 **결과창**(시간/칼로리/부위 피로)
- 리포트: **스트릭**(연속/이번달/전체), **주간 볼륨·횟수 추이 차트**, 부위 밸런스 레이더(**기간 1주/1개월/전체**), 달력, 일별 상세(**선택 날짜 수동 기록 추가 + 버튼** → `ManualRecordView`, StatsView.swift)
- **다크모드 무시**: 앱 `.preferredColorScheme(.light)`(WorkoutApp.swift), 홈 위젯 흰색 `.containerBackground` 고정(FatigueWidget.swift)
- 운동별 **성장 그래프 + PR**(운동 설명 페이지)
- 홈 추천 카드(부족 부위 + 플랜 추천, 회복 모델 기반)
- 다이나믹 아일랜드/잠금 Live Activity, 홈/잠금 피로도 위젯
- 스플래시(“워카웃” 물드는 애니메이션), 앱 아이콘(파란 덤벨), 블루 테마

## Xcode 수동 설정 (빌드 전 필요)
- Widget Extension 타겟에 위젯 3파일 + `Models.swift` + `WorkoutActivityAttributes.swift` + `BodyFatigueView.swift` 멤버십
- App Group `group.com.oddong.WorkoutApp` — **앱·위젯 두 타겟 모두** + Signing Team(Personal) 선택 (안 하면 위젯 데이터 공유·다이나믹아일랜드 안 됨)
- `NSSupportsLiveActivities`=YES (앱 Info, pbxproj에 반영됨)

## 남은 로드맵
- 인바디 데이터 기반 무게 추천·운동 추천 (근성장/체중 고려 — 기록 기능은 완료, 추천은 추후)
- 2순위: HealthKit 연동, iCloud/백업, 알림(회복 완료·복귀 유도), 유산소 칼로리 정밀화(MET)
- AI 코칭/챗봇 — **Claude API + 백엔드 프록시**(키는 앱에 넣지 않음). 데이터 쌓인 뒤 진행 예정
- 다듬기: 유산소 피로도 가중치, 휴식 기본값(90초) 설정화, 등>승모 세부부위 비어있음

## 주의/결정 사항
- `Exercise.level`은 데이터셋에 없어 전부 `intermediate`(화면 미표시)
- 데이터셋 교체로 예전 free-db id를 참조하던 플랜/기록은 연결 끊김(개발용이라 무방)
- 코드 컨벤션: 기존 스타일 유지, 최소 변경 원칙. 새 UI는 `Theme` 색·`.cardShadow()`·`.strokeBorder` 사용
