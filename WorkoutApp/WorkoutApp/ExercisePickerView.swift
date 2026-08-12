import SwiftUI
import UIKit
import ImageIO
import Charts

/// 운동 목록 소스: 기본(전체) / 최근 운동(2주) / 즐겨찾기
enum ExerciseSource: String, CaseIterable {
    case all = "기본", recent = "최근 운동", favorite = "즐겨찾기"
}

struct ExercisePickerView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var onDone: ([Exercise]) -> Void

    @State private var source: ExerciseSource = .all
    @State private var part: BodyPart?
    @State private var sub: String?            // 세부부위(중분류)
    @State private var equip: EquipmentType?
    @State private var selected: Set<String> = []
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                searchBar
                sourceChips
                chips("부위", BodyPart.allCases, $part) { $0.rawValue }
                // 세부부위: 대분류에 따라 있었다가 없었다가 (어깨·가슴·등·하체만)
                if let p = part, !p.subRegions.isEmpty {
                    chips("세부부위", p.subRegions, $sub) { $0 }
                }
                // 기구: 유산소는 해당 없음 → 숨김
                if part != .cardio {
                    chips("기구", EquipmentType.allCases, $equip) { $0.rawValue }
                }
                list
                doneButton
            }
            .padding(20)
            .background(Theme.bg)
            .navigationTitle("운동 추가하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("닫기") { dismiss() }.tint(Theme.or) }
            .onChange(of: part) { sub = nil }   // 대분류 바뀌면 세부부위 초기화
            .interactiveDismissDisabled(!selected.isEmpty)   // 선택 중 실수로 쓸어내려도 안 닫힘
            .keyboardDoneToolbar()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.footnote).foregroundStyle(Theme.sub)
            TextField("운동 이름 검색", text: $query,
                      prompt: Text("운동 이름 검색").foregroundStyle(Theme.sub))
                .font(.subheadline).foregroundStyle(Theme.dark)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.footnote).foregroundStyle(Theme.bd)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// 부위 + (세부부위) + 기구로 거른 목록. 유산소는 기구 필터를 무시.
    private func filteredBase() -> [Exercise] {
        var r = store.filtered(part: part, equip: part == .cardio ? nil : equip)
        if let part, let sub {
            r = r.filter { part.subRegion(of: $0) == sub }
        }
        return r
    }

    private var items: [Exercise] {
        let q = trimmedQuery.lowercased()
        // 부위·기구 필터가 걸려 있으면 그 범위, 아니면 전체
        let basePool = (part == nil && equip == nil) ? store.exercises : filteredBase()
        var pool: [Exercise]
        switch source {
        case .all:
            // 기본: 필터나 검색어가 있어야 목록 표시 (기존 동작)
            guard !q.isEmpty || part != nil || equip != nil else { return [] }
            pool = basePool
        case .recent:
            // 최근 2주 내 했던 운동 — 최근에 한 순서, 부위·기구 필터 그대로 적용
            let order = store.recentExerciseIDs(days: 14)
            let idx = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
            pool = basePool.filter { idx[$0.id] != nil }.sorted { idx[$0.id]! < idx[$1.id]! }
        case .favorite:
            // 즐겨찾기 — 부위·기구 필터 그대로 적용
            pool = basePool.filter { store.favorites.contains($0.id) }
        }
        guard !q.isEmpty else { return pool }
        return pool.filter { $0.koName.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }

    /// 목록 행의 부위·기구 표시 (유산소는 "유산소"만)
    private func subLabel(_ ex: Exercise) -> String {
        if BodyPart.of(ex) == .cardio { return "유산소" }
        let p = BodyPart.of(ex)?.rawValue ?? "-"
        let e = EquipmentType.allCases.first { $0.raw == ex.equipment }?.rawValue ?? ex.equipment
        return "\(p) · \(e)"
    }

    private func toggle(_ ex: Exercise) {
        if selected.contains(ex.id) { selected.remove(ex.id) } else { selected.insert(ex.id) }
    }

    private var list: some View {
        ScrollView {
            if source == .all && part == nil && equip == nil && trimmedQuery.isEmpty {
                Text("부위·기구를 선택하거나\n운동 이름으로 검색하세요.")
                    .multilineTextAlignment(.center)
                    .font(.footnote).foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.top, 40)
            } else if items.isEmpty {
                Text(source == .recent ? "최근 2주 안에 한 운동이 없어요."
                     : source == .favorite ? "즐겨찾기한 운동이 없어요.\n목록에서 북마크를 눌러 추가하세요."
                     : "검색 결과가 없어요.")
                    .multilineTextAlignment(.center)
                    .font(.footnote).foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.top, 40)
            }
            LazyVStack(spacing: 0) {
                ForEach(items) { ex in
                    let on = selected.contains(ex.id)
                    let fav = store.favorites.contains(ex.id)
                    HStack(spacing: 10) {
                        NavigationLink(value: ex) {
                            HStack(spacing: 10) {
                                ExerciseThumb(exercise: ex)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.koName).font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt)
                                    Text(subLabel(ex))
                                        .font(.caption2).foregroundStyle(Theme.sub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.bd)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button { store.toggleFavorite(ex.id) } label: {
                            Image(systemName: fav ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(fav ? Theme.or : Theme.bd).font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button { toggle(ex) } label: {
                            Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(Theme.or).font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(Theme.bd)
                }
            }
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: Exercise.self) { ex in
            ExerciseDetailView(exercise: ex, added: selected.contains(ex.id)) { toggle(ex) }
        }
    }

    // 보기 소스 칩 (기본 / 최근 운동 / 즐겨찾기 — 항상 하나 선택)
    private var sourceChips: some View {
        HStack(spacing: 6) {
            ForEach(ExerciseSource.allCases, id: \.self) { s in
                let on = source == s
                Button {
                    source = s
                } label: {
                    HStack(spacing: 4) {
                        if s == .recent { Image(systemName: "clock").font(.caption2) }
                        if s == .favorite { Image(systemName: "bookmark").font(.caption2) }
                        Text(s.rawValue).font(.footnote.weight(on ? .semibold : .regular))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(on ? Theme.or : .white, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? Theme.or : Theme.bd, lineWidth: 1))
                    .foregroundStyle(on ? .white : Theme.txt)
                }
            }
        }
    }

    private var doneButton: some View {
        Button {
            onDone(store.exercises.filter { selected.contains($0.id) })
            dismiss()
        } label: {
            Text(selected.isEmpty ? "운동을 선택하세요" : "\(selected.count)개 추가 완료")
                .font(.title3.weight(.medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(15)
                .background(selected.isEmpty ? Theme.bd : Theme.or, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selected.isEmpty)
    }

    private func chips<T: Hashable>(_ title: String, _ items: [T], _ sel: Binding<T?>, label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(Theme.or)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        let on = sel.wrappedValue == item
                        Button(label(item)) { sel.wrappedValue = on ? nil : item }
                            .font(.footnote)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(on ? Theme.or : .white, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Theme.or : Theme.bd, lineWidth: 1))
                            .foregroundStyle(on ? .white : Theme.txt)
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }
}

fileprivate struct ExHistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let volume: Double
    let distance: Double
    let duration: Int
}

// MARK: - 운동 설명 페이지
struct ExerciseDetailView: View {
    @EnvironmentObject var store: DataStore
    let exercise: Exercise
    @State var added: Bool
    var onToggle: () -> Void

    private var isCardio: Bool { BodyPart.of(exercise) == .cardio }
    private var advice: WorkoutAdvice {
        AICoach.advice(for: PlannedExercise(
            exerciseID: exercise.id, name: exercise.koName,
            bodyPart: BodyPart.of(exercise), sets: []))
    }

    /// 이 운동의 세션별 기록 (오래된 → 최신)
    private var history: [ExHistoryPoint] {
        store.records
            .compactMap { r -> (Date, PlannedExercise)? in
                guard let pe = r.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
                return (r.endedAt, pe)
            }
            .sorted { $0.0 < $1.0 }
            .map { date, pe in
                ExHistoryPoint(date: date,
                               weight: pe.sets.map(\.weight).max() ?? 0,
                               volume: pe.sets.reduce(0) { $0 + $1.weight * Double($1.reps) },
                               distance: pe.sets.compactMap(\.distance).max() ?? 0,
                               duration: pe.sets.compactMap(\.duration).max() ?? 0)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.koName).font(.title2.weight(.semibold)).foregroundStyle(Theme.orD)
                    Text(exercise.name).font(.footnote).foregroundStyle(Theme.sub)
                }
                HStack(spacing: 6) {
                    tag(BodyPart.of(exercise)?.rawValue ?? "-")
                    tag(EquipmentType.allCases.first { $0.raw == exercise.equipment }?.rawValue ?? exercise.equipment)
                }
                ExerciseMotionView(exercise: exercise)
                recordCard
                adviceCard
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .navigationTitle("운동 설명")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { addBar }
    }

    // MARK: 내 기록 (성장 그래프 + 최고기록)
    private var recordCard: some View {
        let h = history
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.or)
                Text("내 기록").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.or)
            }
            if h.isEmpty {
                Text("아직 이 운동 기록이 없어요.\n한 번 해보면 성장 그래프가 채워져요.")
                    .font(.footnote).foregroundStyle(Theme.sub)
            } else {
                HStack(spacing: 8) {
                    if isCardio {
                        prPill("최장 거리", "\((h.map(\.distance).max() ?? 0).formatted())km")
                        prPill("최장 시간", "\((h.map(\.duration).max() ?? 0) / 60)분")
                    } else {
                        prPill("최고 무게", "\((h.map(\.weight).max() ?? 0).formatted())kg")
                        prPill("최고 볼륨", "\(Int(h.map(\.volume).max() ?? 0))kg")
                    }
                    prPill("기록", "\(h.count)회")
                }
                Chart(h) { p in
                    let y = isCardio ? p.distance : p.weight
                    LineMark(x: .value("날짜", p.date), y: .value("기록", y)).foregroundStyle(Theme.or)
                    PointMark(x: .value("날짜", p.date), y: .value("기록", y)).foregroundStyle(Theme.or)
                }
                .chartXAxis { AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
                } }
                .chartYAxis { AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.bd)
                    AxisValueLabel().font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
                } }
                .frame(height: 150)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
    }
    private func prPill(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Theme.orD)
            Text(title).font(.caption2).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 12))
    }

    private var adviceCard: some View {
        let a = advice
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Theme.or)
                Text("AI 자세 가이드").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.or)
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
            group("핵심 자세", a.formCues, icon: "checkmark", tint: Theme.or)
            group("흔한 실수", a.mistakes, icon: "xmark", tint: Color(red: 0.85, green: 0.4, blue: 0.3))
            HStack(alignment: .top, spacing: 8) {
                pill("템포", a.tempo)
                pill("휴식", a.rest)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 16))
    }

    private var addBar: some View {
        Button {
            added.toggle(); onToggle()
        } label: {
            Text(added ? "추가됨 ✓" : "이 운동 추가")
                .font(.title3.weight(.medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(15)
                .background(added ? Theme.orD : Theme.or, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func group(_ title: String, _ items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.sub)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: icon).font(.caption2).foregroundStyle(tint).padding(.top, 2)
                    Text(item).font(.footnote).foregroundStyle(Theme.txt)
                }
            }
        }
    }

    private func pill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.or)
            Text(value).font(.caption2).foregroundStyle(Theme.txt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(Theme.or)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.orL, in: Capsule())
    }
}

