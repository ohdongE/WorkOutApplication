import WidgetKit
import SwiftUI

// 위젯 익스텐션의 진입점. (이 파일들은 "WorkoutWidgetExtension" 타겟에만 포함)
@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        FatigueWidget()                     // 홈/잠금화면 7일 피로도 위젯
        if #available(iOS 16.2, *) {
            WorkoutLiveActivity()           // 다이나믹 아일랜드 / 잠금화면 Live Activity
        }
    }
}

// 위젯 공용 색 (메인: 연한 파란색)
let wOrange  = Color(red: 0.30, green: 0.65, blue: 0.91)  // 메인 블루
let wOrangeD = Color(red: 0.18, green: 0.55, blue: 0.84)  // 진한 블루
let wOrangeL = Color(red: 0.92, green: 0.96, blue: 0.99)  // 연한 블루 배경
let wSub     = Color(red: 0.61, green: 0.65, blue: 0.69)  // 보조 텍스트(쿨그레이)
let wTxt     = Color(red: 0.39, green: 0.44, blue: 0.49)  // 본문 텍스트
