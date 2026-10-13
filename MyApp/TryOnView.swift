import SwiftUI
import PhotosUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// Virtual try-on: the app's AI feature, dressed in black and brushed silver. A glossy black pill marks it
// wherever it appears; the try-on screen keeps the chrome-on-black look.
// This is the interaction prototype only: no model runs, the preview is a staged scan.

/// Brushed-metal fills for the try-on feature. Decorative content colours, not UI tokens.
enum Metallic {
    static let ring = AngularGradient(colors: [0x0B0B0C, 0xE9E9EC, 0x6E6E73, 0xFFFFFF, 0x2A2A2D, 0xBDBDC2, 0x0B0B0C].map { Color(hex: $0) },
                                      center: .center)
    static let face = LinearGradient(colors: [0xFFFFFF, 0xC7C7CC, 0x8E8E93, 0xF2F2F7].map { Color(hex: $0) },
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let plate = LinearGradient(colors: [0x2C2C2E, 0x0B0B0C, 0x1C1C1E].map { Color(hex: $0) },
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The "Try on" control: a small, quiet black pill with white type and the faintest gloss on
/// top. Still, so it never competes with the photo.
struct TryOnButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 10, weight: .medium))
                Text("Try on").font(.custom("BeVietnamPro-Medium", size: 11, relativeTo: .caption2))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.62))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                            .frame(height: 12)
                            .padding(.horizontal, 3)
                            .padding(.top, 1)
                    }
            }
            .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Virtual try-on")
        .accessibilityHint("Try this look on a photo of you")
    }
}

/// Full-screen try-on: the look on the left, your photo on the right, and a chrome scan line
/// that sweeps your photo while the preview is "styled".
struct VirtualTryOnView: View {
    let title: String
    let art: Art
    @State private var pick: PhotosPickerItem?
    @State private var photo: Image?
    @State private var scanning = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [.white.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                header
                HStack(spacing: R.spacingSpace12) {
                    panel(label: "The look") {
                        ArtView(art: art)
                    }
                    panel(label: "You") {
                        if let photo {
                            photo.resizable().scaledToFill()
                                .overlay { if scanning { ScanLine() } }
                        } else {
                            VStack(spacing: R.spacingSpace8) {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 28, weight: .light))
                                Text("Your photo here")
                                    .font(.custom("BeVietnamPro-Regular", size: 12, relativeTo: .caption))
                            }
                            .foregroundStyle(Metallic.face)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Metallic.plate)
                        }
                    }
                }
                .frame(height: 340)

                Text(photo == nil
                     ? "Add a full-length photo in good light. We'll dress you in \(title) and keep the photo on your phone."
                     : "Styling you in \(title)…")
                    .font(.custom("BeVietnamPro-Regular", size: 14, relativeTo: .subheadline))
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                Spacer(minLength: 0)

                PhotosPicker(selection: $pick, matching: .images) {
                    HStack(spacing: R.spacingSpace8) {
                        Image(systemName: "sparkles")
                        Text(photo == nil ? "Add your photo" : "Try another photo")
                    }
                    .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .headline))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Metallic.face, in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1) }
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace16)
        }
        .preferredColorScheme(.dark)
        .onChange(of: pick) {
            Task {
                guard let data = try? await pick?.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data) else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    photo = Image(uiImage: ui)
                    scanning = !reduceMotion
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
                    Text("AI · BETA").font(.custom("BeVietnamPro-Medium", size: 11, relativeTo: .caption2)).tracking(1.2)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Metallic.face, in: Capsule())
                Text("Virtual try-on")
                    .font(.custom("PlayfairDisplayRoman-Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Metallic.face)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Metallic.plate, in: Circle())
                    .overlay { Circle().strokeBorder(Metallic.ring, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private func panel<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay { Rectangle().strokeBorder(Metallic.ring, lineWidth: 1.5) }
            .overlay(alignment: .topLeading) {
                Text(label.uppercased())
                    .font(.custom("BeVietnamPro-Medium", size: 10, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Metallic.face, in: Capsule())
                    .padding(10)
            }
    }
}

/// A bright chrome line sweeping down and back over the photo.
private struct ScanLine: View {
    @State private var down = false

    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 70)
                .overlay { Rectangle().fill(.white).frame(height: 1.5) }
                .offset(y: down ? g.size.height - 35 : -35)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { down = true }
        }
    }
}
