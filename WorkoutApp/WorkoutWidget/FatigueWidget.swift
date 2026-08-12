import WidgetKit
import SwiftUI

// MARK: - 타임라인
struct FatigueEntry: TimelineEntry {
    let date: Date
    let levels: [PartLevel]                 // 부위 집계 (텍스트 표시용)
    let regions: [MuscleRegion: Double]     // 세부부위 (인체 그림 색칠용)
    let overall: Int
    let hasData: Bool
}

struct PartLevel: Hashable, Codable {
    let name: String
    let level: Double
}

struct FatigueProvider: TimelineProvider {
    func placeholder(in context: Context) -> FatigueEntry { Self.sample }

    func getSnapshot(in context: Context, completion: @escaping (FatigueEntry) -> Void) {
        completion(context.isPreview ? Self.sample : make())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FatigueEntry>) -> Void) {
        // 3시간마다 갱신(피로도 시간 감쇠 반영). 앱에서 기록 변경 시엔 즉시 reload됨.
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: .now)!
        completion(Timeline(entries: [make()], policy: .after(next)))
    }

    private func make() -> FatigueEntry {
        let recs = SharedStore.loadRecords()
        let levels = Fatigue.levels(recs).map { PartLevel(name: $0.part.rawValue, level: $0.level) }
        let hasData = levels.contains { $0.level > 0 }
        return FatigueEntry(date: .now, levels: levels,
                            regions: Fatigue.regionLevels(recs),
                            overall: Fatigue.overall(recs), hasData: hasData)
    }

    static let sample = FatigueEntry(
        date: .now,
        levels: [PartLevel(name: "가슴", level: 0.9), PartLevel(name: "등", level: 0.6),
                 PartLevel(name: "어깨", level: 0.4), PartLevel(name: "하체", level: 0.8),
                 PartLevel(name: "이두", level: 0.2), PartLevel(name: "삼두", level: 0.3)],
        regions: [MuscleRegion(part: .chest, sub: nil): 0.9,
                  MuscleRegion(part: .back, sub: "광배"): 0.6,
                  MuscleRegion(part: .shoulder, sub: nil): 0.4,
                  MuscleRegion(part: .lower, sub: "대퇴"): 0.8,
                  MuscleRegion(part: .biceps, sub: nil): 0.2,
                  MuscleRegion(part: .triceps, sub: nil): 0.3],
        overall: 64, hasData: true)
}

// MARK: - 위젯 정의
struct FatigueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FatigueWidget", provider: FatigueProvider()) { entry in
            FatigueWidgetView(entry: entry)
        }
        .configurationDisplayName("7일 운동 피로도")
        .description("최근 7일간 부위별 운동 피로도를 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - 뷰 (패밀리별 분기)
struct FatigueWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FatigueEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:        mediumView
            case .accessoryRectangular: rectView
            case .accessoryCircular:    circularView
            default:                    smallView
            }
        }
        // 홈 위젯은 흰색 고정(다크모드 무시), 잠금화면 액세서리는 시스템 렌더링
        .containerBackground(for: .widget) {
            (family == .systemSmall || family == .systemMedium) ? Color.white : Color.clear
        }
    }

    // 홈 소형: 전체 % + 인체 그림(앞/뒤)
    private var smallView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("피로도").font(.caption2.weight(.semibold)).foregroundStyle(wSub)
                Spacer()
                Text("\(entry.overall)%").font(.caption.weight(.bold)).foregroundStyle(wOrange)
            }
            if entry.hasData {
                BodyFatigueView(levels: entry.regions, accent: wOrange,
                                figureHeight: 96, spacing: 12, showLabels: false)
                    .frame(maxHeight: .infinity)
            } else {
                emptyText
            }
        }
    }

    // 홈 중형: 인체 그림(앞/뒤) + 전체 % + 상위 부위
    private var mediumView: some View {
        HStack(spacing: 14) {
            BodyFatigueView(levels: entry.regions, accent: wOrange,
                            figureHeight: 108, spacing: 12, showLabels: false)
                .frame(width: 116)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill").font(.caption2).foregroundStyle(wOrange)
                    Text("7일 운동 피로도").font(.caption.weight(.semibold)).foregroundStyle(wTxt)
                }
                Text("전체 \(entry.overall)%").font(.title3.weight(.bold)).foregroundStyle(wOrange)
                if entry.hasData {
                    ForEach(topLevels(2), id: \.self) { p in
                        HStack(spacing: 5) {
                            Circle().fill(wOrange.opacity(0.55 + 0.45 * p.level))
                                .frame(width: 6, height: 6)
                            Text("\(p.name) \(Fatigue.label(p.level))")
                                .font(.caption2).foregroundStyle(wSub)
                        }
                    }
                } else {
                    Text("이번 주 운동 기록 없음").font(.caption2).foregroundStyle(wSub)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // 잠금화면 가로형
    private var rectView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("운동 피로도 \(entry.overall)%").font(.headline)
            if let top = topLevels(1).first, entry.hasData {
                Text("\(top.name) \(Fatigue.label(top.level)) · 상위 부위")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("이번 주 운동 기록 없음").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // 잠금화면 원형 게이지
    private var circularView: some View {
        Gauge(value: Double(entry.overall), in: 0...100) {
            Image(systemName: "dumbbell.fill")
        } currentValueLabel: {
            Text("\(entry.overall)")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var emptyText: some View {
        Text("이번 주 운동 기록이 없어요")
            .font(.caption2).foregroundStyle(wSub)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func topLevels(_ n: Int) -> [PartLevel] {
        entry.levels.sorted { $0.level > $1.level }.prefix(n).map { $0 }
    }
}