// MARK: - 운동 미디어(GIF) 소스 추상화
// ⚠️ 이미지 소스를 나중에 갈아끼울 수 있도록 데이터와 분리. 상업 출시 전 라이선스 문제로 교체 가능.
protocol ExerciseImageProvider {
    /// 운동의 애니메이션 GIF URL (없으면 nil)
    func gifURL(for exercise: Exercise) -> URL?
}

/// hasaneyldrm/exercises-dataset (GymVisual 이미지, 180×180, 비상업/개발용).
struct HasanGIFProvider: ExerciseImageProvider {
    static let base = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/"
    func gifURL(for e: Exercise) -> URL? {
        guard let path = e.images.first, !path.isEmpty else { return nil }  // 예: "videos/0001-xxx.gif"
        return URL(string: Self.base + path)
    }
}

/// 앱 전역 미디어 소스 진입점 — 소스 교체 시 이 한 줄만 바꾸면 됨.
enum ExerciseMedia {
    static let provider: ExerciseImageProvider = HasanGIFProvider()
}

// MARK: - 목록용 작은 썸네일 (GIF 첫 프레임을 정지 이미지로)
struct ExerciseThumb: View {
    let exercise: Exercise
    var size: CGFloat = 46

    var body: some View {
        Group {
            if let url = ExerciseMedia.provider.gifURL(for: exercise) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Image(systemName: "dumbbell")
                            .font(.caption).foregroundStyle(Theme.bd)
                    }
                }
            } else {
                Image(systemName: "dumbbell").font(.caption).foregroundStyle(Theme.bd)
            }
        }
        .frame(width: size, height: size)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.bd, lineWidth: 1))
    }
}

