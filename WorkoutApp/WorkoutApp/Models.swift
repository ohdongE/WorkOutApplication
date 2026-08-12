import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let equipment: String
    let primaryMuscles: [String]
    let level: String
    let images: [String]
    var koName: String { KoName.translate(name) }
}

enum BodyPart: String, CaseIterable, Codable {
    case shoulder = "어깨", chest = "가슴", back = "등"
    case biceps = "이두", triceps = "삼두", lower = "하체"
    case cardio = "유산소"
    var muscles: Set<String> {
        switch self {
        case .shoulder: ["shoulders", "traps"]
        case .chest:    ["chest"]
        case .back:     ["lats", "middle back", "lower back"]
        case .biceps:   ["biceps", "forearms"]
        case .triceps:  ["triceps"]
        case .lower:    ["quadriceps", "hamstrings", "glutes", "calves", "abductors", "adductors"]
        case .cardio:   ["cardio"]
        }
    }
    static func of(_ e: Exercise) -> BodyPart? {
        allCases.first { !$0.muscles.isDisjoint(with: e.primaryMuscles) }
    }

    /// 세부부위(중분류) — 없는 부위는 빈 배열
    var subRegions: [String] {
        switch self {
        case .shoulder: ["전면", "측면", "후면"]
        case .chest:    ["상부", "중부", "하부"]
        case .back:     ["광배", "승모", "하부"]
        case .lower:    ["대퇴", "햄스트링", "둔근", "종아리"]
        default:        []
        }
    }

    /// 운동을 세부부위로 분류(이름 키워드 기반). 세부부위 없는 부위는 nil.
    func subRegion(of e: Exercise) -> String? {
        guard !subRegions.isEmpty else { return nil }
        let k = (e.id + " " + e.name).lowercased()
        func has(_ ss: String...) -> Bool { ss.contains { k.contains($0) } }
        switch self {
        case .shoulder:
            if has("rear", "reverse", "bent-over lateral", "face pull", "prone") { return "후면" }
            if has("lateral", "side", "upright") { return "측면" }
            return "전면"                                  // 프론트/오버헤드/밀리터리/아놀드/숄더프레스
        case .chest:
            if has("incline") { return "상부" }
            if has("decline") { return "하부" }
            return "중부"
        case .back:
            if has("shrug") { return "승모" }
            if has("deadlift", "good morning", "hyperextension", "back extension", "romanian") { return "하부" }
            return "광배"                                  // 풀다운/풀업/로우/풀오버
        case .lower:
            if has("calf", "calve") { return "종아리" }
            if has("leg curl", "lying curl", "seated curl", "romanian", "stiff", "good morning", "glute-ham") { return "햄스트링" }
            if has("hip thrust", "glute", "bridge", "hip extension") { return "둔근" }
            return "대퇴"                                  // 스쿼트/레그프레스/익스텐션/런지/핵
        default: return nil
        }
    }
}

enum EquipmentType: String, CaseIterable, Codable {
    case barbell = "바벨", ezBar = "이지바", dumbbell = "덤벨"
    case cable = "케이블머신", machine = "머신"
    var raw: String {
        switch self {
        case .barbell: "barbell"; case .ezBar: "e-z curl bar"
        case .dumbbell: "dumbbell"; case .cable: "cable"; case .machine: "machine"
        }
    }
}

struct PlannedSet: Codable, Identifiable, Hashable {
    var id = UUID(); var weight: Double; var reps: Int
    var duration: Int? = nil      // 유산소: 시간(초)
    var distance: Double? = nil   // 유산소: 거리(km)

    /// 부위별 기본 세트 구성 (유산소는 시간·거리 1회차, 그 외 웨이트 3세트)
    static func defaults(for bodyPart: BodyPart?) -> [PlannedSet] {
        if bodyPart == .cardio {
            return [PlannedSet(weight: 0, reps: 0, duration: 600, distance: 1.0)]
        }
        return [.init(weight: 20, reps: 8), .init(weight: 20, reps: 8), .init(weight: 20, reps: 8)]
    }
    /// 기록/표시용 요약 문자열
    func summary(cardio: Bool) -> String {
        if cardio {
            let m = (duration ?? 0) / 60, s = (duration ?? 0) % 60
            let t = s > 0 ? "\(m)분 \(s)초" : "\(m)분"
            if let d = distance, d > 0 { return "\(t) · \(d.formatted())km" }
            return t
        }
        return "\(weight.formatted())kg×\(reps)"
    }
}
struct PlannedExercise: Codable, Identifiable, Hashable {
    var id = UUID(); var exerciseID: String; var name: String
    var bodyPart: BodyPart?
    var sets: [PlannedSet]
}
struct WorkoutPlan: Codable, Identifiable, Hashable {
    var id = UUID(); var name: String; var exercises: [PlannedExercise]
}
struct WorkoutRecord: Codable, Identifiable, Hashable {
    var id = UUID(); var planName: String
    var startedAt: Date; var endedAt: Date
    var exercises: [PlannedExercise]
    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
    }
    var calories: Double { duration / 60 * 6 }
}

// MARK: - 인바디(체성분) 기록
struct InBodyRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var weight: Double?       // 체중(kg)
    var muscle: Double?       // 골격근량(kg)
    var fatMass: Double?      // 체지방량(kg)
    var fatPercent: Double?   // 체지방률(%)
    var bmi: Double?

    /// 인바디 앱 CSV 내보내기 파싱 — 헤더 키워드로 열을 자동 감지해 형식이 조금 달라도 동작.
    static func parse(csv text: String) -> [InBodyRecord] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return [] }
        let sep: Character = lines[0].contains("\t") ? "\t" : (lines[0].contains(";") ? ";" : ",")
        func cells(_ line: String) -> [String] {
            line.split(separator: sep, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'\u{FEFF}")) }
        }
        let header = cells(lines[0])
        func col(_ keys: [String], exclude: [String] = []) -> Int? {
            header.firstIndex { h in
                keys.contains { h.localizedCaseInsensitiveContains($0) } &&
                !exclude.contains { h.localizedCaseInsensitiveContains($0) }
            }
        }
        let dateC   = col(["측정일", "일자", "날짜", "일시", "date"])
        let weightC = col(["체중", "weight"], exclude: ["목표", "표준", "조절", "control"])
        let muscleC = col(["골격근", "skeletal", "smm"])
        let fatPctC = col(["체지방률", "pbf", "percent"])
        let fatC    = col(["체지방량", "fat mass", "bfm"])
        let bmiC    = col(["bmi", "체질량"])
        guard let dc = dateC, weightC != nil || muscleC != nil else { return [] }

        var out: [InBodyRecord] = []
        for line in lines.dropFirst() {
            let c = cells(line)
            guard c.count > dc, let date = parseDate(c[dc]) else { continue }
            func num(_ i: Int?) -> Double? {
                guard let i, i < c.count else { return nil }
                let s = c[i].filter { "0123456789.-".contains($0) }
                return s.isEmpty ? nil : Double(s)
            }
            let r = InBodyRecord(date: date, weight: num(weightC), muscle: num(muscleC),
                                 fatMass: num(fatC), fatPercent: num(fatPctC), bmi: num(bmiC))
            if r.weight != nil || r.muscle != nil { out.append(r) }
        }
        return out.sorted { $0.date < $1.date }
    }

    /// "2026.07.09", "2026-07-09 07:30", "2026년 7월 9일", "20260709…" 등에서 연·월·일 추출
    static func parseDate(_ s: String) -> Date? {
        let pattern = #"(\d{4})[.\-/년\s]*(\d{1,2})[.\-/월\s]*(\d{1,2})"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r1 = Range(m.range(at: 1), in: s),
              let r2 = Range(m.range(at: 2), in: s),
              let r3 = Range(m.range(at: 3), in: s),
              let y = Int(s[r1]), let mo = Int(s[r2]), let d = Int(s[r3]),
              (1...12).contains(mo), (1...31).contains(d) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: mo, day: d))
    }
}

// MARK: - 인바디 AI 코치 (체성분 변화 분석 → 운동·식단 방향)
// 근거: 체성분 개선의 표준 지침 —
//  · 단백질 1.6~2.2g/kg/일 (근비대·근보존 메타분석 권장 범위)
//  · 감량 속도 주당 체중의 0.5~1% (그 이상은 제지방 손실 급증)
//  · 증량 잉여 +200~300kcal (과잉 잉여는 대부분 지방으로 축적)
//  · 근성장 자극은 점진적 과부하 + 주 부위별 10~20세트
//  측정 오차를 고려해 골격근 ±0.3kg, 체지방률 ±0.5%p, 체중 ±0.5kg 미만은 "유지"로 판정.
struct InBodyAdvice: Hashable {
    enum Tone { case good, neutral, warn, bad }
    var tone: Tone
    var headline: String     // 한 줄 진단
    var analysis: [String]   // 수치 해석
    var actions: [String]    // 앞으로의 운동·식단 방향
}

