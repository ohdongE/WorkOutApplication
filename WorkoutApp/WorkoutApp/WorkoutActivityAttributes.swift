import Foundation
import ActivityKit

// ⚠️ 이 파일은 앱 타겟과 위젯 타겟 "둘 다"에 포함(Target Membership)되어야 합니다.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exercise: String        // 현재 운동 이름
        var setProgress: String     // "2/4"
        var exProgress: String      // "1/5"
        var startedAt: Date         // 경과 시간 계산 기준
    }
    var planName: String            // 플랜 이름 (고정)
}
