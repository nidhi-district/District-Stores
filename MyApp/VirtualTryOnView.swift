import PhotosUI
import SwiftUI
import UIKit

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// Virtual try-on, "Your closet" (Figma file vvLepayC0iUi8CADXgiI1g, node 23294:8651, from the AI
// try-on section 21886:10927). Only this one screen is built; the Stores banner opens it directly.
// The Figma screen ("You're all set!" and a single button) loses half its users, so this version
// teaches what an outfit photo can be and where to get one before asking for it.

/// Identifies the try-on closet for `readerCover`.
struct TryOnPresentation: Identifiable {
    let id = "virtual-try-on"
}

/// Where an outfit photo can come from.
enum OutfitSource: String, CaseIterable, Identifiable {
    case gallery, shopping, pinterest, camera

    var id: String { rawValue }

    /// The headline on this source's card in the deck.
    var cardTitle: String {
        switch self {
        case .gallery: "Upload from gallery"
        case .shopping: "Screenshot any website"
        case .camera: "Click a photo"
        case .pinterest: "Found on Pinterest"
        }
    }

    var cardLine: String {
        switch self {
        case .gallery: "Outfits already on your phone"
        case .shopping: "Shopping apps and sites work too"
        case .camera: "Spotted something at the mall?"
        case .pinterest: "Screenshot the pin and upload it"
        }
    }

    /// This source's card in the deck; the same artwork as the Lottie.
    var card: String {
        switch self {
        case .gallery: "vto_card_gallery"
        case .shopping: "vto_card_website"
        case .pinterest: "vto_card_pinterest"
        case .camera: "vto_card_camera"
        }
    }
}

// MARK: - Stores banner

