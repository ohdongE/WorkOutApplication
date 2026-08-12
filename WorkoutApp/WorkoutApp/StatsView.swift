import SwiftUI
import Charts

fileprivate struct WeekStat: Identifiable {
    let id = UUID(); let label: String; let volume: Double; let count: Int
}

enum BalancePeriod: String, CaseIterable, Identifiable {
    case week = "1주", month = "1개월", all = "전체"
    var id: String { rawValue }
    var days: Int? { switch self { case .week: 7; case .month: 30; case .all: nil } }
}

struct StatsView: View {
    @EnvironmentObject var store: DataStore
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var selDate = Calendar.current.startOfDay(for: .now)
    @State private var balancePeriod: BalancePeriod = .week
    @State private var trendVolume = true
    @State private var showAddRecord = false

    private var dayRecs: [WorkoutRecord] { store.records(on: selDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("운동 리포트").font(.title.weight(.semibold)).foregroundStyle(Theme.orD)
                    streakCard
                    fatigueCard
                    trendCard
                    balanceCard
                    calendarCard
                    metricRow
                    dayDetail
                }.padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .sheet(isPresented: $showAddRecord) {
                ManualRecordView(date: selDate)
            }
        }
    }

    // MARK: 연속 기록 / 요약
    private var streakCard: some View {
        HStack(spacing: 8) {
            streakStat("flame", "\(currentStreak())일", "연속")
            streakStat("calendar", "\(thisMonthCount())회", "이번 달")
            streakStat("dumbbell", "\(store.records.count)회", "전체")
        }
    }
    private func streakStat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.body.weight(.medium)).foregroundStyle(Theme.or)
                .frame(height: 22)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Theme.orD)
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }
    private func currentStreak() -> Int {
        let cal = Calendar.current
        let days = Set(store.records.map { cal.startOfDay(for: $0.endedAt) })
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) {                                  // 오늘 안 했으면 어제부터 인정
            guard let y = cal.date(byAdding: .day, value: -1, to: day), days.contains(y) else { return 0 }
            day = y
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
    private func thisMonthCount() -> Int {
        let iv = Calendar.current.dateInterval(of: .month, for: .now)!
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        return store.records.filter { iv.contains($0.endedAt) && $0.endedAt < tomorrow }.count
    }

    // MARK: 부위별 피로도 (인체 그림 + 세부부위 상세)
    private var fatigueCard: some View {
        let regions = Fatigue.regionLevels(store.records)
        // 세부부위 상세 칩: 세부 항목(가슴·상부 등) + 세부 구분 없는 부위(이두·삼두)
        let details = regions
            .filter { $0.key.part != .cardio && $0.value >= 0.15 &&
                      ($0.key.sub != nil || $0.key.part.subRegions.isEmpty) }
            .sorted { $0.value > $1.value }
            .prefix(6)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("부위별 피로도").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                Spacer()
                Text("진할수록 피로 · 연하면 회복됨").font(.caption2).foregroundStyle(Theme.sub)
            }
            BodyFatigueView(levels: regions)
            if !details.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                    ForEach(Array(details), id: \.key) { region, level in
                        HStack(spacing: 5) {
                            Circle().fill(BodyFatigueView.heat(level)).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(region.label).font(.caption2).foregroundStyle(Theme.txt)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text("\(Int((level * 100).rounded()))% · \(Fatigue.label(level))")
                                    .font(.system(size: 9)).foregroundStyle(Theme.sub)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, 6)
                        .background(Theme.orL.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: 주간 볼륨·횟수 통계
    private var trendCard: some View {
        let weeks = weeklyStats()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("주간 통계").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                Spacer()
                Picker("", selection: $trendVolume) {
                    Text("볼륨").tag(true); Text("횟수").tag(false)
                }.pickerStyle(.segmented).frame(width: 120)
            }
            Chart(weeks) { w in
                BarMark(x: .value("주", w.label),
                        y: .value(trendVolume ? "볼륨" : "횟수", trendVolume ? w.volume : Double(w.count)))
                    .foregroundStyle(Theme.or).cornerRadius(4)
            }
            .chartXAxis { AxisMarks { _ in
                AxisValueLabel().font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
            } }
            .chartYAxis { AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.bd)
                AxisValueLabel().font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
            } }
            .frame(height: 150)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }
    private func weeklyStats() -> [WeekStat] {
        let cal = Calendar.current
        let thisStart = cal.dateInterval(of: .weekOfYear, for: .now)!.start
        return (0...7).reversed().map { w in
            let start = cal.date(byAdding: .weekOfYear, value: -w, to: thisStart)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let recs = store.records.filter { $0.endedAt >= start && $0.endedAt < end }
            return WeekStat(label: start.formatted(.dateTime.month(.defaultDigits).day()),
                            volume: recs.reduce(0) { $0 + $1.totalVolume },
                            count: recs.count)
        }
    }

    // MARK: 부위 밸런스 (기간: 1주 / 1개월 / 전체)
    private let balanceOrder: [BodyPart] = [.chest, .shoulder, .triceps, .biceps, .back, .lower, .cardio]
    private func balanceData() -> [(label: String, value: Double)] {
        let cutoff = balancePeriod.days.map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        var load: [BodyPart: Double] = [:]
        for r in store.records {
            if r.endedAt >= tomorrow { continue }                 // 미래 날짜 기록 제외
            if let c = cutoff, r.endedAt < c { continue }
            for e in r.exercises where e.bodyPart != nil { load[e.bodyPart!, default: 0] += Double(e.sets.count) }
        }
        let maxLoad = load.values.max() ?? 0
        return balanceOrder.map { (label: $0.rawValue, value: maxLoad > 0 ? (load[$0] ?? 0) / maxLoad : 0) }
    }
    private var balanceCard: some View {
        let data = balanceData()
        let hasData = data.contains { $0.value > 0 }
        let cutoff = balancePeriod.days.map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let periodRecs = store.records.filter { $0.endedAt < tomorrow && (cutoff == nil || $0.endedAt >= cutoff!) }
        let periodSets = periodRecs.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("부위 밸런스").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                Spacer()
                Picker("", selection: $balancePeriod) {
                    ForEach(BalancePeriod.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 170)
            }
            if hasData {
                Text("이 기간 운동 \(periodRecs.count)회 · \(periodSets)세트 · 가장 많이 한 부위 대비 %")
                    .font(.caption2).foregroundStyle(Theme.sub)
            }
            if hasData {
                RadarChart(data: data).frame(height: 250)
            } else {
                Text("이 기간엔 운동 기록이 없어요.")
                    .multilineTextAlignment(.center)
                    .font(.footnote).foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: 달력
    private var calendarCard: some View {
        let cal = Calendar.current
        let days = cal.range(of: .day, in: .month, for: month)!.count
        let firstWeekday = cal.component(.weekday, from: month) - 1
        let recordDays: Set<Date> = Set(store.records.map { cal.startOfDay(for: $0.endedAt) })

        return VStack(spacing: 8) {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Theme.or)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(String(cal.component(.year, from: month)))년")
                        .font(.caption2).foregroundStyle(Theme.sub)
                    Text("\(cal.component(.month, from: month))월")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                }
                Spacer()
                Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.or)
                }
            }
            let cols = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(["일","월","화","수","목","금","토"], id: \.self) {
                    Text($0).font(.caption2).foregroundStyle(Theme.sub)
                }
                ForEach(0..<firstWeekday, id: \.self) { _ in Text("") }
                ForEach(1...days, id: \.self) { d in
                    let date = cal.date(byAdding: .day, value: d - 1, to: month)!
                    let has = recordDays.contains(date)
                    let on = cal.isDate(date, inSameDayAs: selDate)
                    Button { selDate = date } label: {
                        VStack(spacing: 2) {
                            Text("\(d)").font(.footnote.weight(has ? .medium : .regular))
                                .foregroundStyle(on ? .white : Theme.txt)
                            Circle().fill(has && !on ? Theme.or : .clear).frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .background(on ? Theme.or : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: 선택 날짜 지표
    private var metricRow: some View {
        let vol = dayRecs.reduce(0) { $0 + $1.totalVolume }
        let min = Int(dayRecs.reduce(0) { $0 + $1.duration } / 60)
        let cal = dayRecs.reduce(0) { $0 + $1.calories }
        return HStack(spacing: 8) {
            metric("총 무게", "\(Int(vol))kg")
            metric("칼로리", "\(Int(cal))kcal")
            metric("시간", "\(min)분")
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.or)
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: 일별 상세
    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selDate, format: .dateTime.month().day()) 운동 기록")
                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.or)
                Spacer()
                // 미래 날짜엔 수동 기록 추가 불가 (통계 왜곡 방지)
                if selDate <= Calendar.current.startOfDay(for: .now) {
                    Button { showAddRecord = true } label: {
                        Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(Theme.or)
                            .frame(width: 28, height: 28).background(Theme.orL, in: Circle())
                    }
                }
            }
            if dayRecs.isEmpty {
                Text("이 날 운동 기록이 없어요.").font(.footnote).foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            ForEach(dayRecs) { r in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(r.planName).font(.subheadline.weight(.medium)).foregroundStyle(Theme.orD)
                        Spacer()
                        Text("\(Int(r.duration/60))분").font(.caption).foregroundStyle(Theme.sub)
                        Button { store.deleteRecord(r) } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Theme.sub)
                        }
                    }
                    ForEach(r.exercises) { e in
                        let cardio = e.bodyPart == .cardio
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name).font(.footnote.weight(.medium)).foregroundStyle(Theme.txt)
                            Text(e.sets.map { $0.summary(cardio: cardio) }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Theme.sub)
                        }
                    }
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
                .cardShadow()
            }
        }
    }
}