enum InBodyCoach {
    static func advice(_ records: [InBodyRecord]) -> InBodyAdvice? {
        guard let last = records.last else { return nil }
        guard records.count >= 2 else { return firstMeasurement(last) }
        let prev = records[records.count - 2]

        func delta(_ a: Double?, _ b: Double?) -> Double? {
            guard let a, let b else { return nil }
            return a - b
        }
        let dW  = delta(last.weight, prev.weight)          // 체중 변화
        let dM  = delta(last.muscle, prev.muscle)          // 골격근량 변화
        let dFP = delta(last.fatPercent, prev.fatPercent)  // 체지방률 변화(%p)
        let dFM = delta(last.fatMass, prev.fatMass)        // 체지방량 변화
        let days = max(1, Calendar.current.dateComponents([.day], from: prev.date, to: last.date).day ?? 1)

        // 판정 신호 (측정 오차 이하는 무시)
        let muscleUp   = (dM ?? 0) >= 0.3
        let muscleDown = (dM ?? 0) <= -0.3
        // 체지방: 체지방률 우선, 없으면 체지방량으로
        let fatUp   = dFP.map { $0 >= 0.5 } ?? ((dFM ?? 0) >= 0.5)
        let fatDown = dFP.map { $0 <= -0.5 } ?? ((dFM ?? 0) <= -0.5)

        func fmt(_ v: Double, _ unit: String) -> String { String(format: "%+.1f", v) + unit }
        var analysis: [String] = ["\(prev.date.formatted(.dateTime.month().day())) → \(last.date.formatted(.dateTime.month().day())) (\(days)일 사이)"]
        if let w = last.weight, let d = dW { analysis.append("체중 \(w.formatted())kg (\(fmt(d, "kg")))") }
        if let m = last.muscle, let d = dM { analysis.append("골격근량 \(m.formatted())kg (\(fmt(d, "kg")))") }
        if let f = last.fatPercent, let d = dFP { analysis.append("체지방률 \(f.formatted())% (\(fmt(d, "%p")))") }
        else if let f = last.fatMass, let d = dFM { analysis.append("체지방량 \(f.formatted())kg (\(fmt(d, "kg")))") }

        // 근육·지방 데이터가 없으면 체중만으로 제한적 조언
        guard dM != nil || dFP != nil || dFM != nil else {
            return weightOnly(dW, analysis: analysis)
        }

        var a: InBodyAdvice
        switch (muscleUp, muscleDown, fatUp, fatDown) {
        // 근육↑ 지방↓ — 최상의 리컴프
        case (true, _, _, true):
            a = InBodyAdvice(tone: .good,
                headline: "이상적인 변화예요 — 근육은 늘고 체지방은 줄었습니다.",
                analysis: analysis,
                actions: ["지금 루틴이 정확히 작동 중입니다. 프로그램을 바꾸지 마세요",
                          "정체가 오기 전까지 점진적 과부하 유지 — 목표 횟수를 다 채우면 무게를 2.5~5% 올리기",
                          "단백질은 체중 1kg당 1.6~2.2g을 계속 유지하세요",
                          "수면 7시간 이상 — 근육 합성과 회복의 절반은 잠에서 나옵니다"])
        // 근육↑ 지방↑ — 증량(벌크) 흐름
        case (true, _, true, _):
            a = InBodyAdvice(tone: .neutral,
                headline: "근육과 체지방이 함께 늘었어요 — 증량(벌크) 흐름입니다.",
                analysis: analysis,
                actions: ["의도한 증량이라면 정상 궤도입니다. 다만 지방이 근육보다 빨리 늘면 잉여 칼로리를 줄이세요 (+200~300kcal면 충분)",
                          "고강도 근력운동을 유지해야 잉여 에너지가 근육으로 갑니다 — 주 3~4회, 부위별 주 10~20세트",
                          "체지방률이 계속 오르면 저강도 유산소를 주 2회 20~30분 추가",
                          "가공식품·액상과당보다 단백질과 복합탄수화물로 칼로리를 채우세요"])
        // 근육↓ 지방↓ — 감량 중 근손실
        case (_, true, _, true):
            a = InBodyAdvice(tone: .warn,
                headline: "체지방과 함께 근육도 빠지고 있어요 — 감량 속도 조절이 필요합니다.",
                analysis: analysis,
                actions: ["감량 속도를 주당 체중의 0.5~1% 이내로 늦추세요 — 그 이상 빠지면 근육이 함께 갑니다",
                          "단백질을 체중 1kg당 2.0~2.2g으로 올리세요 — 감량기엔 평소보다 더 필요합니다",
                          "근력운동 무게를 낮추지 마세요 — 무게를 유지해야 몸이 근육을 지킬 이유가 생깁니다",
                          "유산소가 주 4회 이상이라면 2~3회로 줄이고 근력운동을 우선하세요"])
        // 근육↓ 지방↑ — 가장 나쁜 방향
        case (_, true, true, _):
            a = InBodyAdvice(tone: .bad,
                headline: "주의가 필요해요 — 근육은 줄고 체지방은 늘었습니다.",
                analysis: analysis,
                actions: ["체성분이 나쁜 방향으로 움직이고 있습니다. 원인은 대부분 ①근력운동 부족 ②단백질 부족 ③수면·스트레스 ④음주입니다 — 이 4가지부터 점검하세요",
                          "주 3~4회 복합운동(스쿼트·데드리프트·벤치·로우) 중심으로 근력운동을 다시 세우세요 — 근육에 '유지할 이유'를 줘야 합니다",
                          "매끼 단백질 25~40g(하루 체중 1kg당 1.6~2.2g)을 먼저 채우고 나머지를 구성하세요",
                          "야식·음주·액상당(음료)을 먼저 끊는 게 식단 조절의 최우선입니다",
                          "일상 활동량(걷기·계단)을 늘리세요 — 운동 1시간보다 나머지 23시간이 체지방을 좌우합니다",
                          "2~4주 뒤 같은 조건(아침 공복)에서 재측정해 방향을 확인하세요"])
        // 근육↑ 지방 유지
        case (true, _, false, false):
            a = InBodyAdvice(tone: .good,
                headline: "체지방 증가 없이 근육이 늘었어요 — 아주 좋은 흐름입니다.",
                analysis: analysis,
                actions: ["현재 식사량과 루틴 균형이 좋습니다 — 그대로 유지하세요",
                          "성장 속도를 더 내고 싶다면 +200kcal 정도만 조심스럽게 늘려보세요",
                          "점진적 과부하 유지 — 기록이 3주 이상 정체되면 세트 수나 무게를 조정합니다"])
        // 근육 유지 지방↓
        case (false, false, _, true):
            a = InBodyAdvice(tone: .good,
                headline: "근육을 지키면서 체지방만 줄였어요 — 교과서적인 감량입니다.",
                analysis: analysis,
                actions: ["지금 감량 속도가 적절합니다 — 이대로 진행하세요",
                          "단백질(1.6~2.2g/kg)과 근력운동 강도를 끝까지 유지하는 게 핵심입니다",
                          "체중 감소가 2주 이상 멈추면 -100~200kcal 추가 조정 또는 활동량 증가로 대응하세요"])
        // 근육 유지 지방↑
        case (false, false, true, _):
            a = InBodyAdvice(tone: .warn,
                headline: "근육은 그대로인데 체지방이 늘었어요 — 섭취 칼로리 점검이 필요합니다.",
                analysis: analysis,
                actions: ["근력운동은 작동 중이지만 칼로리가 남고 있습니다 — 최근 식사량·간식·음주를 점검하세요",
                          "하루 -200~300kcal만 줄여도 방향이 바뀝니다. 급하게 굶지 마세요",
                          "저강도 유산소(빠르게 걷기 30분)를 주 2~3회 추가하면 부담 없이 소비를 늘릴 수 있습니다"])
        // 큰 변화 없음
        default:
            a = InBodyAdvice(tone: .neutral,
                headline: "체성분이 유지되고 있어요.",
                analysis: analysis,
                actions: ["유지가 목표라면 성공적입니다. 변화가 목표라면 자극이 부족하다는 신호예요",
                          "근육을 늘리려면: 무게·세트 수를 늘리고(점진적 과부하) +200kcal",
                          "체지방을 줄이려면: -300~500kcal 적자 + 단백질 상향(2.0g/kg)",
                          "2~4주 간격으로 같은 조건에서 측정해 추세를 확인하세요"])
        }

        // 급격한 체중 변화 경고 덧붙이기
        if let d = dW {
            let perWeek = abs(d) / Double(days) * 7
            if d >= 3 || (d > 0 && perWeek >= 1.0 && !muscleUp) {
                a.actions.insert("⚠️ 체중이 짧은 기간에 크게 늘었습니다(\(fmt(d, "kg"))). 근육 증가 속도(월 0.5~1kg)를 넘는 증가분은 대부분 지방·수분입니다 — 섭취량을 먼저 점검하세요", at: 0)
                if a.tone == .neutral { a.tone = .warn }
            } else if d <= -3 || (d < 0 && perWeek >= 1.2) {
                a.actions.removeAll { $0.contains("감량 속도가 적절") }   // 경고와 모순되는 문구 제거
                a.actions.insert("⚠️ 체중 감소 속도가 빠릅니다(\(fmt(d, "kg"))). 주당 1%를 넘는 감량은 근손실·요요 위험이 큽니다 — 속도를 늦추세요", at: 0)
                if a.tone == .good { a.tone = .warn }
            }
        }
        return a
    }

    // 첫 측정 — 기준점 안내
    private static func firstMeasurement(_ r: InBodyRecord) -> InBodyAdvice {
        var analysis: [String] = []
        if let w = r.weight { analysis.append("체중 \(w.formatted())kg") }
        if let m = r.muscle { analysis.append("골격근량 \(m.formatted())kg") }
        if let f = r.fatPercent { analysis.append("체지방률 \(f.formatted())%") }
        return InBodyAdvice(tone: .neutral,
            headline: "첫 측정이 저장됐어요 — 이제 변화를 추적할 기준점이 생겼습니다.",
            analysis: analysis,
            actions: ["다음 측정은 2~4주 뒤, 같은 조건(아침 공복·운동 전)에서 하세요 — 조건이 다르면 수분 때문에 수치가 크게 흔들립니다",
                      "어떤 목표든 기본은 같습니다: 주 3회 이상 근력운동 + 단백질 1.6~2.2g/kg",
                      "다음 측정부터 골격근량·체지방률 변화를 분석해 방향을 알려드릴게요"])
    }

