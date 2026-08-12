import SwiftUI
import Charts
import UniformTypeIdentifiers

// 추이 차트에 표시할 지표
enum InBodyMetric: String, CaseIterable, Identifiable {
    case weight = "체중", muscle = "골격근량", fatPercent = "체지방률"
    var id: String { rawValue }
    var unit: String { self == .fatPercent ? "%" : "kg" }
    func value(of r: InBodyRecord) -> Double? {
        switch self {
        case .weight: r.weight
        case .muscle: r.muscle
        case .fatPercent: r.fatPercent
        }
    }
}

struct InBodyView: View {
    @EnvironmentObject var store: DataStore
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var metric: InBodyMetric = .weight

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("인바디").font(.title.weight(.semibold)).foregroundStyle(Theme.orD)
                    if let last = store.inbody.last {
                        summaryCard(last)
                        if let advice = InBodyCoach.advice(store.inbody) { adviceCard(advice) }
                    } else {
                        emptyCard
                    }
                    if store.inbody.count >= 2 { trendCard }
                    uploadButton
                    if !store.inbody.isEmpty { historySection }
                }.padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text]) {
                handleImport($0)
            }
            .alert("인바디 가져오기",
                   isPresented: Binding(get: { importMessage != nil },
                                        set: { if !$0 { importMessage = nil } })) {
                Button("확인") { importMessage = nil }
            } message: { Text(importMessage ?? "") }
        }
    }

    // MARK: 최근 측정 요약 (직전 대비 증감 포함)
    private func summaryCard(_ last: InBodyRecord) -> some View {
        let prev = store.inbody.dropLast().last
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 측정").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                Spacer()
                Text(last.date, format: .dateTime.year().month().day())
                    .font(.caption).foregroundStyle(Theme.sub)
            }
            HStack(spacing: 8) {
                summaryStat("체중", last.weight, prev?.weight, "kg", upIsGood: false)
                summaryStat("골격근량", last.muscle, prev?.muscle, "kg", upIsGood: true)
                summaryStat("체지방률", last.fatPercent, prev?.fatPercent, "%", upIsGood: false)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }
    private func summaryStat(_ label: String, _ value: Double?, _ prev: Double?,
                             _ unit: String, upIsGood: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
            Text(value.map { "\($0.formatted())\(unit)" } ?? "—")
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.orD)
            if let v = value, let p = prev, abs(v - p) >= 0.05 {
                let up = v > p
                let good = up == upIsGood
                Text("\(up ? "▲" : "▼") \(abs(v - p).formatted())")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(good ? Theme.or : Color(red: 0.85, green: 0.4, blue: 0.3))
            } else {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: AI 코치 — 체성분 변화 분석과 앞으로의 방향
    private func adviceCard(_ a: InBodyAdvice) -> some View {
        let toneColor: Color = switch a.tone {
        case .good: Theme.orD
        case .neutral: Theme.txt
        case .warn: Color(red: 0.85, green: 0.55, blue: 0.15)
        case .bad: Color(red: 0.85, green: 0.4, blue: 0.3)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Theme.or)
                Text("AI 코치 — 앞으로의 방향").font(.caption.weight(.semibold)).foregroundStyle(Theme.or)
            }
            Text(a.headline).font(.footnote.weight(.semibold)).foregroundStyle(toneColor)
            if !a.analysis.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 변화").font(.caption2.weight(.semibold)).foregroundStyle(Theme.sub)
                    ForEach(a.analysis, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2).foregroundStyle(Theme.or).padding(.top, 2)
                            Text(item).font(.footnote).foregroundStyle(Theme.txt)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("추천 방향").font(.caption2.weight(.semibold)).foregroundStyle(Theme.sub)
                ForEach(a.actions, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2).foregroundStyle(toneColor).padding(.top, 2)
                        Text(item).font(.footnote).foregroundStyle(Theme.txt)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.orL, in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "scalemass").font(.largeTitle).foregroundStyle(Theme.or)
            Text("아직 인바디 기록이 없어요.\n인바디 앱에서 내보낸 CSV 파일을 업로드해보세요.")
                .multilineTextAlignment(.center)
                .font(.footnote).foregroundStyle(Theme.sub)
            Text("인바디 앱 → 헬스리포트 → 상세 → 가장 하단 \"데이터 내보내기\"\n→ 기간 전체 선택 후 내보내기")
                .multilineTextAlignment(.center)
                .font(.caption2).foregroundStyle(Theme.sub.opacity(0.8))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: 추이 차트
    private var trendCard: some View {
        let points = store.inbody.compactMap { r in
            metric.value(of: r).map { (date: r.date, value: $0) }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("추이").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.orD)
                Spacer()
                Picker("", selection: $metric) {
                    ForEach(InBodyMetric.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 210)
            }
            if points.count >= 2 {
                Chart(points, id: \.date) { p in
                    LineMark(x: .value("날짜", p.date), y: .value(metric.rawValue, p.value))
                        .foregroundStyle(Theme.or)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("날짜", p.date), y: .value(metric.rawValue, p.value))
                        .foregroundStyle(Theme.or)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
                } }
                .chartYAxis { AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.bd)
                    AxisValueLabel().font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.txt)
                } }
                .frame(height: 170)
            } else {
                Text("이 지표의 기록이 2개 이상 쌓이면 그래프가 그려져요.")
                    .font(.footnote).foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bd, lineWidth: 1))
        .cardShadow()
    }

    // MARK: CSV 업로드
    private var uploadButton: some View {
        Button { showImporter = true } label: {
            Label("인바디 CSV 업로드", systemImage: "square.and.arrow.down")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.or)
                .frame(maxWidth: .infinity).padding(12)
                .background(Theme.orL, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.or, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
    }
    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importMessage = "파일을 열 수 없어요."; return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importMessage = "파일을 읽을 수 없어요."; return
        }
        // 한국어 CSV는 UTF-8이 아닐 수 있어 EUC-KR 폴백
        let eucKR = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: eucKR) else {
            importMessage = "파일 인코딩을 읽을 수 없어요."; return
        }
        let parsed = InBodyRecord.parse(csv: text)
        guard !parsed.isEmpty else {
            importMessage = "인바디 데이터를 찾지 못했어요.\n인바디 앱에서 내보낸 CSV 파일이 맞는지 확인해주세요."
            return
        }
        let added = store.mergeInBody(parsed)
        let dup = parsed.count - added
        importMessage = added > 0
            ? (dup > 0 ? "새 기록 \(added)건을 추가했어요. (중복 \(dup)건 제외)"
                       : "새 기록 \(added)건을 추가했어요.")
            : "모두 이미 있는 기록이라 추가하지 않았어요. (중복 \(dup)건)"
    }

    // MARK: 측정 기록 목록 (최신순)
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("측정 기록").font(.footnote.weight(.medium)).foregroundStyle(Theme.or)
            ForEach(store.inbody.reversed()) { r in
                HStack(spacing: 10) {
                    Text(r.date, format: .dateTime.year(.twoDigits).month().day())
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.txt)
                        .frame(width: 76, alignment: .leading)
                    historyValue("체중", r.weight, "kg")
                    historyValue("골격근", r.muscle, "kg")
                    historyValue("체지방", r.fatPercent, "%")
                    Button { store.deleteInBody(r) } label: {
                        Image(systemName: "trash").font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.bd, lineWidth: 1))
            }
        }
    }
    private func historyValue(_ label: String, _ v: Double?, _ unit: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
            Text(v.map { "\($0.formatted())\(unit)" } ?? "—")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.orD)
        }
        .frame(maxWidth: .infinity)
    }
}