// MARK: - 수동 운동 기록 추가 (리포트에서 선택 날짜에 직접 기록)
struct ManualRecordView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let date: Date

    @State private var name = ""
    @State private var minutes = 60
    @State private var exercises: [PlannedExercise] = []
    @State private var showPicker = false
    @State private var pendingDeleteExId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("기록 이름", text: $name,
                              prompt: Text("기록 이름 (예: 가슴/삼두)").foregroundStyle(Theme.sub))
                        .font(.subheadline).foregroundStyle(Theme.dark)
                        .padding(11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))

                    HStack {
                        Text("운동 시간").font(.subheadline).foregroundStyle(Theme.txt)
                        Spacer()
                        SetField(reps: $minutes, suffix: "분")
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))

                    ForEach($exercises) { $pe in exerciseCard($pe) }

                    Button { showPicker = true } label: {
                        Text("+ 운동 추가").font(.subheadline.weight(.medium)).foregroundStyle(Theme.or)
                            .frame(maxWidth: .infinity).padding(12)
                            .background(Theme.orL, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }

                    Button { save() } label: {
                        Text(exercises.isEmpty ? "운동을 추가하세요" : "기록 저장")
                            .font(.title3.weight(.medium)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(15)
                            .background(exercises.isEmpty ? Theme.bd : Theme.or,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(exercises.isEmpty)
                }.padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .navigationTitle(Text("\(date, format: .dateTime.month().day()) 기록 추가"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("취소") { dismiss() }.tint(Theme.or) }
            .keyboardDoneToolbar()
            .confirmationDialog("이 운동을 삭제할까요?",
                isPresented: Binding(get: { pendingDeleteExId != nil },
                                     set: { if !$0 { pendingDeleteExId = nil } }),
                titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let id = pendingDeleteExId { exercises.removeAll { $0.id == id } }
                    pendingDeleteExId = nil
                }
                Button("취소", role: .cancel) { pendingDeleteExId = nil }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { selected in
                    for ex in selected {
                        exercises.append(.init(
                            exerciseID: ex.id, name: ex.koName, bodyPart: BodyPart.of(ex),
                            sets: PlannedSet.defaults(for: BodyPart.of(ex))))
                    }
                }
            }
        }
    }

    private func save() {
        let start = Calendar.current.startOfDay(for: date).addingTimeInterval(9 * 3600)  // 그날 오전 9시 기준
        let end = start.addingTimeInterval(Double(max(1, minutes)) * 60)
        let rec = WorkoutRecord(planName: name.isEmpty ? "운동 기록" : name,
                                startedAt: start, endedAt: end, exercises: exercises)
        store.records.append(rec)
        dismiss()
    }

    // 운동 카드 (PlanEditorView와 동일한 세트 편집 패턴)
    private func exerciseCard(_ pe: Binding<PlannedExercise>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pe.wrappedValue.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                Spacer()
                Button { pendingDeleteExId = pe.wrappedValue.id } label: {
                    Image(systemName: "trash").font(.footnote).foregroundStyle(Theme.or)
                }
            }
            let cardio = pe.wrappedValue.bodyPart == .cardio
            ForEach(pe.sets) { $s in
                HStack(spacing: 6) {
                    Text("\((pe.wrappedValue.sets.firstIndex(where: { $0.id == s.id }) ?? 0) + 1)\(cardio ? "회차" : "세트")")
                        .font(.caption).foregroundStyle(Theme.sub).frame(width: 38, alignment: .leading)
                    if cardio {
                        SetField(reps: durMinBinding($s), suffix: "분")
                        SetField(reps: durSecBinding($s), suffix: "초")
                        SetField(value: distBinding($s), suffix: "km")
                    } else {
                        SetField(value: $s.weight, suffix: "kg")
                        SetField(reps: $s.reps, suffix: "회")
                    }
                    Button {
                        if pe.wrappedValue.sets.count > 1 {
                            pe.wrappedValue.sets.removeAll { $0.id == s.id }
                        }
                    } label: {
                        Image(systemName: "xmark").font(.caption2).foregroundStyle(Theme.bd)
                    }
                    .disabled(pe.wrappedValue.sets.count <= 1)
                }
            }
            Button(cardio ? "+ 회차 추가" : "+ 세트 추가") {
                let last = pe.wrappedValue.sets.last
                pe.wrappedValue.sets.append(cardio
                    ? PlannedSet(weight: 0, reps: 0, duration: last?.duration ?? 600, distance: last?.distance ?? 1.0)
                    : PlannedSet(weight: last?.weight ?? 20, reps: last?.reps ?? 8))
            }.font(.caption).tint(Theme.or)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
    }

    private func durMinBinding(_ s: Binding<PlannedSet>) -> Binding<Int> {
        Binding(get: { (s.wrappedValue.duration ?? 0) / 60 },
                set: { v in s.wrappedValue.duration = max(0, v) * 60 + (s.wrappedValue.duration ?? 0) % 60 })
    }
    private func durSecBinding(_ s: Binding<PlannedSet>) -> Binding<Int> {
        Binding(get: { (s.wrappedValue.duration ?? 0) % 60 },
                set: { v in s.wrappedValue.duration = (s.wrappedValue.duration ?? 0) / 60 * 60 + min(59, max(0, v)) })
    }
    private func distBinding(_ s: Binding<PlannedSet>) -> Binding<Double> {
        Binding(get: { s.wrappedValue.distance ?? 0 }, set: { s.wrappedValue.distance = $0 })
    }
}