    // 체중 데이터만 있을 때
    private static func weightOnly(_ dW: Double?, analysis: [String]) -> InBodyAdvice {
        let d = dW ?? 0
        let headline = d >= 0.5 ? "체중이 늘었어요. 근육·지방 데이터가 있으면 더 정확한 분석이 가능해요."
                     : d <= -0.5 ? "체중이 줄었어요. 근육·지방 데이터가 있으면 더 정확한 분석이 가능해요."
                     : "체중이 유지되고 있어요."
        return InBodyAdvice(tone: .neutral, headline: headline, analysis: analysis,
            actions: ["체중만으로는 근육·지방 어느 쪽이 변했는지 알 수 없습니다",
                      "골격근량·체지방률이 포함된 CSV를 업로드하면 방향 분석을 해드릴게요"])
    }
}

enum KoName {
    static let dict: [String: String] = [
        "barbell":"바벨","dumbbell":"덤벨","dumbbells":"덤벨","cable":"케이블","machine":"머신",
        "lever":"레버","smith":"스미스","e-z":"이지","bench":"벤치","press":"프레스",
        "incline":"인클라인","decline":"디클라인","curl":"컬","curls":"컬","row":"로우","rows":"로우",
        "seated":"시티드","standing":"스탠딩","lying":"라잉","squat":"스쿼트","deadlift":"데드리프트",
        "lunge":"런지","raise":"레이즈","raises":"레이즈","lateral":"래터럴","front":"프론트","rear":"리어",
        "shoulder":"숄더","shrug":"슈러그","pulldown":"풀다운","pullover":"풀오버","pushdown":"푸시다운",
        "extension":"익스텐션","extensions":"익스텐션","kickback":"킥백","fly":"플라이","flyes":"플라이",
        "crossover":"크로스오버","overhead":"오버헤드","close":"클로즈","wide":"와이드","grip":"그립",
        "reverse":"리버스","preacher":"프리처","concentration":"컨센트레이션","hammer":"해머",
        "triceps":"트라이셉스","biceps":"바이셉스","leg":"레그","calf":"카프","hip":"힙","hack":"핵",
        "romanian":"루마니안","sumo":"스모","upright":"업라이트","military":"밀리터리","arnold":"아놀드",
        "one-arm":"원암","one":"원","arm":"암","two":"투","alternate":"얼터네이트","alternating":"얼터네이팅",
        "single":"싱글","split":"스플릿","bulgarian":"불가리안","walking":"워킹","face":"페이스",
        "pull":"풀","push":"푸시","up":"업","down":"다운","thrust":"스러스트","bridge":"브릿지",
        "clean":"클린","high":"하이","low":"로우","bent":"벤트","over":"오버","medium":"미디엄",
        "crunch":"크런치","behind":"비하인드","neck":"넥","back":"백","dip":"딥","chin":"친",
        "rope":"로프","bar":"바","straight":"스트레이트","v":"브이","drag":"드래그","kneeling":"닐링",
        "full":"풀","half":"하프","good":"굿","morning":"모닝","stiff":"스티프","t":"티","lat":"랫",
        // --- 확장: 데이터에 등장하지만 빠져있던 단어들 (한/영 혼용 방지) ---
        "side":"사이드","wrist":"리스트","delt":"델트","delts":"델트","deltoid":"델토이드","chest":"체스트",
        "flat":"플랫","narrow":"내로우","pulley":"풀리","palm":"팜","palms":"팜","head":"헤드",
        "rotation":"로테이션","rotations":"로테이션","tricep":"트라이셉","bicep":"바이셉","ez":"이지",
        "stance":"스탠스","long":"롱","attachment":"어태치먼트","cross":"크로스","external":"익스터널",
        "internal":"인터널","power":"파워","legs":"레그","legged":"레그","step":"스텝","ups":"업",
        "iron":"아이언","elevated":"엘리베이티드","flye":"플라이","inner":"이너","linear":"리니어",
        "jammer":"재머","laterals":"래터럴","thigh":"싸이","weighted":"웨이티드","zottman":"지트만",
        "worlds":"월드","world":"월드","guillotine":"길로틴","bodyweight":"맨몸","box":"박스",
        "chains":"체인","chain":"체인","bradford":"브래드포드","rocky":"로키","presses":"프레스",
        "butterfly":"버터플라이","deadlifts":"데드리프트","adduction":"어덕션","abductor":"어브덕터",
        "adductor":"어덕터","shrugs":"슈러그","car":"카","drivers":"드라이버","chair":"체어","band":"밴드",
        "body":"바디","cuban":"쿠반","skull":"스컬","crusher":"크러셔","skullcrusher":"스컬크러셔",
        "neutral":"뉴트럴","lunges":"런지","pronation":"프로네이션","supination":"수피네이션",
        "pronated":"프로네이티드","supinated":"수피네이티드","prone":"프론","supine":"수파인",
        "scaption":"스캡션","finger":"핑거","flexor":"플렉서","range":"레인지","motion":"모션",
        "db":"덤벨","facing":"페이싱","twist":"트위스트","jm":"제이엠","jefferson":"제퍼슨",
        "landmine":"랜드마인","iso":"아이소","sprint":"스프린트","cambered":"캠버드","middle":"미들",
        "mid":"미드","floor":"플로어","plie":"플리에","partials":"파셜","hyperextension":"하이퍼익스텐션",
        "rocking":"로킹","see":"시","saw":"소","shotgun":"샷건","hang":"행","pistol":"피스톨",
        "snatch":"스내치","speed":"스피드","spider":"스파이더","jerk":"저크","plate":"플레이트",
        "movers":"무버","mover":"무버","handle":"핸들","tate":"테이트","underhand":"언더핸드",
        "overhand":"오버핸드","pulldowns":"풀다운","jump":"점프","sissy":"시시","zercher":"저처",
        "anti":"안티","gravity":"그래비티","around":"어라운드","leverage":"레버리지","above":"어보브",
        "squats":"스쿼트",
        // --- 유산소 ---
        "treadmill":"트레드밀","running":"러닝","indoor":"인도어","cycling":"사이클링","rowing":"로잉",
        "elliptical":"일립티컬","trainer":"트레이너","stair":"스테어","climber":"클라이머","burpee":"버피",
        "mountain":"마운틴","knees":"니","battle":"배틀","swimming":"수영",
        // --- 새 데이터셋(ExerciseDB) 용어 ---
        "ball":"볼","exercise":"익서사이즈","stretch":"스트레치","kettlebell":"케틀벨","assisted":"어시스티드","sled":"슬레드","medicine":"메디신","dips":"딥스",
        "hands":"핸즈","toe":"토","resistance":"레지스턴스","hamstring":"햄스트링","forward":"포워드","glute":"글루트","roller":"롤러","lower":"로어",
        "knee":"니","wall":"월","run":"런","touch":"터치","arms":"암","twisting":"트위스팅","walk":"워크","kick":"킥",
        "donkey":"동키","inverted":"인버티드","double":"더블","swing":"스윙","parallel":"패러렐","hand":"핸드","abduction":"어덕션","revers":"리버스",
        "suspended":"서스펜디드","calves":"카프","pose":"포즈","scapula":"스캐퓰러","raised":"레이즈드","bosu":"보수","drop":"드롭","sit":"싯",
        "upper":"어퍼","quads":"쿼드","circles":"서클","muscle":"머슬","plyo":"플라이오","lift":"리프트","elbow":"엘보","french":"프렌치",
        "support":"서포트","circular":"서큘러","inverse":"인버스","extended":"익스텐디드","archer":"아처","response":"리스폰스","squeeze":"스퀴즈","stork":"스토크",
        "jack":"잭","rotational":"로테이셔널","three":"쓰리","march":"마치","goblet":"고블릿","retractor":"리트랙터","tap":"탭","balance":"밸런스",
        "handstand":"핸드스탠드","depresor":"디프레서","jumps":"점프","fixed":"픽스드","crossovers":"크로스오버","crawl":"크롤","pass":"패스","ski":"스키",
        "y":"와이","plank":"플랭크","throw":"쓰로우","modified":"모디파이드","squatting":"스쿼팅","tilt":"틸트","hyper":"하이퍼","pelvic":"펠빅",
        "piriformis":"피리포미스","olympic":"올림픽","hug":"허그","bike":"바이크","thruster":"쓰러스터","clasped":"클래스프드","reach":"리치","isometric":"아이소메트릭",
        "off":"오프","bars":"바","round":"라운드","gluteus":"글루테우스","self":"셀프","diagonal":"다이애고널","keens":"니","kipping":"키핑",
        "closer":"클로저","outstretched":"아웃스트레치드","l":"엘","upward":"업워드","get":"겟","bottoms":"바텀","tire":"타이어","angle":"앵글",
        "skin":"스킨","spine":"스파인","catch":"캐치","basic":"베이직","kickbacks":"킥백","femoral":"피모럴","twisted":"트위스티드","flip":"플립",
        "frog":"프로그","supported":"서포티드","drive":"드라이브","turkish":"터키시","diamond":"다이아몬드","cycle":"사이클","korean":"코리안","stalder":"스탈더",
        "variation":"베리에이션","scissor":"시저","depth":"뎁스","board":"보드","boxing":"복싱","pronate":"프로네이트","outside":"아웃사이드","fours":"포스",
        "mixed":"믹스드","w":"더블유","dog":"독","unilateral":"유니래터럴","clap":"클랩","ground":"그라운드","degrees":"디그리","thrusts":"쓰러스트",
        "hops":"홉","posterior":"포스테리어","pike":"파이크","cobra":"코브라","waiter":"웨이터","point":"포인트","inside":"인사이드","hindu":"힌두",
        "stationary":"스테이셔너리","sternum":"스터넘","peroneals":"페로니얼","contralateral":"콘트라래터럴","bowling":"볼링","thibaudeau":"티보도","stabilization":"스태빌라이제이션","quad":"쿼드",
        "all":"올","elevator":"엘리베이터","pirate":"파이럿","cat":"캣","straps":"스트랩","stride":"스트라이드","monster":"몬스터","farmers":"파머스",
        "male":"메일","skier":"스키어","sequence":"시퀀스","can":"캔","bends":"벤드","impossible":"임파서블","apart":"어파트","scott":"스캇",
        "pectoralis":"펙토랄리스","angled":"앵글드","twin":"트윈","platform":"플랫폼","supper":"슈퍼","astride":"어스트라이드","stepmill":"스텝밀","major":"메이저",
        "tibialis":"티비알리스","towel":"타월","out":"아웃","ring":"링","strap":"스트랩","stepbox":"스텝박스","frankenstein":"프랑켄슈타인","climb":"클라임",
        "carry":"캐리","squad":"스쿼트","rack":"랙","kicks":"킥","superman":"슈퍼맨","svend":"스벤드","plus":"플러스","reps":"렙",
        "gripper":"그리퍼","big":"빅","star":"스타","wheel":"휠","slam":"슬램","pin":"핀","planche":"플란체","yoga":"요가",
        "ergometer":"에르고미터","pec":"펙","renegade":"레니게이드","kayak":"카약","semi":"세미","gripless":"그립리스","gluteham":"글루트햄","rollerer":"롤러",
        "rotate":"로테이트","bear":"베어","clock":"클락","ropes":"로프","horizontal":"호리존탈","cossack":"코사크","hook":"훅","ankle":"앵클",
        "cage":"케이지","release":"릴리즈","peacher":"프리처","curtsey":"커트시","forth":"포스","slide":"슬라이드","flutter":"플러터","left":"레프트",
        "runners":"러너","deep":"딥","stability":"스태빌리티","sphinx":"스핑크스","outer":"아우터","hyght":"하이트","rotary":"로터리","short":"쇼트",
        "lifting":"리프팅","breeding":"브리딩","skater":"스케이터","gironda":"지론다","seesaw":"시소","multiple":"멀티플","backward":"백워드","battling":"배틀링",
        "reclining":"리클라이닝","pendlay":"펜들레이","dynamic":"다이나믹","potty":"포티","wipers":"와이퍼","london":"런던","vertical":"버티컬","trap":"트랩",
        "scapular":"스캐퓰러","glutes":"글루트","reversed":"리버스드",
        "ham":"햄","intermediate":"인터미디엇","position":"포지션","greatest":"그레이티스트"
    ]
    /// 문장부호/불필요 단어를 걸러내는 필러 목록
    private static let drop: Set<String> =
        ["with","the","to","a","an","of","for","on","in","and","or","against","from","at","through","into"]

