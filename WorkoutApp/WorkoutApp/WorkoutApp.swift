import SwiftUI

@main
struct WorkoutApp: App {
    @StateObject private var store = DataStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().environmentObject(store)
                if showSplash {
                    SplashView { withAnimation(.easeOut(duration: 0.45)) { showSplash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.light)   // 다크모드 무시 — 항상 흰색/파란색 고정
        }
    }
}

// MARK: - 스플래시(앱 실행) 화면
// 흰 배경 중앙의 "워카웃" 글씨가 아래→위로 주황색으로 물든 뒤, 다 물들면 본 화면으로 전환.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var fill: CGFloat = 0      // 0(비어있음) → 1(완전히 주황)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ZStack {
                // 바탕(아직 안 물든) 글씨 — 은은한 그림자
                Text("워카웃")
                    .foregroundStyle(Color(white: 0.83))
                    .shadow(color: Theme.or.opacity(0.28), radius: 12, x: 0, y: 6)
                // 주황 글씨 — 아래에서부터 차오르는 마스크로 점점 드러남
                Text("워카웃")
                    .foregroundStyle(Theme.or)
                    .mask(alignment: .bottom) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(height: geo.size.height * fill)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
            }
            .font(.system(size: 39, weight: .bold, design: .rounded))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0)) { fill = 1 }
            // 다 물들면(약간의 여운 후) 종료
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { onFinish() }
        }
    }
}

struct RootView: View {
    init() {
        // 탭바: 스크롤해도 항상 동일한 배경 + 상단 구분선 유지
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.bg)
        tab.shadowColor = UIColor(Theme.bd)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some View {
        TabView {
            MainView().tabItem { Label("홈", systemImage: "dumbbell.fill") }
            StatsView().tabItem { Label("리포트", systemImage: "chart.bar.fill") }
            InBodyView().tabItem { Label("인바디", systemImage: "scalemass.fill") }
        }
        .tint(Theme.or)
        .fontDesign(.rounded)   // 앱 전체 심플한 라운드 서체
    }
}

enum Theme {
    // 메인: 흰색 + 연한 파란색 (이름은 유지, 값만 블루 계열로 교체)
    static let or   = Color(red: 0.30, green: 0.65, blue: 0.91)  // #4DA6E8 메인 블루
    static let orD  = Color(red: 0.18, green: 0.55, blue: 0.84)  // #2E8BD6 진한 블루(제목/그라데이션)
    static let orL  = Color(red: 0.92, green: 0.96, blue: 0.99)  // #EAF4FC 연한 블루 배경
    static let bd   = Color(red: 0.83, green: 0.91, blue: 0.97)  // #D3E7F7 테두리
    static let txt  = Color(red: 0.39, green: 0.44, blue: 0.49)  // #64717C 본문 텍스트(쿨그레이)
    static let sub  = Color(red: 0.61, green: 0.65, blue: 0.69)  // #9BA7B0 보조 텍스트
    static let bg   = Color(red: 0.98, green: 0.99, blue: 1.00)  // #FBFDFF 배경(살짝 블루 화이트)
    static let dark = Color(red: 0.13, green: 0.13, blue: 0.15)  // 레이더 카드 배경
}

extension View {
    /// 카드에 은은한 입체감을 주는 따뜻한 그림자
    func cardShadow(_ strong: Bool = false) -> some View {
        shadow(color: Theme.or.opacity(strong ? 0.22 : 0.10),
               radius: strong ? 12 : 9, x: 0, y: strong ? 6 : 4)
    }
    /// 키보드 위에 "완료" 버튼 툴바 — 숫자패드 등 어떤 키보드도 내릴 수 있게
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }.tint(Theme.or)
            }
        }
    }
}
