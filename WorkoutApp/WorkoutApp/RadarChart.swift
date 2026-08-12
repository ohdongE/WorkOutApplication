import SwiftUI

// 부위별 밸런스를 보여주는 레이더(방사형) 차트 — 라이트 테마
struct RadarChart: View {
    let data: [(label: String, value: Double)]   // value 0...1
    var accent: Color = Theme.or
    var grid: Color = Theme.bd
    var labelColor: Color = Theme.sub
    var valueColor: Color = Theme.txt

    private func angle(_ i: Int, _ n: Int) -> Double {
        -.pi / 2 + Double(i) * 2 * .pi / Double(n)   // 12시 방향에서 시계방향
    }
    private func point(_ center: CGPoint, _ radius: CGFloat, _ a: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(a)), y: center.y + radius * CGFloat(sin(a)))
    }
    private func polygon(_ center: CGPoint, _ radius: CGFloat, _ n: Int) -> Path {
        Path { p in
            for i in 0..<n {
                let pt = point(center, radius, angle(i, n))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
    /// 데이터 다각형 — 0%는 정확히 중심으로 (두번째 참고 이미지 스타일)
    private func dataPath(_ center: CGPoint, _ radius: CGFloat, _ n: Int) -> Path {
        Path { p in
            for i in 0..<n {
                let pt = point(center, radius * CGFloat(data[i].value), angle(i, n))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    var body: some View {
        GeometryReader { geo in
            let n = data.count
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2 - 52

            ZStack {
                // 동심 격자
                ForEach(1...4, id: \.self) { ring in
                    polygon(center, radius * CGFloat(ring) / 4, n)
                        .stroke(grid.opacity(0.6), lineWidth: 1)
                }
                // 축(스포크)
                Path { p in
                    for i in 0..<n {
                        p.move(to: center)
                        p.addLine(to: point(center, radius, angle(i, n)))
                    }
                }
                .stroke(grid.opacity(0.45), lineWidth: 1)

                // 데이터 영역 — 각진 다각형 + 평면 채움
                dataPath(center, radius, n).fill(accent.opacity(0.28))
                dataPath(center, radius, n)
                    .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                // 꼭짓점 라벨
                ForEach(0..<n, id: \.self) { i in
                    let lp = point(center, radius + 34, angle(i, n))
                    VStack(spacing: 1) {
                        Text(data[i].label)
                            .font(.caption).foregroundStyle(labelColor)
                        Text("\(Int((data[i].value * 100).rounded()))%")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(valueColor)
                    }
                    .position(x: lp.x, y: lp.y)
                }
            }
        }
    }
}