    static func translate(_ name: String) -> String {
        name.split(separator: " ").compactMap { token -> String? in
            let clean = token.lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "()./-_"))
            if clean.isEmpty || drop.contains(clean) { return nil }
            // 하이픈/슬래시/언더스코어 복합어는 조각별 번역 후 붙임 (필러 제거)
            if clean.contains("-") || clean.contains("/") || clean.contains("_") {
                let parts = clean.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "_" })
                    .map(String.init)
                    .filter { !$0.isEmpty && !drop.contains($0) }
                    .map { dict[$0] ?? $0 }
                return parts.isEmpty ? nil : parts.joined()
            }
            return dict[clean] ?? clean
        }.joined(separator: " ")
    }
}

struct WorkoutAdvice: Hashable {
    var summary: String        // 한 줄 요약
    var formCues: [String]     // 핵심 자세 포인트
    var mistakes: [String]     // 흔한 실수
    var tempo: String          // 템포/호흡
    var rest: String           // 추천 휴식
    var variation: String? = nil  // 변형(그립·각도·기구) 차이 설명 — 같은 동작의 다른 변형과 뭐가 다른지
}

enum AICoach {
    /// 부위 기본 조언 → 동작(운동 종류)별 전용 조언으로 덮어써서 반환.
    /// ⚠️ 단어 단위 매칭 (부분 문자열 X). 예: "machine"이 "chin"에 오탐되지 않도록.
    static func advice(for pe: PlannedExercise) -> WorkoutAdvice {
        // ⚠️ 현 데이터셋 id는 숫자라 표시 이름(한글 음차)까지 합쳐 단어 매칭.
        //    키워드는 영문으로 쓰고, KoName 사전으로 음차 형태까지 함께 대조한다.
        let words = Set((pe.exerciseID + " " + pe.name).lowercased()
            .split(whereSeparator: { !$0.isLetter }).map(String.init))
        if pe.bodyPart == .cardio { return cardioAdvice(words) }
        return weightAdvice(pe, words)
    }
    /// 영문 키워드 또는 그 한글 음차가 단어 목록에 있는지
    fileprivate static func hit(_ words: Set<String>, _ keys: [String]) -> Bool {
        keys.contains { words.contains($0) || words.contains(KoName.dict[$0] ?? $0) }
    }
    // MARK: 유산소 전용 조언
    private static func cardioAdvice(_ w: Set<String>) -> WorkoutAdvice {
        func has(_ ss: String...) -> Bool { hit(w, ss) }

        if has("burpee") {
            return WorkoutAdvice(
                summary: "전신을 쓰는 고강도 운동 — 속도보다 정확한 동작이 먼저입니다.",
                formCues: ["손을 어깨 바로 아래 짚고 다리를 뒤로 뻗으세요",
                           "엎드린 자세에서 배에 힘을 줘 허리가 처지지 않게",
                           "일어설 때 엉덩이를 쭉 펴며 가볍게 점프"],
                mistakes: ["허리가 아래로 꺾인 채 엎드리는 것",
                           "무릎을 굽히지 않고 뻣뻣하게 착지하는 것"],
                tempo: "일정한 리듬으로, 초보자는 10회 × 3세트부터",
                rest: "세트 간 60~90초, 호흡이 돌아온 뒤 시작")
        }
        if has("rope") {
            return WorkoutAdvice(
                summary: "손목으로 돌리고 발끝으로 낮게 뛰는 것이 오래 뛰는 비결입니다.",
                formCues: ["팔꿈치를 몸에 붙이고 손목으로만 줄을 돌리세요",
                           "발끝(앞꿈치)으로 착지하고 무릎은 부드럽게",
                           "높이는 2~3cm면 충분 — 낮게, 가볍게"],
                mistakes: ["팔 전체로 크게 돌려 금방 지치는 것",
                           "높이 뛰어 무릎·발목에 충격을 주는 것"],
                tempo: "1분 뛰고 30초 쉬기부터 시작해 점차 늘리기",
                rest: "종아리 피로가 크니 세트 간 30~60초")
        }
        if has("climber") {
            return WorkoutAdvice(
                summary: "플랭크 자세를 유지한 채 무릎만 당기는 코어+유산소 복합 운동입니다.",
                formCues: ["어깨가 손목 바로 위에 오도록 고정하세요",
                           "배에 힘을 줘 머리부터 발끝까지 일직선 유지",
                           "무릎을 가슴 쪽으로 리드미컬하게 번갈아 당기기"],
                mistakes: ["엉덩이가 위로 솟아 산 모양이 되는 것",
                           "몸이 위아래로 출렁이는 것"],
                tempo: "20~30초 진행 + 30초 휴식 반복",
                rest: "세트 간 30~60초")
        }
        if has("run", "running", "treadmill") {
            return WorkoutAdvice(
                summary: "발이 몸 아래에 착지하게 — 보폭을 줄이는 게 무릎을 지키는 핵심입니다.",
                formCues: ["시선은 정면, 어깨 힘을 빼고 팔은 앞뒤로만 흔드세요",
                           "보폭은 줄이고 발걸음은 빠르게 (발이 몸 앞에 떨어지지 않게)",
                           "발 중앙으로 부드럽게 착지"],
                mistakes: ["손잡이를 잡고 걷거나 뛰는 것 (운동 효과 급감)",
                           "보폭이 커서 뒤꿈치로 쿵쿵 찍는 것",
                           "경사에서 상체를 뒤로 젖히는 것"],
                tempo: "대화가 가능한 속도로 시작, 거리·속도는 주당 10%씩만 늘리기",
                rest: "인터벌이라면 뛰기 1분 + 걷기 2분 반복이 초보자에게 최적")
        }
        if has("bike", "cycle", "cycling") {
            return WorkoutAdvice(
                summary: "안장 높이만 제대로 맞춰도 무릎 통증의 대부분은 예방됩니다.",
                formCues: ["페달이 가장 아래일 때 무릎이 살짝 굽는 높이로 안장 조절",
                           "발 앞쪽(엄지발가락 뿌리)으로 페달을 밟으세요",
                           "배에 힘을 줘 골반을 고정하고 다리만 회전"],
                mistakes: ["안장이 낮아 무릎이 과하게 접히는 것",
                           "골반이 좌우로 흔들리는 것 (안장이 너무 높음)",
                           "핸들에 상체 무게를 전부 싣는 것"],
                tempo: "분당 80~100회전이 무릎에 가장 부담 없는 속도",
                rest: "인터벌이라면 고강도 30초 + 저강도 90초")
        }
        if has("elliptical") {
            return WorkoutAdvice(
                summary: "발 전체를 페달에 붙이고 팔과 다리를 함께 쓰는 전신 유산소입니다.",
                formCues: ["뒤꿈치까지 발 전체를 페달에 밀착하세요",
                           "핸들을 밀고 당기며 상체도 함께 사용",
                           "허리를 세우고 배에 힘 유지"],
                mistakes: ["까치발로 타서 종아리만 피로해지는 것",
                           "핸들에 기대 하체 부하가 빠지는 것"],
                tempo: "일정한 리듬으로 20~40분",
                rest: "강도는 저항 레벨로 조절, 속도는 일정하게")
        }
        if has("stepmill", "stair") {
            return WorkoutAdvice(
                summary: "허리를 세우고 발판을 온전히 밟는 것이 엉덩이 자극의 핵심입니다.",
                formCues: ["발판에 발의 앞 2/3 이상을 올리세요",
                           "손잡이는 균형만 살짝 — 체중은 다리로",
                           "뒤꿈치로 발판을 눌러 엉덩이 힘으로 오르기"],
                mistakes: ["손잡이에 체중을 실어 매달리는 것",
                           "상체를 숙여 허리에 부담을 주는 것"],
                tempo: "속도보다 자세 — 천천히 꾸준히 10~20분",
                rest: "숨이 너무 차면 속도를 한 단계 낮춰 회복")
        }
        if has("jump", "jumps", "hops", "skater") {
            return WorkoutAdvice(
                summary: "착지가 전부입니다 — 무릎을 굽혀 소리 없이 내려앉으세요.",
                formCues: ["무릎과 발끝 방향을 맞춰 착지하세요",
                           "발 앞쪽 → 뒤꿈치 순으로 부드럽게 닿기",
                           "착지하며 엉덩이를 뒤로 빼 충격 흡수"],
                mistakes: ["무릎이 안쪽으로 모이며 착지하는 것",
                           "쿵 소리가 나는 딱딱한 착지"],
                tempo: "정확한 착지가 유지되는 횟수까지만",
                rest: "세트 간 60~90초, 폼이 무너지면 즉시 휴식")
        }
        return WorkoutAdvice(
            summary: "숨이 차지만 대화는 가능한 강도가 지방 연소에 가장 효율적입니다.",
            formCues: ["시작 5분은 낮은 강도로 몸을 데우세요",
                       "코로 마시고 입으로 내쉬는 리듬을 일정하게",
                       "마지막 5분은 강도를 낮춰 심박을 서서히 내리기"],
            mistakes: ["처음부터 전력으로 시작해 금방 지치는 것",
                       "호흡을 참거나 불규칙하게 쉬는 것"],
            tempo: "초보자는 20~30분, 대화 가능한 속도 유지",
            rest: "인터벌 시 심박이 안정될 때까지 1~2분 걷기")
    }

