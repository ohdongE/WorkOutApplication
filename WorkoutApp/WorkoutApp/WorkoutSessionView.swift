import SwiftUI

struct WorkoutSessionView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var plan: WorkoutPlan

    @State private var exIndex = 0
    @State private var done: [Int] = []                 // 운동별 완료 세트 수
    @State private var startedAt = Date()
    @State private var elapsed = 0
    @State private var showPicker = false
    @State private var finishedRecord: WorkoutRecord?   // 종료 결과창
    @State private var restRemaining: Int?              // 휴식 남은 초 (nil=휴식 아님)
    @State private var restEndTick = 0                  // 휴식 종료 햅틱 트리거
    @State private var showCloseConfirm = false         // 종료 확인
    @State private var pendingDeleteEx: Int?            // 삭제 확인할 운동 인덱스
    @State private var showReorder = false              // 운동 순서 변경 시트
    private let restDefault = 90                         // 기본 휴식 시간(초)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: PlannedExercise { plan.exercises[exIndex] }
    private func doneCount(_ i: Int) -> Int { i < done.count ? done[i] : 0 }
    private var allDone: Bool { doneCount(exIndex) >= current.sets.count }
    private var allExercisesDone: Bool {
        !plan.exercises.isEmpty &&
        plan.exercises.indices.allSatisfy { doneCount($0) >= plan.exercises[$0].sets.count }
    }
    private var currentExercise: Exercise? { store.exercises.first { $0.id == current.exerciseID } }
    private var isCardio: Bool { current.bodyPart == .cardio }
    /// 이 운동의 가장 최근 지난 기록 (없으면 nil)
    private var lastPerformance: PlannedExercise? {
        for r in store.records.sorted(by: { $0.endedAt > $1.endedAt }) {
            if let pe = r.exercises.first(where: { $0.exerciseID == current.exerciseID }) { return pe }
        }
        return nil
    }

    var body: some View {
        ZStack {
            content
            if let rec = finishedRecord {
                WorkoutResultView(record: rec) { dismiss() }   // 확인 → 세션 종료
                    .transition(.opacity)
            }
        }
        .onReceive(timer) { _ in
            elapsed = Int(Date().timeIntervalSince(startedAt))
            if let r = restRemaining {
                if r <= 1 { restRemaining = nil; restEndTick += 1 }   // 휴식 끝 → 햅틱
                else { restRemaining = r - 1 }
            }
        }
        .sensoryFeedback(.success, trigger: restEndTick)              // 휴식 종료 진동
        .onAppear {
            ensureDoneSize()
            if !plan.exercises.isEmpty { startActivity() }
        }
        .sheet(isPresented: $showPicker) { ExercisePickerView { addExercises($0) } }
        .sheet(isPresented: $showReorder) { reorderSheet }
    }

    private var content: some View {
        Group {
            if plan.exercises.isEmpty { emptyState } else { sessionBody }
        }
        .padding(20)
        .background(Theme.bg)
        .keyboardDoneToolbar()
        .alert("운동을 종료할까요?", isPresented: $showCloseConfirm) {
            Button("종료", role: .destructive) { close() }
            Button("취소", role: .cancel) {}
        } message: { Text("나가면 운동 기록이 저장되지 않습니다.") }
        .confirmationDialog("이 운동을 삭제할까요?",
                            isPresented: Binding(get: { pendingDeleteEx != nil },
                                                 set: { if !$0 { pendingDeleteEx = nil } }),
                            titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let i = pendingDeleteEx { deleteExercise(i) }; pendingDeleteEx = nil
            }
            Button("취소", role: .cancel) { pendingDeleteEx = nil }
        }
    }

    private func ensureDoneSize() { while done.count < plan.exercises.count { done.append(0) } }

    /// 세션 중 운동 추가. 원본 플랜엔 반영되지 않고 기록에만 남음.
    private func addExercises(_ selected: [Exercise]) {
        let wasEmpty = plan.exercises.isEmpty
        for ex in selected {
            plan.exercises.append(.init(
                exerciseID: ex.id, name: ex.koName, bodyPart: BodyPart.of(ex),
                sets: PlannedSet.defaults(for: BodyPart.of(ex))))
            done.append(0)
        }
        if wasEmpty { startActivity() } else { syncActivity() }
    }

    // MARK: - Live Activity
    private var setProgress: String { "\(doneCount(exIndex))/\(current.sets.count)" }
    private var exProgress: String { "\(exIndex + 1)/\(plan.exercises.count)" }
    private func startActivity() {
        if #available(iOS 16.2, *) {
            WorkoutActivityController.start(planName: plan.name, exercise: current.name,
                setProgress: setProgress, exProgress: exProgress, startedAt: startedAt)
        }
    }
    private func syncActivity() {
        if #available(iOS 16.2, *) {
            WorkoutActivityController.update(exercise: current.name,
                setProgress: setProgress, exProgress: exProgress, startedAt: startedAt)
        }
    }
    private func endActivity() { if #available(iOS 16.2, *) { WorkoutActivityController.end() } }
    private func close() { endActivity(); dismiss() }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "plus.circle").font(.largeTitle).foregroundStyle(Theme.or)
            Text("빈 플랜이에요.\n원하는 운동을 추가해 시작하세요.")
                .multilineTextAlignment(.center).font(.subheadline).foregroundStyle(Theme.sub)
            Button { showPicker = true } label: {
                Text("운동 추가").font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Theme.or, in: Capsule()).cardShadow()
            }
            Button("닫기") { close() }.font(.footnote).tint(Theme.sub)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionBody: some View {
        VStack(spacing: 12) {
            header
            navigatorRow
            Text(current.name).font(.title3.weight(.medium)).foregroundStyle(Theme.orD)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let last = lastPerformance {
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.caption2).foregroundStyle(Theme.sub)
                    Text("지난 기록  " + last.sets.map { $0.summary(cardio: isCardio) }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView {
                VStack(spacing: 8) {
                    if let ex = currentExercise { ExerciseMotionView(exercise: ex, height: 170) }
                    ForEach(Array(plan.exercises[exIndex].sets.enumerated()), id: \.element.id) { j, _ in
                        setRow(j)
                    }
                    addSetButton
                    aiTip
                    addExerciseButton
                }
            }.scrollIndicators(.hidden)
            if restRemaining != nil { restBar }
            mainButton
            if !allExercisesDone { earlyEndButton }
        }
    }

    // 남은 게 있어도 종료 — 완료한 세트/운동만 기록에 포함
    private var earlyEndButton: some View {
        Button { finishEarly() } label: {
            Text("운동 종료").font(.subheadline.weight(.medium)).foregroundStyle(Theme.or)
                .frame(maxWidth: .infinity).padding(10)
                .background(Theme.orL, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private func finishEarly() {
        var exs: [PlannedExercise] = []
        for (i, ex) in plan.exercises.enumerated() {
            let d = doneCount(i)
            guard d > 0 else { continue }               // 완료 세트 없는 운동은 제외
            var e = ex
            e.sets = Array(ex.sets.prefix(d))            // 완료한 세트만
            exs.append(e)
        }
        endActivity()
        guard !exs.isEmpty else { dismiss(); return }   // 완료한 게 전혀 없으면 기록 없이 종료
        let rec = WorkoutRecord(planName: plan.name, startedAt: startedAt, endedAt: .now, exercises: exs)
        store.records.append(rec)
        withAnimation { finishedRecord = rec }
    }
    private func deleteSet(_ j: Int) {
        guard plan.exercises[exIndex].sets.count > 1 else { return }
        plan.exercises[exIndex].sets.remove(at: j)
        if doneCount(exIndex) > plan.exercises[exIndex].sets.count {
            done[exIndex] = plan.exercises[exIndex].sets.count
        }
        syncActivity()
    }

    // 휴식 타이머 — 컴팩트 한 줄. 남은 시간 + ±10초 + 종료
    private var restBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer").font(.footnote).foregroundStyle(Theme.or)
            Text(String(format: "%d:%02d", (restRemaining ?? 0) / 60, (restRemaining ?? 0) % 60))
                .font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Theme.orD)
                .frame(minWidth: 50, alignment: .leading)
            Spacer()
            restAdjust("−10", -10)
            restAdjust("+10", 10)
            Button { restRemaining = nil } label: {
                Text("종료").font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 32).background(Theme.or, in: Capsule())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.or.opacity(0.5), lineWidth: 1))
        .cardShadow()
    }
    private func restAdjust(_ title: String, _ delta: Int) -> some View {
        Button { restRemaining = max(0, (restRemaining ?? 0) + delta) } label: {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.or)
                .frame(width: 42, height: 32).background(Theme.orL, in: Capsule())
        }
    }

    // 운동 목록 + 순서 변경 버튼 (2개 이상일 때만 노출)
    private var navigatorRow: some View {
        HStack(spacing: 8) {
            navigator
            if plan.exercises.count > 1 {
                Button { showReorder = true } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.or)
                        .frame(width: 34, height: 34)
                        .background(Theme.orL, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.bd, lineWidth: 1))
                }
            }
        }
    }

    // 세션 중 순서 변경 — 이 진행에만 적용(원본 플랜엔 영향 없음)
    private var reorderSheet: some View {
        NavigationStack {
            List {
                ForEach(plan.exercises) { pe in
                    let full = doneCount(plan.exercises.firstIndex(where: { $0.id == pe.id }) ?? 0) >= pe.sets.count
                    HStack(spacing: 10) {
                        Image(systemName: full ? "checkmark.circle.fill" : "dumbbell.fill")
                            .font(.caption).foregroundStyle(Theme.or)
                        Text(pe.name).font(.subheadline)
                            .foregroundStyle(pe.id == current.id ? Theme.orD : Theme.txt)
                        if pe.id == current.id {
                            Text("진행 중").font(.caption2.weight(.semibold)).foregroundStyle(Theme.or)
                        }
                    }
                }
                .onMove { moveExercises(from: $0, to: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("운동 순서 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("완료") { showReorder = false }.tint(Theme.or) }
        }
    }

    // 순서 이동: plan/done 함께 재정렬, 진행 중이던 운동 위치는 그대로 따라가게 유지
    private func moveExercises(from source: IndexSet, to dest: Int) {
        let currentID = current.id
        plan.exercises.move(fromOffsets: source, toOffset: dest)
        done.move(fromOffsets: source, toOffset: dest)
        if let idx = plan.exercises.firstIndex(where: { $0.id == currentID }) { exIndex = idx }
        syncActivity()
    }

    // 상단 운동 목록 — 눌러 이동(완료 운동 재진행·수정), x로 삭제
    private var navigator: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(plan.exercises.indices, id: \.self) { i in
                    let full = doneCount(i) >= plan.exercises[i].sets.count
                    let cur = i == exIndex
                    HStack(spacing: 6) {
                        Button { exIndex = i; syncActivity() } label: {
                            HStack(spacing: 4) {
                                if full { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                                Text(shortName(plan.exercises[i].name)).font(.footnote)
                            }
                        }.buttonStyle(.plain)
                        Button { pendingDeleteEx = i } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(cur ? .white.opacity(0.85) : Theme.sub)
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(cur ? Theme.or : (full ? Theme.orL : .white), in: Capsule())
                    .foregroundStyle(cur ? .white : Theme.txt)
                    .overlay(Capsule().strokeBorder(cur ? Theme.or : Theme.bd, lineWidth: 1))
                }
            }
        }.scrollIndicators(.hidden)
    }
    private func shortName(_ s: String) -> String { s.count > 9 ? String(s.prefix(8)) + "…" : s }

    private func deleteExercise(_ i: Int) {
        plan.exercises.remove(at: i)
        if i < done.count { done.remove(at: i) }
        guard !plan.exercises.isEmpty else { exIndex = 0; endActivity(); return }
        if exIndex >= plan.exercises.count { exIndex = plan.exercises.count - 1 }
        else if exIndex > i { exIndex -= 1 }
        syncActivity()
    }

    private var header: some View {
        HStack {
            Button { showCloseConfirm = true } label: { Image(systemName: "xmark").foregroundStyle(Theme.or) }
            Spacer()
            Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60))
                .font(.headline.monospacedDigit()).foregroundStyle(Theme.orD)
            Spacer()
            Text("\(exIndex + 1) / \(plan.exercises.count)").font(.footnote).foregroundStyle(Theme.sub)
        }
    }

    // 세트 행: 무게/횟수는 언제나 편집 가능, 완료 세트는 체크·강조 표시
    private func setRow(_ j: Int) -> some View {
        let isDone = j < doneCount(exIndex)
        let active = j == doneCount(exIndex)
        return HStack {
            HStack(spacing: 4) {
                Text("\(j + 1)\(isCardio ? "회차" : "세트")").font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                if isDone { Image(systemName: "checkmark").font(.caption).foregroundStyle(Theme.or) }
            }
            Spacer()
            if isCardio {
                cardioFields(j)
            } else {
                HStack(spacing: 4) {
                    SetField(value: $plan.exercises[exIndex].sets[j].weight, suffix: "kg")
                    SetField(reps: $plan.exercises[exIndex].sets[j].reps, suffix: "회")
                }
            }
            if plan.exercises[exIndex].sets.count > 1 {
                Button { deleteSet(j) } label: {
                    Image(systemName: "xmark").font(.caption2).foregroundStyle(Theme.bd)
                }.padding(.leading, 2)
            }
        }
        .padding(13)
        .background(isDone ? Theme.orL : .white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(active ? Theme.or : Theme.bd, lineWidth: active ? 2 : 1))
    }

    // 유산소 입력: 분 · 초 · km
    private func cardioFields(_ j: Int) -> some View {
        let minB = Binding<Int>(
            get: { (plan.exercises[exIndex].sets[j].duration ?? 0) / 60 },
            set: { v in
                let sec = (plan.exercises[exIndex].sets[j].duration ?? 0) % 60
                plan.exercises[exIndex].sets[j].duration = max(0, v) * 60 + sec })
        let secB = Binding<Int>(
            get: { (plan.exercises[exIndex].sets[j].duration ?? 0) % 60 },
            set: { v in
                let m = (plan.exercises[exIndex].sets[j].duration ?? 0) / 60
                plan.exercises[exIndex].sets[j].duration = m * 60 + min(59, max(0, v)) })
        let kmB = Binding<Double>(
            get: { plan.exercises[exIndex].sets[j].distance ?? 0 },
            set: { plan.exercises[exIndex].sets[j].distance = $0 })
        return HStack(spacing: 4) {
            SetField(reps: minB, suffix: "분")
            SetField(reps: secB, suffix: "초")
            SetField(value: kmB, suffix: "km")
        }
    }

    private var addSetButton: some View {
        Button {
            let last = plan.exercises[exIndex].sets.last
            if isCardio {
                plan.exercises[exIndex].sets.append(
                    PlannedSet(weight: 0, reps: 0, duration: last?.duration ?? 600, distance: last?.distance ?? 1.0))
            } else {
                plan.exercises[exIndex].sets.append(
                    PlannedSet(weight: last?.weight ?? 20, reps: last?.reps ?? 8))
            }
            syncActivity()
        } label: {
            Text(isCardio ? "+ 회차 추가" : "+ 세트 추가").font(.footnote).foregroundStyle(Theme.or)
                .frame(maxWidth: .infinity).padding(9)
                .background(Theme.orL, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
    }

    private var addExerciseButton: some View {
        Button { showPicker = true } label: {
            Text("+ 운동 추가").font(.footnote.weight(.medium)).foregroundStyle(Theme.or)
                .frame(maxWidth: .infinity).padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
    }

    private var aiTip: some View {
        let a = AICoach.advice(for: current)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Theme.or)
                Text("AI 코치").font(.caption.weight(.semibold)).foregroundStyle(Theme.or)
            }
            Text(a.summary).font(.footnote.weight(.medium)).foregroundStyle(Theme.txt)
            if let v = a.variation {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "target").font(.caption2).foregroundStyle(Theme.orD).padding(.top, 2)
                    Text(v).font(.caption).foregroundStyle(Theme.txt)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }
            adviceGroup("핵심 자세", a.formCues, icon: "checkmark", tint: Theme.or)
            adviceGroup("흔한 실수", a.mistakes, icon: "xmark", tint: Color(red: 0.85, green: 0.4, blue: 0.3))
            HStack(alignment: .top, spacing: 8) {
                metaPill("템포", a.tempo)
                metaPill("휴식", a.rest)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 14))
    }

    private func adviceGroup(_ title: String, _ items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.sub)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon).font(.caption2).foregroundStyle(tint).padding(.top, 2)
                    Text(item).font(.footnote).foregroundStyle(Theme.txt)
                }
            }
        }
    }

    private func metaPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.or)
            Text(value).font(.caption2).foregroundStyle(Theme.txt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }

    private var mainButton: some View {
        Button {
            if !allDone {
                ensureDoneSize(); done[exIndex] += 1; syncActivity()
                restRemaining = restDefault           // 세트 완료 → 휴식 타이머 시작
            } else if allExercisesDone {
                finish()
            } else {
                goNext(); syncActivity()
            }
        } label: {
            Text(!allDone ? "세트 완료" : (allExercisesDone ? "운동 종료" : "다음 운동"))
                .font(.title3.weight(.medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(15)
                .background(allDone && allExercisesDone ? Theme.orD : Theme.or,
                            in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func goNext() {
        let n = plan.exercises.count
        for off in 1...n {
            let i = (exIndex + off) % n
            if doneCount(i) < plan.exercises[i].sets.count { exIndex = i; return }
        }
        exIndex = (exIndex + 1) % n
    }

    private func finish() {
        let rec = WorkoutRecord(planName: plan.name, startedAt: startedAt, endedAt: .now,
                                exercises: plan.exercises)
        store.records.append(rec)     // 저장 (didSet → 위젯 갱신)
        endActivity()
        withAnimation { finishedRecord = rec }
    }
}

// MARK: - 운동 종료 결과창
struct WorkoutResultView: View {
    let record: WorkoutRecord
    var onClose: () -> Void

    /// 세부부위별 자극량 (주동근 + 협응근 가중 환산 세트) — 예: 벤치 5세트 → 가슴·중부 5 / 삼두 2.5 / 어깨·전면 1.5
    private var partSets: [(part: String, sets: Double)] {
        var d: [MuscleRegion: Double] = [:]
        for e in record.exercises {
            let sets = Double(e.sets.count)
            for (region, f) in MuscleMap.stimuli(for: e) {
                d[region, default: 0] += sets * f
            }
        }
        return d.sorted { $0.value > $1.value }.prefix(7)
            .map { (part: $0.key.label, sets: $0.value) }
    }

    var body: some View {
        let mins = Int(record.duration) / 60
        let secs = Int(record.duration) % 60
        let maxSets = partSets.map(\.sets).max() ?? 1

        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.or)
            Text("운동 완료!").font(.title.weight(.bold)).foregroundStyle(Theme.orD)
            Text(record.planName.isEmpty ? "빠른 운동" : record.planName)
                .font(.subheadline).foregroundStyle(Theme.sub)

            HStack(spacing: 10) {
                metric("시간", secs > 0 ? "\(mins)분 \(secs)초" : "\(mins)분")
                metric("칼로리", "\(Int(record.calories))kcal")
                metric("볼륨", "\(Int(record.totalVolume))kg")
            }.padding(.horizontal, 20)

            if !partSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("근육 피로도").font(.footnote.weight(.semibold)).foregroundStyle(Theme.or)
                    ForEach(partSets, id: \.part) { row in
                        HStack(spacing: 8) {
                            Text(row.part).font(.caption).foregroundStyle(Theme.txt)
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .frame(width: 64, alignment: .leading)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.orL)
                                    Capsule().fill(Theme.or)
                                        .frame(width: max(6, g.size.width * CGFloat(row.sets / maxSets)))
                                }
                            }.frame(height: 8)
                            Text("\(Int(row.sets.rounded()))세트").font(.caption2).foregroundStyle(Theme.sub)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
                .padding(.horizontal, 20)
            }
            Spacer()
            Button { onClose() } label: {
                Text("확인").font(.title3.weight(.medium)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(15)
                    .background(Theme.or, in: RoundedRectangle(cornerRadius: 14))
            }.padding(.horizontal, 20).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.or)
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
    }
}
