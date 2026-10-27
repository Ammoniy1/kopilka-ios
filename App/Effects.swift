import SwiftUI

/// Золотая монетка
struct GoldCoin: View {
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [Color(hex: "FFF6C2"), Color(hex: "FFD84D"), Color(hex: "F0B323"), Color(hex: "B9780A")],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 22))
            Circle().strokeBorder(Color(hex: "C98A10"), lineWidth: 2.5)
            Circle().inset(by: 5).strokeBorder(Color(hex: "FFE58A"), lineWidth: 1.5)
            Circle().inset(by: 9).fill(RadialGradient(
                colors: [Color(hex: "FFE680"), Color(hex: "E5A21A")],
                center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 10))
        }
        .shadow(color: Color(hex: "965A00").opacity(0.45), radius: 3, y: 2)
    }
}

/// Монетка, падающая в прорезь свинки
struct FallingCoin: View {
    @State private var fallen = false

    var body: some View {
        GoldCoin()
            .frame(width: 34, height: 34)
            .rotation3DEffect(.degrees(fallen ? 540 : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(fallen ? 0.75 : 1)
            .offset(y: fallen ? 30 : -120)
            .opacity(fallen ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) { fallen = true }
            }
    }
}

/// Конфетти при достижении цели
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let delay: Double
        let duration: Double
        let spin: Double
    }

    @State private var pieces: [Piece] = []
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    Text(p.emoji)
                        .font(.system(size: 26))
                        .rotationEffect(.degrees(fall ? p.spin : 0))
                        .position(x: p.x * geo.size.width, y: fall ? geo.size.height + 60 : -40)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: fall)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            let emojis = ["🎉", "✨", "⭐", "💖", "🎊"]
            pieces = (0..<30).map { i in
                Piece(emoji: emojis[i % emojis.count], x: .random(in: 0.02...0.98),
                      delay: .random(in: 0...0.5), duration: .random(in: 1.8...3.2), spin: .random(in: 180...720))
            }
            DispatchQueue.main.async { fall = true }
        }
    }
}

/// Всплывающее сообщение внизу экрана с кнопкой «Отменить»
struct ToastView: View {
    let message: ToastMessage
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message.text).font(.rounded(15, .medium)).lineLimit(1)
            if message.undo {
                Button("Отменить", action: onUndo)
                    .font(.rounded(15, .bold))
                    .foregroundStyle(Color(hex: "FFB3C9"))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color(hex: "222222")))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}