    // MARK: 웨이트 조언 (구체 동작 → 부위 기본 순으로 매칭)
    private static func weightAdvice(_ pe: PlannedExercise, _ w: Set<String>) -> WorkoutAdvice {
        var a = base(pe.bodyPart)
        func has(_ ss: String...) -> Bool { hit(w, ss) }
        let part = pe.bodyPart

        // --- 하체 ---
        if has("romanian", "stiff", "morning") {
            a.summary = "무릎은 살짝만 굽히고 엉덩이를 뒤로 밀어 허벅지 뒤를 늘이는 운동입니다."
            a.formCues = ["바(무게)를 허벅지에 붙인 채 엉덩이를 뒤로 미세요",
                          "허벅지 뒤가 당기는 지점까지만 내리기 — 더 내리면 허리가 말립니다",
                          "등은 곧게, 시선은 전방 아래"]
            a.mistakes = ["허리를 굽혀 내려가는 것 (엉덩이를 밀어야 함)",
                          "바가 몸에서 멀어지는 것",
                          "무릎을 너무 굽혀 일반 데드리프트가 되는 것"]
            a.tempo = "내릴 때 3초 천천히, 올릴 때 1초"
            a.rest = "세트 간 90초~2분"
        } else if has("deadlift", "deadlifts") {
            a.summary = "바닥의 무게를 엉덩이 힘으로 드는 전신 운동 — 허리가 아닌 엉덩이로 듭니다."
            a.formCues = ["바를 발 중앙 위, 정강이에 닿을 듯 가깝게 두세요",
                          "가슴을 펴고 등을 곧게 고정한 뒤 시작",
                          "바닥을 발로 밀어낸다는 느낌으로 일어서기"]
            a.mistakes = ["허리가 둥글게 말리는 것 (부상 1순위)",
                          "바가 몸에서 멀어져 허리로 버티는 것",
                          "일어선 뒤 허리를 과하게 뒤로 젖히는 것"]
            a.tempo = "올릴 때 1초, 내릴 때 2초 통제"
            a.rest = "고중량 전신 운동 — 세트 간 2~3분 충분히"
        } else if has("calf", "calve", "calves") {
            a.summary = "종아리는 지구력이 좋은 근육이라 가동범위 끝까지 쥐어짜야 자랍니다."
            a.formCues = ["최대한 높이 올라가 1~2초 정지하세요",
                          "내릴 땐 뒤꿈치가 발판 아래로 내려가 쭉 늘어나게",
                          "무릎은 곧게 펴거나(스탠딩) 고정(시티드)"]
            a.mistakes = ["반동으로 통통 튀듯 하는 것",
                          "가동범위를 절반만 쓰는 것"]
            a.tempo = "올릴 때 1초, 정점 1~2초 정지, 내릴 때 2초"
            a.rest = "세트 간 45~60초, 15~20회 고반복이 효과적"
        } else if has("thrust", "thrusts", "bridge") {
            a.summary = "엉덩이 힘만으로 밀어 올리는 둔근 최고의 운동입니다."
            a.formCues = ["날개뼈 아래를 벤치에 대고 턱은 살짝 당기세요",
                          "뒤꿈치로 바닥을 눌러 엉덩이를 들어올리기",
                          "정점에서 무릎~어깨가 일직선, 엉덩이를 1초 꽉 조이기"]
            a.mistakes = ["허리를 젖혀서 올리는 것 (엉덩이 힘으로만)",
                          "발이 너무 멀어 허벅지 뒤 운동이 되는 것"]
            a.tempo = "올릴 때 1초, 정점 1초 조이기, 내릴 때 2초"
            a.rest = "세트 간 90초~2분"
        } else if has("curl", "curls") && part == .lower {
            a.summary = "허벅지 뒤(햄스트링)를 고립하는 운동 — 엉덩이가 뜨지 않게 하세요."
            a.formCues = ["골반을 패드에 단단히 붙이고 시작하세요",
                          "뒤꿈치를 엉덩이 쪽으로 끝까지 당기기",
                          "내릴 땐 다리가 완전히 펴지기 직전까지 천천히"]
            a.mistakes = ["엉덩이가 들리며 반동을 쓰는 것",
                          "가동범위 절반만 쓰는 것"]
            a.tempo = "당길 때 1초, 내릴 때 2~3초"
            a.rest = "세트 간 60~90초"
        } else if has("extension", "extensions") && part == .lower {
            a.summary = "허벅지 앞만 고립하는 운동 — 하체 마무리에 좋습니다."
            a.formCues = ["무릎 관절과 기계 회전축을 일치시키세요",
                          "다리를 끝까지 펴고 정점에서 1초 정지",
                          "내릴 때 무게에 저항하며 천천히"]
            a.mistakes = ["반동으로 차올리는 것",
                          "무게판이 쿵 닿도록 툭 내리는 것"]
            a.tempo = "올릴 때 1초, 정지 1초, 내릴 때 2초"
            a.rest = "세트 간 60~90초"
        } else if has("hack") || (has("press") && part == .lower) {
            a.summary = "허리 부담 없이 하체를 고중량으로 단련하는 머신 운동입니다."
            a.formCues = ["엉덩이와 허리를 시트에 완전히 밀착하세요",
                          "무릎이 90도 근처까지만 내리기",
                          "무릎을 끝까지 펴 잠그지 말고 살짝 남기기"]
            a.mistakes = ["너무 깊이 내려 엉덩이가 시트에서 뜨는 것 (허리 부상 위험)",
                          "무릎을 쭉 펴서 잠그는 것",
                          "발끝으로만 미는 것 — 발바닥 전체로"]
            a.tempo = "내릴 때 2초, 밀 때 1초"
            a.rest = "세트 간 90초~2분"
        } else if has("lunge", "lunges", "split", "bulgarian") {
            a.summary = "한 다리씩 단련하는 하체 균형 운동 — 무릎과 발끝 방향을 맞추는 게 핵심입니다."
            a.formCues = ["상체를 세우고 코어에 힘을 주세요",
                          "뒤 무릎을 바닥 가까이 내리며 앞 정강이는 자연스럽게 앞으로",
                          "앞 발바닥 전체로 바닥을 밀며 올라오기"]
            a.mistakes = ["무릎이 안쪽으로 무너지는 것 (발끝 방향과 어긋남)",
                          "상체가 앞으로 무너지는 것"]
            a.tempo = "내릴 때 2초, 올릴 때 1초"
            a.rest = "양쪽 모두 끝낸 후 90초"
        } else if has("squat", "squats", "squatting") {
            a.summary = "의자에 앉듯 엉덩이를 뒤로 빼며 앉는 하체 운동의 왕입니다."
            a.formCues = ["발은 어깨너비, 발끝은 15도 정도 바깥으로",
                          "무릎이 발끝과 같은 방향을 보게 벌리며 앉으세요",
                          "발바닥 전체로 바닥을 밀며 일어나기"]
            a.mistakes = ["무릎이 안쪽으로 모이는 것",
                          "뒤꿈치가 뜨는 것",
                          "허리가 말린 채 깊이 앉는 것"]
            a.tempo = "3초에 앉고 1초에 일어나기"
            a.rest = "세트 간 2~3분"
        }
        // --- 가슴 (플라이를 인클라인·프레스보다 먼저 체크) ---
        else if has("fly", "flye", "flyes", "crossover", "crossovers", "butterfly") {
            a.summary = "팔을 크게 벌렸다 모으며 가슴을 늘이고 조이는 운동입니다."
            a.formCues = ["팔꿈치를 살짝 굽힌 각도로 끝까지 고정하세요",
                          "가슴이 늘어나는 걸 느끼며 크게 벌리기",
                          "팔이 아닌 가슴 힘으로 모으고, 모은 지점에서 1초 조이기"]
            a.mistakes = ["팔꿈치를 굽혔다 펴며 프레스처럼 미는 것",
                          "너무 무거워 어깨가 앞으로 말리는 것"]
            a.tempo = "벌릴 때 2~3초, 모을 때 1초"
            a.rest = "세트 간 60~90초"
        } else if has("dip", "dips") {
            a.summary = "상체를 숙이면 가슴, 세우면 삼두 — 목적에 맞게 기울이세요."
            a.formCues = ["어깨를 아래로 눌러 고정하세요 (으쓱 금지)",
                          "팔꿈치가 90도가 될 때까지만 내리기",
                          "가슴이 목적이면 상체를 앞으로 15~30도 기울이기"]
            a.mistakes = ["너무 깊이 내려가 어깨 앞쪽이 아픈 것",
                          "어깨가 귀 쪽으로 솟는 것"]
            a.tempo = "내릴 때 2초, 올릴 때 1초"
            a.rest = "세트 간 90초~2분"
        } else if has("incline") && part == .chest {
            a.summary = "윗가슴을 채우는 30~45도 각도의 프레스입니다."
            a.formCues = ["벤치 각도는 30~45도 — 더 세우면 어깨 운동이 됩니다",
                          "무게를 쇄골 위쪽으로 수직으로 미세요",
                          "날개뼈를 모아 어깨를 벤치에 고정"]
            a.mistakes = ["각도를 60도 이상 세우는 것",
                          "팔꿈치를 옆으로 활짝 벌리는 것"]
            a.tempo = "내릴 때 2초, 밀 때 1초"
            a.rest = "세트 간 90초~2분"
        } else if has("decline") && part == .chest {
            a.summary = "아랫가슴 라인을 만드는 하향 각도 프레스입니다."
            a.formCues = ["무게를 아랫가슴(명치 아래) 라인으로 내리세요",
                          "날개뼈를 모아 고정, 팔꿈치는 몸통과 45~70도",
                          "밀어 올린 정점에서 가슴 아래를 조이기"]
            a.mistakes = ["무게를 목 쪽으로 내리는 것",
                          "가동범위를 절반만 쓰는 것"]
            a.tempo = "내릴 때 2초, 밀 때 1초"
            a.rest = "세트 간 90초~2분"
        } else if has("bench") || (has("press") && part == .chest) {
            a.summary = "가슴·어깨·삼두를 함께 쓰는 상체 대표 운동입니다."
            a.formCues = ["날개뼈를 모아 벤치에 고정하고 가슴을 살짝 여세요",
                          "무게를 젖꼭지 라인으로 내리기",
                          "팔꿈치는 몸통과 45~75도 — 활짝 벌리지 않기"]
            a.mistakes = ["엉덩이를 벤치에서 떼는 것",
                          "무게를 목 쪽으로 내리는 것",
                          "손목이 뒤로 꺾이는 것"]
            a.tempo = "내릴 때 2초, 가슴에 살짝 닿으면 1초에 밀기"
            a.rest = "세트 간 90초~2분"
        }
        // --- 등 ---
        else if has("pullover") {
            a.summary = "팔을 머리 뒤로 넘겨 광배를 길게 늘였다 당기는 운동입니다."
            a.formCues = ["팔꿈치를 살짝 굽힌 각도로 고정하세요",
                          "겨드랑이 아래가 늘어나는 지점까지만 넘기기",
                          "가슴 위까지 등 힘으로 당겨오기"]
            a.mistakes = ["팔꿈치를 굽혔다 펴며 삼두를 쓰는 것",
                          "허리를 과하게 젖히는 것"]
            a.tempo = "넘길 때 2초, 당길 때 1초"
            a.rest = "세트 간 60~90초"
        } else if has("shrug", "shrugs") {
            a.summary = "어깨를 귀 쪽으로 수직으로 으쓱 — 승모근 상부 운동입니다."
            a.formCues = ["팔은 편 채 어깨만 수직으로 들어올리세요",
                          "정점에서 1초 정지 후 천천히 내리기",
                          "턱을 살짝 당겨 목 중립 유지"]
            a.mistakes = ["어깨를 앞뒤로 돌리는 것 (회전은 불필요하고 위험)",
                          "반동으로 튕기는 것"]
            a.tempo = "올릴 때 1초, 정지 1초, 내릴 때 2초"
            a.rest = "세트 간 60~90초"
        } else if has("pulldown", "pulldowns", "pullup", "chinup", "chin") || (has("pull") && has("up")) {
            a.summary = "위에서 아래로 당겨 등 넓이를 만드는 운동 — 팔이 아닌 등으로 당깁니다."
            a.formCues = ["가슴을 들고 어깨를 아래로 내리며 시작하세요",
                          "팔꿈치를 갈비뼈 쪽으로 당긴다는 느낌으로",
                          "바가 쇄골 근처에 올 때 등을 꽉 조이기"]
            a.mistakes = ["몸을 뒤로 크게 젖혀 반동을 쓰는 것",
                          "팔 힘으로만 당기는 것"]
            a.tempo = "당길 때 1~2초, 되돌릴 때 2~3초 통제"
            a.rest = "세트 간 90초~2분"
        } else if has("row", "rows") {
            a.summary = "수평으로 당겨 등 두께를 만드는 운동입니다."
            a.formCues = ["허리를 곧게 펴고 상체 각도를 고정하세요",
                          "날개뼈를 먼저 모은 뒤 팔꿈치를 뒤로 당기기",
                          "당긴 정점에서 등을 1초 조이기"]
            a.mistakes = ["상체를 들썩이며 반동을 주는 것",
                          "어깨가 앞으로 말린 채 당기는 것"]
            a.tempo = "당길 때 1초, 되돌릴 때 2초"
            a.rest = "세트 간 90초~2분"
        }
        // --- 어깨 (후면 → 측면 → 전면 → 프레스 순) ---
        else if (has("face") && has("pull")) || has("rear") || (has("reverse") && has("fly", "flye", "flyes")) {
            a.summary = "어깨 뒤쪽을 채우는 운동 — 굽은 어깨를 펴는 데도 최고입니다."
            a.formCues = ["팔꿈치를 어깨 높이로 유지하며 당기세요",
                          "정점에서 날개뼈를 모으며 1초 조이기",
                          "가벼운 무게로 정확하게 — 무게 욕심 금지"]
            a.mistakes = ["무거운 무게로 허리 반동을 쓰는 것",
                          "팔꿈치가 아래로 처져 등 운동이 되는 것"]
            a.tempo = "당길 때 1초, 되돌릴 때 2초"
            a.rest = "세트 간 60초"
        } else if has("lateral", "laterals", "side") && part == .shoulder {
            a.summary = "어깨 옆을 넓히는 대표 운동 — 무게보다 궤적이 중요합니다."
            a.formCues = ["팔꿈치를 살짝 굽힌 채 고정하고 옆으로 들어올리세요",
                          "어깨 높이까지만 — 그 이상은 승모근이 가져갑니다",
                          "팔꿈치가 손보다 먼저 올라간다는 느낌으로"]
            a.mistakes = ["반동으로 튕겨 올리는 것",
                          "어깨가 으쓱 솟은 채 드는 것"]
            a.tempo = "올릴 때 1초, 내릴 때 2~3초 버티며 저항"
            a.rest = "고립 운동이라 세트 간 60~90초면 충분"
        } else if has("front") && has("raise", "raises") {
            a.summary = "어깨 앞을 고립하는 운동 — 프레스를 한다면 보조로 충분합니다."
            a.formCues = ["팔꿈치를 살짝 굽혀 어깨 높이까지만 올리세요",
                          "몸통을 고정하고 어깨 힘으로만",
                          "내릴 때 천천히 저항하며 내리기"]
            a.mistakes = ["몸을 뒤로 흔들며 반동을 쓰는 것",
                          "어깨 높이 이상 올려 승모근이 개입하는 것"]
            a.tempo = "올릴 때 1초, 내릴 때 2초"
            a.rest = "세트 간 60~90초"
        } else if has("overhead", "military", "arnold") || (has("shoulder") && has("press")) || (has("press") && part == .shoulder) {
            a.summary = "머리 위로 미는 어깨 대표 복합 운동입니다."
            a.formCues = ["배와 엉덩이에 힘을 줘 몸통을 기둥처럼 고정하세요",
                          "턱 앞에서 시작해 귀 옆 일직선으로 밀어 올리기",
                          "정점에서 팔꿈치를 완전히 펴고 어깨로 지탱"]
            a.mistakes = ["허리를 뒤로 젖혀 가슴으로 미는 것",
                          "팔꿈치가 과하게 앞으로 나오는 것"]
            a.tempo = "밀 때 1초, 내릴 때 2초 통제"
            a.rest = "세트 간 90초~2분"
        }
        // --- 팔 ---
        else if has("curl", "curls") && part == .biceps {
            a.summary = "팔꿈치를 고정하고 이두로만 들어올리는 팔 운동입니다."
            a.formCues = ["팔꿈치를 몸통 옆에 붙여 고정하세요",
                          "손목은 곧게 — 꺾이면 힘이 새고 손목이 아픕니다",
                          "정점에서 1초 조이고, 내릴 때 저항하며 천천히"]
            a.mistakes = ["몸을 흔들어 반동으로 드는 것",
                          "팔꿈치가 앞뒤로 움직이는 것",
                          "다 내리지 않고 절반만 쓰는 것"]
            a.tempo = "올릴 때 1초, 내릴 때 2~3초 버티기"
            a.rest = "세트 간 60~90초"
        } else if has("pushdown", "kickback", "skullcrusher", "crusher", "extension", "extensions", "french") && part == .triceps {
            a.summary = "위팔을 고정하고 팔꿈치만 펴서 삼두를 조이는 운동입니다."
            a.formCues = ["팔꿈치를 몸통 옆에 붙여 고정하세요",
                          "위팔은 그대로, 아래팔만 움직이기",
                          "끝까지 펴서 삼두를 완전히 수축"]
            a.mistakes = ["팔꿈치가 벌어지거나 앞뒤로 움직이는 것",
                          "상체를 숙이며 체중으로 누르는 것"]
            a.tempo = "펼 때 1초, 되돌릴 때 2초"
            a.rest = "세트 간 60~90초"
        }
        a.variation = variationNote(w, part)
        return a
    }