/// The try-on entry at the foot of the Stores homepage: a quiet card in the closet screen's
/// spotlight style, with the Figma outfit-and-phone illustration on the right.
struct TryOnBanner: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    HStack(spacing: R.spacingSpace4) {
                        Image("vto_star").resizable().renderingMode(.template).frame(width: 10, height: 10)
                        Text("New · Virtual try-on")
                    }
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
                    Text("See it on you\nbefore you buy")
                        .backstageText(.title2)
                        .foregroundStyle(M.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Try on outfits from Pinterest, any shopping app or the mall.")
                        .backstageText(.body3)
                        .foregroundStyle(M.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: R.spacingSpace4) {
                        Text("Try it on")
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .backstageText(.button3)
                    .foregroundStyle(M.textInverse)
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(height: 32)
                    .background(M.surfaceInverse, in: Capsule())
                    .padding(.top, R.spacingSpace4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TryOnIllustration()
                    .scaleEffect(0.72)
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)
            }
            .padding(R.spacingSpace16)
            .background {
                ZStack {
                    M.surfacePrimary
                    RadialGradient(colors: [Color.white.opacity(0.1), .clear], center: .trailing, startRadius: 0, endRadius: 200)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New: virtual try-on. See it on you before you buy. Try on outfits from Pinterest, any shopping app or the mall.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens your try-on closet")
    }
}

/// The Figma illustration: the outfit cut-out with a hand holding a phone in front of it. The
/// phone's screen can show a photo, so the hero can play "this outfit goes in here".
struct TryOnIllustration: View {
    var screen: Image? = nil

    /// The phone's white screen inside `vto_hand`, in the hand image's own 125.7pt frame.
    private static let screenRect = CGRect(x: 44, y: 27.5, width: 34, height: 73)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("vto_outfit")
                .resizable()
                .scaledToFill()
                .frame(width: 181.1, height: 181.1)
            Image("vto_hand")
                .resizable()
                .scaledToFill()
                .frame(width: 125.7, height: 125.7)
                .overlay(alignment: .topLeading) {
                    if let screen {
                        screen
                            .resizable()
                            .scaledToFill()
                            .frame(width: Self.screenRect.width, height: Self.screenRect.height)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .offset(x: Self.screenRect.minX, y: Self.screenRect.minY)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .offset(x: 58.2, y: 55.4)
        }
        .frame(width: 184, height: 182, alignment: .topLeading)
    }
}

// MARK: - Your closet

/// "Upload your outfits": the step where you add an outfit to try on, laid out as the Figma screen with
/// the illustration swapped for a self-dealing deck of cards, one per source ("Upload from
/// gallery", "Screenshot any website", "Found on Pinterest", "Click a photo") with stepper dots.
/// It's the same artwork and motion as the Lottie, so it teaches what an outfit photo can be
/// before asking for one. Tapping a card adds from that source.
struct TryOnClosetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Index of the deck's top card.
    @State private var front = 0
    @State private var swiping = false
    /// -1 flies the top card off to the left, 1 to the right.
    @State private var flyDirection: CGFloat = -1
    @State private var drag: CGSize = .zero
    /// The Figma shows the deck a little smaller than the card art's own size.
    private static let deckScale: CGFloat = 0.86
    /// The deck's natural height: the card art, its fanned cards above, and the dots.
    private static let deckHeight: CGFloat = 386

    /// Alternates the automatic flick left and right.
    @State private var swipeCount = 0
    /// Stops the tour once the person starts choosing.
    @State private var touched = false
    @State private var picking = false
    @State private var pickingScreenshots = false
    @State private var shooting = false
    @State private var howTo: OutfitSource?
    @State private var pickerItem: PhotosPickerItem?
    @State private var added: [UIImage] = []

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundPrimary.ignoresSafeArea()
            Image("vto_spotlight")
                .resizable()
                .frame(width: 400, height: 844)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // The Figma layout: the deck, then "Now add your outfits!", the two ways to add one and
            // the try-on count, centred on the screen. The deck runs at the Figma's smaller size.
            VStack(spacing: 21) {
                Spacer(minLength: 0)
                hero
                    .scaleEffect(Self.deckScale)
                    .frame(height: Self.deckHeight * Self.deckScale)
                    .padding(.bottom, 15)
                Text("Now add your outfits!")
                    .backstageText(.title2)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                cta
                Spacer(minLength: 0)
            }
            .padding(.top, 60)
        }
        .overlay(alignment: .top) { navigation }
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $picking, selection: $pickerItem, matching: .images)
        .photosPicker(isPresented: $pickingScreenshots, selection: $pickerItem, matching: .screenshots)
        .fullScreenCover(isPresented: $shooting) {
            CameraPicker { image in add(image) }
                .ignoresSafeArea()
        }
        .sheet(item: $howTo) { source in
            ShareHowToSheet(source: source) {
                howTo = nil
                if let url = URL(string: "pinterest://") { openURL(url) { ok in if !ok, let web = URL(string: "https://www.pinterest.com") { openURL(web) } } }
            }
        }
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    add(image)
                }
                pickerItem = nil
            }
        }
        // The deck deals itself until the person takes over.
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled && !touched {
                try? await Task.sleep(for: .seconds(1.1))
                guard !touched, added.isEmpty else { break }
                await swipeNext(swipeCount.isMultiple(of: 2) ? -1 : 1, lean: true)
                swipeCount += 1
            }
        }
        .sensoryFeedback(.success, trigger: added.count)
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tryOnLit"), i + 1 < args.count, let s = OutfitSource(rawValue: args[i + 1]) {
                touched = true
                front = OutfitSource.allCases.firstIndex(of: s) ?? 0
            }
            if let i = args.firstIndex(of: "-tryOnSwipe"), i + 1 < args.count, let x = Double(args[i + 1]) {
                touched = true
                drag = CGSize(width: x, height: 0)
            }
            if args.contains("-tryOnHowTo") { howTo = .pinterest }
        }
        #endif
    }

    // MARK: Header

    private var navigation: some View {
        HStack(spacing: R.spacingSpace16) {
            GlassIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
            Text("Upload your outfits")
                .backstageText(.title2)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace12)
        .padding(.bottom, R.spacingSpace8)
        .background {
            LinearGradient(colors: [Color(rgba: 0x0C0B0EB3), Color(rgba: 0x0C0B0E00)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Hero

    /// The deck: one card per way to add an outfit. The top card flicks away every couple of
    /// seconds and the next rises to take its place, like a looping Lottie. Swipe it yourself to
    /// move on, or tap it to add from that source. Once a photo is added it sits on top.
    private var hero: some View {
        let all = OutfitSource.allCases
        // The card art carries 36pt of shadow below the card, so the dots sit close.
        return VStack(spacing: 0) {
            ZStack {
                ForEach(Array(all.enumerated()), id: \.element.id) { i, source in
                    let depth = (i - front + all.count) % all.count
                    deckCard(source, depth: depth)
                        .zIndex(Double(all.count - depth))
                }
                if let last = added.last {
                    AddedCard(image: Image(uiImage: last), count: added.count)
                        .zIndex(10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(height: SwipeCard.canvas.height + 36, alignment: .bottom)
            .frame(maxWidth: .infinity)

            // Where you are in the deck.
            HStack(spacing: 6) {
                ForEach(Array(all.enumerated()), id: \.element.id) { i, _ in
                    Capsule()
                        .fill(i == front ? M.textPrimary : M.textTertiary.opacity(0.5))
                        .frame(width: i == front ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: front)
            // Tucked up into the card art's shadow margin, as in the Lottie.
            .padding(.top, -16)
            .opacity(added.isEmpty ? 1 : 0)
            .accessibilityHidden(true)
        }
    }

    /// A card at its place in the stack: the top one follows your finger and flies off when swiped;
    /// the ones behind step up, smaller and fanned, as it goes.
    private func deckCard(_ source: OutfitSource, depth: Int) -> some View {
        let top = depth == 0
        let place = Double(max(depth - (swiping ? 1 : 0), 0))
        let fan: Double = place == 1 ? 4 : -4
        return SwipeCard(source: source)
            .scaleEffect(top ? 1 : 1 - 0.07 * place, anchor: SwipeCard.pivot)
            .offset(x: top ? (swiping ? flyDirection * 460 : drag.width) : 0,
                    y: top ? (swiping ? -30 : drag.height * 0.15) : -18 * place)
            .rotationEffect(.degrees(top ? (swiping ? flyDirection * 18 : drag.width / 18) : (place == 0 ? 0 : fan)), anchor: SwipeCard.pivot)
            .opacity(top || place < 3 ? 1 : 0)
            .allowsHitTesting(top && added.isEmpty)
            .onTapGesture { choose(source) }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        touched = true
                        drag = value.translation
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 90 {
                            Task { await swipeNext(value.translation.width < 0 ? -1 : 1) }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { drag = .zero }
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(source.cardTitle). \(source.cardLine)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHidden(!top)
    }

    /// Flicks the top card off to one side and brings the next to the front. On its own it leans
    /// the other way for a beat first, as in the Lottie; a finger swipe skips that.
    private func swipeNext(_ direction: CGFloat = -1, lean: Bool = false) async {
        guard !swiping else { return }
        flyDirection = direction
        if lean {
            withAnimation(.easeInOut(duration: 0.2)) { drag = CGSize(width: -direction * 10, height: 0) }
            try? await Task.sleep(for: .seconds(0.2))
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { swiping = true }
        try? await Task.sleep(for: .seconds(0.4))
        var settle = Transaction()
        settle.disablesAnimations = true
        withTransaction(settle) {
            front = (front + 1) % OutfitSource.allCases.count
            swiping = false
            drag = .zero
        }
    }

    // MARK: Button

    /// The Figma buttons, gallery (outlined) over camera (filled), and the try-on count.
    private var cta: some View {
        VStack(spacing: 21) {
            VStack(spacing: R.spacingSpace16) {
                Button { choose(.gallery) } label: {
                    buttonLabel("vto_ic_images", added.isEmpty ? "Upload from gallery" : "Add another from gallery")
                        .foregroundStyle(M.textPrimary)
                        .background(Capsule().fill(M.surfaceTransparent))
                        .overlay(Capsule().strokeBorder(M.borderSelection, lineWidth: R.stroke1Px))
                }
                .buttonStyle(PressableStyle())
                Button { choose(.camera) } label: {
                    buttonLabel("vto_ic_camera", "Take a photo")
                        .foregroundStyle(M.textInverse)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, R.spacingSpace24)
            HStack(spacing: R.spacingSpace4) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("10 try-ons remaining today").backstageText(.body3)
            }
            .foregroundStyle(M.textTertiary)
        }
    }

    private func buttonLabel(_ icon: String, _ title: String) -> some View {
        HStack(spacing: R.spacingSpace8) {
            Image(icon).renderingMode(.template).resizable().frame(width: 20, height: 20)
            Text(title).backstageText(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, R.spacingSpace12)
        .contentShape(Capsule())
    }

    // MARK: Actions

    private func choose(_ source: OutfitSource) {
        touched = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            front = OutfitSource.allCases.firstIndex(of: source) ?? front
        }
        switch source {
        case .pinterest: howTo = .pinterest
        case .shopping: pickingScreenshots = true
        case .camera:
            if UIImagePickerController.isSourceTypeAvailable(.camera) { shooting = true } else { picking = true }
        case .gallery: picking = true
        }
    }

    private func add(_ image: UIImage) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { added.append(image) }
    }
}

/// One card in the deck: the same artwork as the Lottie (virtual-try-on-cards.json), a mini phone
/// UI for the source with what to do at the foot. The image is 288×360 with the card itself at
/// (28, 20, 232×304) and its shadow baked into the margin.
private struct SwipeCard: View {
    let source: OutfitSource

    static let canvas = CGSize(width: 288, height: 360)
    static let card = CGRect(x: 28, y: 20, width: 232, height: 304)
    /// The card's bottom centre, which the deck scales and tilts around.
    static let pivot = UnitPoint(x: 0.5, y: card.maxY / canvas.height)

    var body: some View {
        Image(source.card)
            .resizable()
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: Self.card))
    }
}

/// The photo you just added, on top of the deck.
private struct AddedCard: View {
    let image: Image
    let count: Int

    var body: some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: SwipeCard.card.width, height: SwipeCard.card.height)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Label(count == 1 ? "Added to your closet" : "\(count) outfits in your closet", systemImage: "checkmark.circle.fill")
                    .backstageText(.label2)
                    .foregroundStyle(M.textBlack)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 30)
                    .background(Capsule().fill(M.surfaceInverse))
                    .padding(R.spacingSpace12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
            .frame(width: SwipeCard.canvas.width, height: SwipeCard.canvas.height, alignment: .topLeading)
            .offset(x: SwipeCard.card.minX, y: SwipeCard.card.minY)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Sharing from Pinterest

/// How to send a pin here: three steps and a way into Pinterest.
private struct ShareHowToSheet: View {
    let source: OutfitSource
    var open: () -> Void

    private let steps: [(String, String)] = [
        ("hand.tap", "Open the pin with the outfit you like"),
        ("square.and.arrow.up", "Tap Share, then More"),
        ("sparkles", "Pick District. The outfit lands in your closet"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("Try on a pin")
                    .backstageText(.title2)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Share it from Pinterest in three taps.")
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
            }
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: R.spacingSpace12) {
                        Text("\(i + 1)")
                            .backstageText(.label2)
                            .foregroundStyle(M.textInverse)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(M.surfaceInverse))
                        Text(step.1)
                            .backstageText(.body3)
                            .foregroundStyle(M.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: step.0)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(M.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Button(action: open) {
                HStack(spacing: R.spacingSpace8) {
                    Image(systemName: "pin.fill")
                    Text("Open Pinterest")
                }
                .backstageText(.title3)
                .foregroundStyle(M.textBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(M.surfaceInverse))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(R.spacingSpace24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(M.surfacePrimary)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Camera

/// The system camera, for snapping an outfit in a store.
private struct CameraPicker: UIViewControllerRepresentable {
    var picked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.picked(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

#Preview {
    TryOnClosetView()
}
