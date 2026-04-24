import SwiftUI

extension View {
    @ViewBuilder
    func glassBackground<S: Shape>(
        in shape: S,
        fallback material: Material = .regularMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(material, in: shape)
        }
    }

    @ViewBuilder
    func glassBackground<S: Shape>(
        tinted color: Color,
        in shape: S,
        fallback material: Material = .thinMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.tint(color), in: shape)
        } else {
            self
                .background(material, in: shape)
                .background(color.opacity(0.2), in: shape)
        }
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
