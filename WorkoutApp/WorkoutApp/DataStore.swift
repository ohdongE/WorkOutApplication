import Foundation
import WidgetKit

@MainActor
final class DataStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var plans: [WorkoutPlan] = [] { didSet { save(plans, "plans.json") } }
    @Published var records: [WorkoutRecord] = [] {
        didSet {
            save(records, "records.json")
            WidgetCenter.shared.reloadAllTimelines()   // 피로도 위젯 갱신
        }
    }
    @Published var inbody: [InBodyRecord] = [] { didSet { save(inbody, "inbody.json") } }
    @Published var favorites: Set<String> = [] { didSet { save(favorites, "favorites.json") } }

    init() {
        if let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = list
        }
        plans = load("plans.json") ?? []
        records = load("records.json") ?? []
        inbody = load("inbody.json") ?? []
        favorites = load("favorites.json") ?? []
    }

    func toggleFavorite(_ exerciseID: String) {
        if favorites.contains(exerciseID) { favorites.remove(exerciseID) }
        else { favorites.insert(exerciseID) }
    }
    /// 최근 N일 내에 했던 운동 id — 가장 최근에 한 순서
    func recentExerciseIDs(days: Int) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for r in recentRecords(days: days) {
            for e in r.exercises where !seen.contains(e.exerciseID) {
                seen.insert(e.exerciseID); out.append(e.exerciseID)
            }
        }
        return out
    }

    /// 인바디 CSV 가져오기 병합 — 이미 있는 날짜(중복)는 제외하고 새 날짜만 추가. 반환: 새로 추가된 건수
    func mergeInBody(_ new: [InBodyRecord]) -> Int {
        let cal = Calendar.current
        var added = 0
        for r in new where !inbody.contains(where: { cal.isDate($0.date, inSameDayAs: r.date) }) {
            inbody.append(r); added += 1
        }
        inbody.sort { $0.date < $1.date }
        return added
    }
    func deleteInBody(_ record: InBodyRecord) {
        inbody.removeAll { $0.id == record.id }
    }

    func filtered(part: BodyPart?, equip: EquipmentType?) -> [Exercise] {
        guard part != nil || equip != nil else { return [] }
        return exercises.filter { e in
            (part.map { !$0.muscles.isDisjoint(with: e.primaryMuscles) } ?? true) &&
            (equip.map { $0.raw == e.equipment } ?? true)
        }
    }

    func deletePlan(_ plan: WorkoutPlan) {
        plans.removeAll { $0.id == plan.id }
    }
    func deleteRecord(_ record: WorkoutRecord) {
        records.removeAll { $0.id == record.id }
    }

    func records(on day: Date) -> [WorkoutRecord] {
        records.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: day) }
    }
    func recentRecords(days: Int) -> [WorkoutRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        return records.filter { $0.endedAt >= cutoff && $0.endedAt < tomorrow }   // 미래 날짜 기록 제외
            .sorted { $0.endedAt > $1.endedAt }
    }

    private func save<T: Encodable>(_ v: T, _ n: String) {
        try? JSONEncoder().encode(v).write(to: SharedStore.url(n))
    }
    private func load<T: Decodable>(_ n: String) -> T? {
        func decode(_ url: URL) -> T? {
            guard let d = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(T.self, from: d)
        }
        // App Group 공유 컨테이너 우선
        if let v = decode(SharedStore.url(n)) { return v }
        // App Group 도입 이전에 앱 전용 Documents에 저장된 데이터 → 1회 자동 이관
        let legacy = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(n)
        return decode(legacy)   // 반환값이 assign되면 didSet → 공유 컨테이너로 재저장됨
    }
}