// MARK: - 자세 GIF 표시
struct ExerciseMotionView: View {
    let exercise: Exercise
    var height: CGFloat = 220

    @State private var data: Data?
    @State private var failed = false

    var body: some View {
        Group {
            if let data {
                GIFView(data: data).frame(height: height)
            } else if failed {
                EmptyView()                                    // 없거나 실패하면 조용히 숨김
            } else {
                ProgressView().tint(Theme.or)
                    .frame(maxWidth: .infinity).frame(height: height)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        // 라이선스: 미디어는 GymVisual 소유 → 출처 표기 필수 (상업 출시 전 교체 필요)
        .overlay(alignment: .bottomTrailing) {
            if data != nil {
                Text("© Gym visual").font(.system(size: 9)).foregroundStyle(Theme.sub)
                    .padding(6)
            }
        }
        .task(id: exercise.id) { await load() }
    }

    private func load() async {
        data = nil; failed = false
        guard let url = ExerciseMedia.provider.gifURL(for: exercise) else { failed = true; return }
        if let (d, _) = try? await URLSession.shared.data(from: url) { data = d }
        else { failed = true }
    }
}

// GIF를 프레임 합성·타이밍까지 정확히 처리해 재생 → 잔상(ghosting) 없음.
// CGAnimateImageDataWithBlock이 GIF disposal/합성을 올바르게 다뤄 이전 프레임이 남지 않음.
struct GIFView: UIViewRepresentable {
    let data: Data
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var stop = false }

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        let coord = context.coordinator
        CGAnimateImageDataWithBlock(data as CFData, nil) { [weak iv] _, cgImage, stopPtr in
            if coord.stop || iv == nil { stopPtr.pointee = true; return }
            iv?.image = UIImage(cgImage: cgImage)   // 매 프레임 완전 합성된 이미지
        }
        return iv
    }
    func updateUIView(_ v: UIImageView, context: Context) {}
    static func dismantleUIView(_ v: UIImageView, coordinator: Coordinator) { coordinator.stop = true }
}