    // MARK: 변형(그립·각도·자세·기구) 차이 설명 — 같은 동작의 다른 변형과 뭐가 다른지 (최대 2개)
    private static func variationNote(_ w: Set<String>, _ part: BodyPart?) -> String? {
        func has(_ ss: String...) -> Bool { hit(w, ss) }
        var notes: [String] = []

        // --- 이두 컬 변형 ---
        if part == .biceps {
            if has("hammer") {
                notes.append("해머(중립) 그립: 일반 컬이 이두 전체를 쓴다면, 해머컬은 이두 옆 근육(상완근·전완)을 타겟해 팔의 측면 두께를 만듭니다.")
            }
            if has("incline") {
                notes.append("인클라인 컬: 벤치에 기대면 팔이 몸 뒤로 처져 이두가 최대로 늘어난 상태에서 시작 — 이두 바깥쪽(장두) 자극이 가장 큰 컬입니다.")
            }
            if has("preacher") {
                notes.append("프리처(패드) 컬: 팔을 패드에 고정해 반동을 원천 차단 — 이두 안쪽(단두)과 아랫부분에 집중됩니다.")
            }
            if has("concentration") {
                notes.append("컨센트레이션 컬: 팔꿈치를 허벅지에 고정해 고립도가 가장 높은 컬 — 이두 봉우리를 만드는 데 좋습니다.")
            }
            if has("spider") {
                notes.append("스파이더 컬: 팔이 수직으로 늘어진 채 시작해 수축 구간 자극이 극대화됩니다.")
            }
            if has("drag") {
                notes.append("드래그 컬: 바를 몸에 붙여 끌어올리듯 — 어깨 개입 없이 이두만 씁니다.")
            }
            if has("zottman") {
                notes.append("지트만 컬: 올릴 땐 일반 컬, 내릴 땐 리버스 그립 — 이두와 전완을 한 번에 잡습니다.")
            }
            if has("reverse") {
                notes.append("리버스(오버핸드) 그립: 이두보다 전완과 팔뚝 바깥 근육을 타겟 — 팔뚝 두께용입니다.")
            }
        }
        // --- 가슴 그립 변형 ---
        if part == .chest {
            if has("wide") {
                notes.append("와이드 그립: 가슴 바깥쪽 자극이 커지지만 어깨 부담도 커집니다 — 어깨너비 1.5배까지만.")
            }
            if has("close", "narrow") {
                notes.append("클로즈(좁은) 그립: 삼두와 가슴 안쪽 개입이 커져 삼두 운동에 가깝습니다.")
            }
        }
        // --- 등 그립 변형 ---
        if part == .back {
            if has("wide") {
                notes.append("와이드 그립: 등의 '넓이'(광배 바깥쪽)를 만드는 그립입니다.")
            }
            if has("close", "narrow", "underhand", "reverse") {
                notes.append("좁은·언더핸드 그립: 이두가 함께 쓰이고 광배 아래쪽 자극이 커집니다 — 등 두께에 유리.")
            }
        }
        // --- 어깨 변형 ---
        if part == .shoulder {
            if has("arnold") {
                notes.append("아놀드 프레스: 손목을 돌리며 밀어 어깨 앞·옆을 동시에 자극하는 변형입니다.")
            }
            if has("behind") && has("neck") {
                notes.append("비하인드 넥: 어깨 유연성이 부족하면 부상 위험이 큽니다 — 초보자는 앞으로 내리는 프레스를 권합니다.")
            }
        }
        // --- 삼두 변형 ---
        if part == .triceps {
            if has("overhead") {
                notes.append("오버헤드(머리 위) 방식: 삼두에서 가장 큰 갈래(장두)가 늘어난 채 일해 삼두 전체 크기에 가장 좋습니다.")
            }
            if has("rope") {
                notes.append("로프 손잡이: 끝에서 바깥으로 벌릴 수 있어 삼두를 끝까지 쥐어짤 수 있습니다.")
            }
        }
        // --- 하체 스탠스·자세 변형 ---
        if part == .lower {
            if has("sumo") {
                notes.append("스모(넓은 발) 스탠스: 허벅지 안쪽·엉덩이 비중이 커지고 허리 부담은 줄어듭니다.")
            }
            if has("front") && has("squat", "squats") {
                notes.append("프론트 스쿼트: 무게가 앞에 있어 상체가 세워집니다 — 허벅지 앞 집중도↑, 허리 부담↓.")
            }
            if has("goblet") {
                notes.append("고블릿(가슴 앞 덤벨) 스쿼트: 자세가 무너지기 어려워 초보자에게 가장 좋은 스쿼트 입문입니다.")
            }
        }
        // --- 자세 공통 ---
        if has("seated") {
            notes.append("시티드(앉은) 자세: 반동이 차단돼 목표 근육에 더 정직하게 자극이 갑니다.")
        }
        if has("single", "one") {
            notes.append("원암·싱글(한쪽씩): 좌우 근력 차이를 교정하고 한쪽에 온전히 집중할 수 있습니다.")
        }
        if has("alternate", "alternating") {
            notes.append("얼터네이트(번갈아): 반동이 줄고 한쪽씩 집중할 수 있습니다.")
        }
        // --- 기구 (가장 낮은 우선순위, 1개만) ---
        if has("ez") {
            notes.append("이지바(굽은 바): 손목 각도가 편해 손목·팔꿈치 부담을 줄여줍니다.")
        } else if has("smith") {
            notes.append("스미스 머신: 바 궤적이 고정돼 안전하게 배우기 좋습니다 — 익숙해지면 프리웨이트로.")
        } else if has("machine", "lever") {
            notes.append("머신: 궤적이 고정돼 안전 — 초보자가 자극에만 집중하기 좋습니다.")
        } else if has("cable") {
            notes.append("케이블: 동작 내내 장력이 유지돼 자극이 끊기지 않는 게 최대 장점입니다.")
        } else if has("dumbbell", "dumbbells", "db") {
            notes.append("덤벨: 좌우가 따로 움직여 근력 불균형 교정 + 가동범위가 넓은 게 장점입니다.")
        } else if has("barbell") {
            notes.append("바벨: 가장 무거운 무게를 다룰 수 있어 근력을 키우기에 가장 유리합니다.")
        } else if has("band") {
            notes.append("밴드: 늘어날수록 저항이 커져 수축 구간을 강하게 조입니다.")
        } else if has("kettlebell") {
            notes.append("케틀벨: 무게중심이 손 밖에 있어 코어와 안정근이 함께 단련됩니다.")
        }

        return notes.isEmpty ? nil : notes.prefix(2).joined(separator: "\n")
    }

