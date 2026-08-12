import Foundation
import ActivityKit

// 앱 타겟 전용. Live Activity 시작/갱신/종료를 관리합니다.
@available(iOS 16.2, *)
enum WorkoutActivityController {
    private static var activity: Activity<WorkoutActivityAttributes>?

    static func start(planName: String, exercise: String,
                      setProgress: String, exProgress: String, startedAt: Date) {
        // 시스템 설정에서 Live Activity가 꺼져 있으면 조용히 무시
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🟠 LiveActivity: areActivitiesEnabled == false (설정에서 꺼짐 or Info.plist 키 없음)")
            return
        }
        guard activity == nil else {
            update(exercise: exercise, setProgress: setProgress,
                   exProgress: exProgress, startedAt: startedAt)
            return
        }
        let attrs = WorkoutActivityAttributes(planName: planName)
        let state = WorkoutActivityAttributes.ContentState(
            exercise: exercise, setProgress: setProgress,
            exProgress: exProgress, startedAt: startedAt)
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil)
            print("🟢 LiveActivity 시작됨: id=\(activity?.id ?? "nil")")
        } catch {
            activity = nil
            print("🔴 LiveActivity 시작 실패: \(error)")
        }
    }

    static func update(exercise: String, setProgress: String,
                       exProgress: String, startedAt: Date) {
        guard let activity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            exercise: exercise, setProgress: setProgress,
            exProgress: exProgress, startedAt: startedAt)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    static func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
