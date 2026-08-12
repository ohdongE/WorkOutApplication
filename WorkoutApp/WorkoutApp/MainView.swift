import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: DataStore
    @State private var showPlanSheet = false
    @State private var editingPlan: WorkoutPlan?
    @State private var activePlan: WorkoutPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    recommendCard
                    startButton
                    plansSection
                }.padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .sheet(isPresented: $showPlanSheet) { planSheet.presentationDetents([.medium, .large]) }
            .sheet(item: $editingPlan) { PlanEditorView(plan: $0) }
            .fullScreenCover(item: $activePlan) { WorkoutSessionView(plan: $0) }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11:  "좋은 아침이에요 ☀️"
        case 11..<17: "오늘도 화이팅이에요 💪"
        case 17..<22: "오늘도 수고했어요 🌙"
        default:      "늦은 시간까지 고생이 많아요 🌛"
        }
    }
    private var subGreeting: String {
        let n = store.recentRecords(days: 7).count
        return n == 0 ? "이번 주 첫 운동을 시작해볼까요?" : "이번 주 \(n)번 운동했어요"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting).font(.title2.weight(.semibold)).foregroundStyle(Theme.orD)
                Text(subGreeting).font(.footnote).foregroundStyle(Theme.sub)
            }
            Spacer()
            Button { editingPlan = WorkoutPlan(name: "", exercises: []) } label: {
                Image(systemName: "plus")
                    .foregroundStyle(Theme.or)
                    .frame(width: 40, height: 40)
                    .background(Theme.orL, in: Circle())
                    .cardShadow()
            }
        }
    }

    // MARK: - 최근 7일 부위 분석 → 부족 부위 & 플랜 추천
    /// 최근 7일 자극이 부족한 부위(하위 2개)와, 그 부위를 커버하는 추천 플랜
    private var recommendation: (weak: [BodyPart], plan: WorkoutPlan?, hasRecords: Bool) {
        let levels = Fatigue.levels(store.records).sorted { $0.level < $1.level }
        let hasRecords = levels.contains { $0.level > 0 }
        let weak = Array(levels.prefix(2).map(\.part))
        let plan = store.plans
            .map { p -> (WorkoutPlan, Int) in
                let covered = Set(p.exercises.compactMap(\.bodyPart)).intersection(weak).count
                return (p, covered)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
        return (weak, plan, hasRecords)
    }

    private var recommendCard: some View {
        let rec = recommendation
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.footnote).foregroundStyle(Theme.or)
                Text("오늘의 추천").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
            }

            if !rec.hasRecords {
                Text("이번 주 아직 운동 전이에요.\n어느 부위든 가볍게 시작해볼까요?")
                    .font(.footnote).foregroundStyle(Theme.txt)
            } else {
                HStack(spacing: 6) {
                    Text("이번 주 부족한 부위").font(.footnote).foregroundStyle(Theme.txt)
                    ForEach(rec.weak, id: \.self) { part in
                        Text(part.rawValue)
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.or)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.orL, in: Capsule())
                    }
                }
            }

            if let plan = rec.plan {
                Button { activePlan = plan } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill").foregroundStyle(Theme.or)
                        Text("‘\(plan.name.isEmpty ? "이름 없는 플랜" : plan.name)’ 플랜으로 채워보세요")
                            .font(.footnote.weight(.medium)).foregroundStyle(Theme.txt)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.sub)
                    }
                    .padding(11)
                    .background(Theme.orL.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button { editingPlan = WorkoutPlan(name: "", exercises: []) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Theme.or)
                        Text("이 부위를 넣은 플랜을 만들어보세요")
                            .font(.footnote.weight(.medium)).foregroundStyle(Theme.txt)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.sub)
                    }
                    .padding(11)
                    .background(Theme.orL.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    private var startButton: some View {
        Button { showPlanSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("운동 시작").font(.title3.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(16)
            .background(
                LinearGradient(colors: [Theme.or, Theme.orD], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16))
            .cardShadow(true)
        }
    }

    private var planSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("플랜 선택").font(.headline).foregroundStyle(Theme.orD)

            // 일회용(빈) 플랜 — 세션 중에 운동을 즉석에서 추가. 저장은 안 되고 기록에만 남음.
            Button {
                showPlanSheet = false
                activePlan = WorkoutPlan(name: "빠른 운동", exercises: [])
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.or)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("빈 플랜으로 시작").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                        Text("운동을 즉석에서 추가하는 일회용 루틴").font(.caption).foregroundStyle(Theme.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.sub)
                }
                .padding(13)
                .background(Theme.orL, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
            }

            // 최근 운동 — 빈 플랜으로 했던 것 포함, 눌러서 그대로 다시 시작
            let recent = Array(store.records.sorted { $0.endedAt > $1.endedAt }.prefix(5))
            if !recent.isEmpty {
                Text("최근 운동").font(.caption.weight(.medium)).foregroundStyle(Theme.sub)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(recent) { rec in
                            Button {
                                showPlanSheet = false
                                activePlan = WorkoutPlan(name: rec.planName.isEmpty ? "빠른 운동" : rec.planName,
                                                         exercises: rec.exercises)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rec.planName.isEmpty ? "빠른 운동" : rec.planName)
                                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.orD).lineLimit(1)
                                    Text(rec.exercises.map(\.name).joined(separator: ", "))
                                        .font(.caption2).foregroundStyle(Theme.sub).lineLimit(1)
                                    Text("\(rec.endedAt, format: .dateTime.month().day()) · \(rec.exercises.count)개")
                                        .font(.caption2).foregroundStyle(Theme.sub)
                                }
                                .frame(width: 150, alignment: .leading)
                                .padding(11)
                                .background(Theme.orL.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))
                            }
                        }
                    }
                }.scrollIndicators(.hidden)
            }

            if !store.plans.isEmpty {
                Text("내 플랜").font(.caption.weight(.medium)).foregroundStyle(Theme.sub)
            }
            ScrollView {
                ForEach(store.plans) { p in
                    let empty = p.exercises.isEmpty
                    Button {
                        showPlanSheet = false; activePlan = p
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name.isEmpty ? "이름 없는 플랜" : p.name)
                                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                                Text(empty ? "운동을 추가해주세요"
                                           : p.exercises.map(\.name).joined(separator: ", "))
                                    .font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "play.fill").foregroundStyle(empty ? Theme.bd : Theme.or)
                        }
                        .padding(13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
                    }
                    .disabled(empty)
                }
            }.scrollIndicators(.hidden)
        }
        .padding(20)
        .presentationBackground(.white)
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내 플랜").font(.footnote.weight(.medium)).foregroundStyle(Theme.or)
            ForEach(store.plans) { p in
                Button { editingPlan = p } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(Theme.or)
                            .frame(width: 38, height: 38)
                            .background(Theme.orL, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name.isEmpty ? "이름 없는 플랜" : p.name)
                                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                            Text("\(p.exercises.count)개 운동").font(.caption).foregroundStyle(Theme.sub)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.or)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
                    .cardShadow()
                }
            }
        }
    }
}