    private static func base(_ part: BodyPart?) -> WorkoutAdvice {
        switch part {
        case .chest:
            WorkoutAdvice(summary: "날개뼈를 고정하고 가슴 힘으로 미세요.",
                formCues: ["날개뼈를 뒤로 모아 고정", "팔꿈치는 몸통과 45~75도 유지",
                           "가슴 근육이 늘었다 조이는 걸 느끼며"],
                mistakes: ["어깨가 앞으로 말리는 것", "가동범위를 좁게 쓰는 것"],
                tempo: "내릴 때 2초, 밀 때 1초", rest: "세트 간 90초~2분")
        case .back:
            WorkoutAdvice(summary: "팔이 아닌 등으로 당기세요.",
                formCues: ["날개뼈를 먼저 모으고 당기기", "팔꿈치를 뒤·아래로 보내기",
                           "당긴 정점에서 등을 1초 조이기"],
                mistakes: ["팔 힘으로만 당기는 것", "반동을 쓰는 것"],
                tempo: "당길 때 1초, 되돌릴 때 2~3초", rest: "세트 간 90초~2분")
        case .shoulder:
            WorkoutAdvice(summary: "무게보다 자세 — 승모근 개입을 줄이세요.",
                formCues: ["어깨를 아래로 내려 고정", "어깨 높이까지만 들기",
                           "배에 힘을 줘 반동 억제"],
                mistakes: ["반동으로 들어올리는 것", "무게 욕심에 승모근으로 드는 것"],
                tempo: "올릴 때 1초, 내릴 때 2~3초", rest: "세트 간 60~90초")
        case .biceps:
            WorkoutAdvice(summary: "팔꿈치를 고정하고 천천히 내리세요.",
                formCues: ["팔꿈치를 몸통 옆에 고정", "손목은 곧게",
                           "정점에서 최대 수축"],
                mistakes: ["반동으로 어깨를 쓰는 것", "빠르게 툭 내리는 것"],
                tempo: "올릴 때 1초, 내릴 때 2~3초 버티기", rest: "세트 간 60~90초")
        case .triceps:
            WorkoutAdvice(summary: "팔꿈치를 붙이고 끝까지 펴세요.",
                formCues: ["팔꿈치를 몸에 붙여 고정", "아래팔만 움직이기",
                           "완전히 펴서 삼두 수축"],
                mistakes: ["팔꿈치가 벌어지는 것", "상체 반동을 쓰는 것"],
                tempo: "펼 때 1초, 되돌릴 때 2초", rest: "세트 간 60~90초")
        case .lower:
            WorkoutAdvice(summary: "무릎은 발끝 방향, 배에 힘, 허리는 곧게.",
                formCues: ["무릎이 발끝 방향을 따라가게", "뒤꿈치로 바닥을 밀기",
                           "배에 힘을 줘 허리를 곧게 유지"],
                mistakes: ["무릎이 안으로 모이는 것", "허리가 말리는 것"],
                tempo: "내릴 때 2~3초, 올릴 때 1초", rest: "세트 간 2~3분")
        default:
            WorkoutAdvice(summary: "일정한 호흡과 통제된 동작을 유지하세요.",
                formCues: ["가동범위를 끝까지 사용", "반동 없이 통제된 속도로",
                           "목표 근육에 집중"],
                mistakes: ["반동을 쓰는 것", "호흡을 멈추는 것"],
                tempo: "올릴 때 1초, 내릴 때 2초", rest: "세트 간 60~90초")
        }
    }
}

