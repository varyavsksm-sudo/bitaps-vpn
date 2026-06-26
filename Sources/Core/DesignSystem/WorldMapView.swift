import SwiftUI

/// Dot-matrix world map (same art as the landing page) with glowing pins for our
/// locations. Active nodes pulse in accent; "soon" nodes sit dim. Selected node
/// gets a bright halo. "Серверы, которые никогда не спят."
public struct WorldMapView: View {
    let servers: [Server]
    let selectedId: String?
    let onTap: ((Server) -> Void)?
    @State private var pulse = false

    public init(servers: [Server], selectedId: String? = nil, onTap: ((Server) -> Void)? = nil) {
        self.servers = servers
        self.selectedId = selectedId
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / 2          // map art is 2:1
            ZStack(alignment: .topLeading) {
                Image("WorldMap")
                    .resizable()
                    .aspectRatio(2, contentMode: .fit)
                    .frame(width: w, height: h)
                    .opacity(0.28)

                ForEach(servers) { s in
                    Group {
                        if let onTap, s.available {
                            Button { onTap(s) } label: { pin(for: s) }.buttonStyle(.plain)
                        } else {
                            pin(for: s)
                        }
                    }
                    .position(x: s.mapX * w, y: s.mapY * h)
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(2, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    @ViewBuilder private func pin(for s: Server) -> some View {
        let active = s.available
        let selected = s.id == selectedId
        let color = active ? BitColor.accent : BitColor.muted
        ZStack {
            if active {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: pulse ? 26 : 14, height: pulse ? 26 : 14)
                    .opacity(pulse ? 0 : 0.8)
            }
            Circle()
                .fill(color)
                .frame(width: selected ? 12 : 8, height: selected ? 12 : 8)
                .overlay(Circle().stroke(.white.opacity(selected ? 0.9 : 0.3), lineWidth: selected ? 2 : 1))
                .bitGlow(color, radius: active ? 10 : 0, opacity: active ? 0.9 : 0)
        }
    }
}
