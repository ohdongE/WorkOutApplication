import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // 잠금화면 / 배너 표시
            lockScreen(context)
                .activityBackgroundTint(wOrangeL)
                .activitySystemActionForegroundColor(wOrangeD)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.planName, systemImage: "dumbbell.fill")
                        .font(.caption).foregroundStyle(wOrange).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(wOrangeD)
                        .frame(maxWidth: 60, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exercise).font(.footnote.weight(.semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("세트 \(context.state.setProgress)").font(.caption2)
                        Spacer()
                        Text("운동 \(context.state.exProgress)").font(.caption2)
                    }.foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(wOrange)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(wOrangeD)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(wOrange)
            }
            .keylineTint(wOrange)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title2).foregroundStyle(wOrange)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.planName)
                    .font(.caption.weight(.semibold)).foregroundStyle(wOrange)
                Text(context.state.exercise)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(wTxt).lineLimit(1)
                Text("세트 \(context.state.setProgress) · 운동 \(context.state.exProgress)")
                    .font(.caption2).foregroundStyle(wSub)
            }
            Spacer()
            Text(context.state.startedAt, style: .timer)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(wOrangeD)
                .frame(maxWidth: 70, alignment: .trailing)
        }
        .padding()
    }
}