// MARK: - 근육 자극 매핑 (앱 + 위젯 공용)
/// 부위 + 세부부위 조합 키. sub == nil 이면 부위 전체(집계) 또는 세부 구분 없는 부위(이두·삼두).
struct MuscleRegion: Hashable {
    let part: BodyPart
    let sub: String?
    var label: String { sub.map { "\(part.rawValue) \($0)" } ?? part.rawValue }
}

/// 운동 → 자극 부위 목록. 주동근 1.0 + 협응근 가중치(0.2~0.6).
/// 예: 벤치프레스 = 가슴 중부 1.0 + 삼두 0.5 + 어깨 전면 0.3,
///     인클라인 프레스 = 가슴 상부 1.0 + 어깨 전면 0.5 + 삼두 0.5.
/// ⚠️ AICoach와 동일하게 id+표시이름(한글 음차) 단어 매칭 사용.
enum MuscleMap {
    static func stimuli(for pe: PlannedExercise) -> [(region: MuscleRegion, factor: Double)] {
        guard let part = pe.bodyPart else { return [] }
        let w = Set((pe.exerciseID + " " + pe.name).lowercased()
            .split(whereSeparator: { !$0.isLetter }).map(String.init))
        func has(_ ss: String...) -> Bool { AICoach.hit(w, ss) }

        var out: [(MuscleRegion, Double)] = []
        func add(_ p: BodyPart, _ s: String?, _ f: Double) {
            out.append((MuscleRegion(part: p, sub: s), f))
        }

        switch part {
        case .cardio:
            add(.cardio, nil, 1.0)
        case .chest:
            let sub = has("incline") ? "상부" : has("decline") ? "하부" : "중부"
            add(.chest, sub, 1.0)
            if has("press", "presses", "bench", "dip", "dips", "push", "pushup") {
                add(.triceps, nil, 0.5)                              // 미는 동작 → 삼두 협응
                add(.shoulder, "전면", sub == "상부" ? 0.5 : 0.3)     // 상부 자극 시 전면어깨 개입↑
            } else {
                add(.shoulder, "전면", 0.2)                          // 플라이 계열도 전면어깨 소폭
            }
        case .back:
            if has("shrug", "shrugs") {
                add(.back, "승모", 1.0)
            } else if has("deadlift", "deadlifts", "romanian", "stiff", "morning", "hyperextension") {
                add(.back, "하부", 1.0)                              // 힙 힌지 계열
                add(.lower, "햄스트링", 0.6)
                add(.lower, "둔근", 0.5)
                add(.back, "승모", 0.3)
            } else {
                add(.back, "광배", 1.0)                              // 풀다운/풀업/로우/풀오버
                add(.biceps, nil, 0.4)                               // 당기는 동작 → 이두 협응
                if has("row", "rows") {
                    add(.shoulder, "후면", 0.3)
                    add(.back, "승모", 0.3)
                }
            }
        case .shoulder:
            let sub = (has("rear") || (has("face") && has("pull")) || (has("reverse") && has("fly", "flye", "flyes"))) ? "후면"
                    : has("lateral", "laterals", "side", "upright") ? "측면" : "전면"
            add(.shoulder, sub, 1.0)
            if has("press", "presses", "overhead", "military", "arnold") {
                add(.triceps, nil, 0.4)                              // 프레스 → 삼두 협응
                add(.chest, "상부", 0.2)
            }
            if sub == "후면" { add(.back, "승모", 0.2) }
            if has("upright") { add(.back, "승모", 0.4) }            // 업라이트 로우 → 승모 개입 큼
        case .biceps:
            add(.biceps, nil, 1.0)
        case .triceps:
            add(.triceps, nil, 1.0)
            if has("dip", "dips") || (has("close") && has("bench", "press")) {
                add(.chest, "하부", 0.3)                             // 딥스/클로즈 벤치 → 가슴 협응
                add(.shoulder, "전면", 0.2)
            }
        case .lower:
            if has("calf", "calve", "calves") {
                add(.lower, "종아리", 1.0)
            } else if has("curl", "curls", "romanian", "stiff", "morning") {
                add(.lower, "햄스트링", 1.0)
                if has("romanian", "stiff", "morning") {
                    add(.lower, "둔근", 0.4)
                    add(.back, "하부", 0.3)
                }
            } else if has("thrust", "thrusts", "glute", "bridge") {
                add(.lower, "둔근", 1.0)
                add(.lower, "햄스트링", 0.4)
            } else {
                add(.lower, "대퇴", 1.0)                             // 스쿼트/레그프레스/런지/익스텐션
                if !has("extension", "extensions") {                 // 익스텐션은 대퇴 고립
                    add(.lower, "둔근", 0.5)
                    add(.lower, "햄스트링", 0.2)
                }
                if has("squat", "squats", "deadlift") { add(.back, "하부", 0.25) }
            }
        }
        return out
    }
}

// MARK: - 부위별 피로도 & 근 회복 모델 (앱 + 위젯 공용)
// 근거(2026-07 문헌 재검토 반영):
//  · 근단백질 합성(MPS)은 운동 후 ~24h 정점 → 36~48h에 기저치 복귀. 지연성근육통(DOMS)은
//    24~72h에 정점 후 5~7일에 소멸. 이 앱의 "피로도"는 재훈련 준비도(readiness) 지표이므로,
//    운동 직후 최대 → 회복될수록 감소하는 지수 감쇠로 모델링(대다수 근육맵 앱과 동일한 접근).
//  · 재훈련 간격: 대근육(등·하체) 48~72h, 중간(가슴·어깨) 48h, 소근육(이두·삼두) 24~48h.
//    (ACSM/NSCA 가이드라인 + 트레이닝 볼륨 연구와 일치 — 아래 시간 상수가 이 범위 안에 있음.)
//  · 자극량은 세트 수 기반(주당 유효 볼륨 MEV 4~8 / MAV 10~20 세트 문헌과 정합). 세션당 ≈10세트를
//    1회 최대 자극으로 포화시키며, 협응근은 MuscleMap 가중치(0.2~0.6)로 부분 반영.
enum Fatigue {
    /// 부위별 "거의 완전회복(≈95%)"까지 걸리는 시간(시간). 근육 크기 기반.
    static func fullRecoveryHours(_ p: BodyPart) -> Double {
        switch p {
        case .lower:            72   // 하체(대근육) — 가장 느림
        case .back:             72   // 등(대근육)
        case .chest, .shoulder: 48   // 가슴·어깨(중간)
        case .biceps, .triceps: 40   // 이두·삼두(소근육) — 빠름
        case .cardio:           24   // 유산소 — 회복 가장 빠름
        }
    }

    /// 시간당 감쇠상수 k. exp(-k·T)=0.05(T시간 뒤 5% 잔여) → k = ln(20)/T ≈ 2.996/T
    static func decayK(_ p: BodyPart) -> Double { 2.9957 / fullRecoveryHours(p) }

    /// 세부부위 단위 피로도 0...1. `MuscleMap`으로 주동근+협응근 자극을 함께 누적.
    /// 반환 dict에는 세부 항목(예: 가슴·상부)과 부위 집계(sub == nil)가 모두 포함된다.
    static func regionLevels(_ records: [WorkoutRecord], now: Date = .now) -> [MuscleRegion: Double] {
        var acc: [MuscleRegion: Double] = [:]
        for r in records {
            let hours = now.timeIntervalSince(r.endedAt) / 3600
            guard hours >= 0, hours < 24 * 10 else { continue }   // 10일 지나면 잔여≈0
            for e in r.exercises {
                let sets = Double(e.sets.count)
                for (region, f) in MuscleMap.stimuli(for: e) {
                    let load = min(1.0, sets / 10.0) * f          // ≈10세트를 1회 최대 자극으로
                    let decayed = load * exp(-decayK(region.part) * hours)
                    acc[region, default: 0] += decayed
                    if region.sub != nil {                        // 부위 집계에도 합산
                        acc[MuscleRegion(part: region.part, sub: nil), default: 0] += decayed
                    }
                }
            }
        }
        return acc.mapValues { min(1.0, $0) }
    }

    /// 부위별 현재 피로도 0...1 (1=방금 훈련해 최대 피로, 0=완전 회복).
    /// 협응근 자극 포함 — 예: 벤치프레스는 가슴뿐 아니라 삼두·전면어깨 피로도에도 반영.
    static func levels(_ records: [WorkoutRecord], now: Date = .now) -> [(part: BodyPart, level: Double)] {
        let regions = regionLevels(records, now: now)
        return BodyPart.allCases.map {
            (part: $0, level: regions[MuscleRegion(part: $0, sub: nil)] ?? 0)
        }
    }

    /// 전체 피로도 0...100 (전 부위 평균)
    static func overall(_ records: [WorkoutRecord], now: Date = .now) -> Int {
        let ls = levels(records, now: now)
        let avg = ls.reduce(0) { $0 + $1.level } / Double(max(1, ls.count))
        return Int((avg * 100).rounded())
    }

    static func label(_ level: Double) -> String {
        switch level {
        case ..<0.15:  "회복됨"
        case ..<0.45:  "낮음"
        case ..<0.75:  "보통"
        default:       "높음"
        }
    }
}

// MARK: - App Group 공용 저장소 (앱 ↔ 위젯 데이터 공유)
enum SharedStore {
    /// ⚠️ Xcode의 App Group ID와 반드시 일치시켜야 함 (앱·위젯 두 타겟 모두)
    static let appGroup = "group.com.oddong.WorkoutApp"

    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static func url(_ name: String) -> URL { container.appendingPathComponent(name) }

    static func loadRecords() -> [WorkoutRecord] {
        guard let d = try? Data(contentsOf: url("records.json")) else { return [] }
        return (try? JSONDecoder().decode([WorkoutRecord].self, from: d)) ?? []
    }
}