// MARK: - 플랜 편집
struct PlanEditorView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var plan: WorkoutPlan
    @State private var showPicker = false
    @State private var reordering = false
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteExId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if reordering { reorderList } else { editorScroll }
            }
            .background(Theme.bg)
            .navigationTitle(reordering ? "순서 변경" : "플랜 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if reordering {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { reordering = false }.tint(Theme.or)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }.tint(Theme.or)
                    }
                    if store.plans.contains(where: { $0.id == plan.id }) {
                        ToolbarItem(placement: .destructiveAction) {
                            Button { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                            }.tint(Theme.or)
                        }
                    }
                }
            }
            .alert("플랜을 삭제할까요?", isPresented: $showDeleteConfirm) {
                Button("삭제", role: .destructive) { store.deletePlan(plan); dismiss() }
                Button("취소", role: .cancel) {}
            } message: { Text("이 플랜이 목록에서 제거됩니다.") }
            .confirmationDialog("이 운동을 뺄까요?",
                                isPresented: Binding(get: { pendingDeleteExId != nil },
                                                     set: { if !$0 { pendingDeleteExId = nil } }),
                                titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let id = pendingDeleteExId { plan.exercises.removeAll { $0.id == id } }
                    pendingDeleteExId = nil
                }
                Button("취소", role: .cancel) { pendingDeleteExId = nil }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { selected in
                    for ex in selected {
                        plan.exercises.append(.init(
                            exerciseID: ex.id, name: ex.koName, bodyPart: BodyPart.of(ex),
                            sets: PlannedSet.defaults(for: BodyPart.of(ex))
                        ))
                    }
                }
            }
        }
    }

    private var editorScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("플랜 이름", text: $plan.name,
                          prompt: Text("플랜 이름").foregroundStyle(Theme.sub))
                    .padding(11)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))

                ForEach($plan.exercises) { $pe in
                    exerciseCard($pe)
                }

                if plan.exercises.count > 1 {
                    Button { reordering = true } label: {
                        Label("운동 순서 변경", systemImage: "arrow.up.arrow.down")
                            .font(.footnote.weight(.medium)).foregroundStyle(Theme.or)
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                }

                Button { showPicker = true } label: {
                    Text("+ 운동 추가").font(.subheadline.weight(.medium)).foregroundStyle(Theme.or)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
                }

                Button {
                    if plan.name.isEmpty { plan.name = "새 플랜" }
                    if let i = store.plans.firstIndex(where: { $0.id == plan.id }) {
                        store.plans[i] = plan
                    } else { store.plans.append(plan) }
                    dismiss()
                } label: {
                    Text(plan.exercises.isEmpty ? "운동을 추가하세요" : "저장")
                        .font(.title3.weight(.medium)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(15)
                        .background(plan.exercises.isEmpty ? Theme.bd : Theme.or,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(plan.exercises.isEmpty)
            }.padding(20)
        }
        .scrollIndicators(.hidden)
        .keyboardDoneToolbar()
    }

    // 순서 변경 모드 — 오른쪽 핸들 드래그로 이동
    private var reorderList: some View {
        List {
            ForEach(plan.exercises) { pe in
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill").font(.caption).foregroundStyle(Theme.or)
                    Text(pe.name).font(.subheadline).foregroundStyle(Theme.txt)
                }
            }
            .onMove { plan.exercises.move(fromOffsets: $0, toOffset: $1) }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
    }

    private func exerciseCard(_ pe: Binding<PlannedExercise>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pe.wrappedValue.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                Spacer()
                Button {
                    pendingDeleteExId = pe.wrappedValue.id
                } label: { Image(systemName: "trash").font(.footnote).foregroundStyle(Theme.or) }
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

    // 유산소 시간(초 저장) → 분/초 편집 바인딩
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

struct SetField: View {
    var value: Binding<Double>?
    var reps: Binding<Int>?
    let suffix: String
    var body: some View {
        HStack(spacing: 3) {
            Group {
                if let v = value {
                    TextField("", value: v, format: .number).keyboardType(.decimalPad).frame(width: 52)
                } else if let r = reps {
                    TextField("", value: r, format: .number).keyboardType(.numberPad).frame(width: 40)
                }
            }
            .font(.footnote).foregroundStyle(Theme.txt)
            .padding(5)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.bd, lineWidth: 1))
            Text(suffix).font(.caption).foregroundStyle(Theme.sub)
        }
    }
}
