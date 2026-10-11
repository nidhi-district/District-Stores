import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Discovery bot: answers a "vibe" query with a carousel of restaurant cards. Opened from the
/// floating entry point on Stores. Layout follows Figma "Discovery bot 2.0" › Bot Window.
struct DiscoveryBotView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = "Tell me north Indian restaurants near me"
    @State private var draft = ""
    @State private var focused: DiscoveryBotData.Restaurant.ID? = DiscoveryBotData.restaurants[1].id
    @FocusState private var typing: Bool

    private let restaurants = DiscoveryBotData.restaurants

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    queryBubble
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, R.spacingSpace24)
                    headline
                        .padding(.top, R.spacingSpace40)
                    carousel
                        .padding(.top, R.spacingSpace24)
                    pageDots
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            inputBar.padding(.bottom, R.spacingSpace8)
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: Chrome

    /// Near-black at the top, a violet wash behind the results and a magenta glow at the bottom
    /// (stops sampled from the Bot Window render).
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x04030B), location: 0),
                .init(color: Color(hex: 0x04030D), location: 0.15),
                .init(color: Color(hex: 0x16132D), location: 0.23),
                .init(color: Color(hex: 0x252143), location: 0.32),
                .init(color: Color(hex: 0x28243F), location: 0.81),
                .init(color: Color(hex: 0x1F1D2E), location: 0.86),
                .init(color: Color(hex: 0x18171E), location: 0.90),
                .init(color: Color(hex: 0x3A1E3E), location: 0.95),
                .init(color: Color(hex: 0x532459), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var header: some View {
        HStack {
            Button {} label: { Image("bot_menu").frame(width: 44, height: 44) }
                .accessibilityLabel("Menu")
            Spacer()
            Button { dismiss() } label: { Image("bot_close").frame(width: 44, height: 44) }
                .accessibilityLabel("Close")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, R.spacingSpace16 - 10)
        .padding(.top, 4)
    }

    // MARK: Conversation

    private var queryBubble: some View {
        Text(query)
            .font(.custom("BeVietnamPro-Medium", size: 14, relativeTo: .subheadline))
            .tracking(-0.082)
            .lineSpacing(4)
            .foregroundStyle(M.textWhite)
            .padding(.horizontal, R.spacingSpace12)
            .padding(.vertical, R.spacingSpace8)
            .background(M.surfaceTransparent, in: bubbleShape)
            .overlay(bubbleShape.stroke(M.borderSubtle, lineWidth: 1))
            .padding(.leading, 61)
            .padding(.trailing, R.spacingSpace16)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12, bottomTrailingRadius: 0, topTrailingRadius: 12)
    }

    /// "Got you top 10 restaurants near you / in North Indian", key words underlined with squiggles.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Got you top 10 restaurants ").foregroundStyle(M.textPrimary.opacity(0.5))
                Text("near you").foregroundStyle(M.textPrimary)
                    .overlay(alignment: .bottom) { Image("bot_squiggle_near").offset(y: 4) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("in ").foregroundStyle(M.textPrimary.opacity(0.5))
                Text("North Indian").foregroundStyle(M.textPrimary)
                    .overlay(alignment: .bottom) { Image("bot_squiggle_cuisine").offset(y: 4) }
            }
        }
        .font(.custom("BeVietnamPro-SemiBold", size: 18, relativeTo: .headline))
        .tracking(-0.18)
        .lineSpacing(1)
        .padding(.horizontal, R.spacingSpace16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Results

    private var carousel: some View {
        GeometryReader { proxy in
            carousel(centeringIn: proxy.size.width)
        }
        .frame(height: DiscoveryBotCard.size.height)
    }

    private func carousel(centeringIn width: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(restaurants) { restaurant in
                    DiscoveryBotCard(restaurant: restaurant)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card
                                .scaleEffect(phase.isIdentity ? 1 : 0.942)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (width - DiscoveryBotCard.size.width) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focused)
        .scrollIndicators(.hidden)
    }

    private var pageDots: some View {
        HStack(spacing: 2) {
            ForEach(restaurants) { restaurant in
                Circle()
                    .fill(M.textPrimary.opacity(restaurant.id == focused ? 1 : 0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: focused)
        .accessibilityHidden(true)
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: R.spacingSpace12) {
            Image("bot_sparkle")
            TextField("", text: $draft, prompt: Text("Type in your vibe").foregroundStyle(M.textPrimary.opacity(0.5)))
                .font(.custom("BeVietnamPro-Medium", size: 14, relativeTo: .subheadline))
                .tracking(-0.082)
                .foregroundStyle(M.textPrimary)
                .tint(M.borderSelectionPurple)
                .focused($typing)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: { typing = true }) {
                Image("bot_mic")
                    .frame(width: 28, height: 28)
                    .background(M.buttonPrimaryBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak your vibe")
        }
        .padding(.leading, R.spacingSpace16)
        .padding(.trailing, 10)
        .frame(width: 343, height: 48)
        .background(M.surfaceTransparent, in: Capsule())
        .liquidGlass(in: Capsule(), clear: true)
        .overlay(Capsule().stroke(Color(rgba: 0xE3DDFF33), lineWidth: 1.5))
        .shadow(color: Color(rgba: 0xFAFAFA3D), radius: 6)
        .shadow(color: .black.opacity(0.2), radius: 17, y: -5)
        .frame(maxWidth: .infinity)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.snappy) { query = text }
        draft = ""
    }
}

// MARK: - Card

private struct DiscoveryBotCard: View {
    static let size = CGSize(width: 260, height: 360)
    let restaurant: DiscoveryBotData.Restaurant

    var body: some View {
        ZStack {
            // The photo sits in the middle band; mirrored, blurred copies bleed into the top and
            // bottom, and the photo's own edges fade into them so there's no hard seam.
            Image(restaurant.image)
                .resizable().scaledToFill()
                .frame(width: 363, height: Self.size.height)
                .blur(radius: 21.6, opaque: true)
            Image(restaurant.image)
                .resizable().scaledToFill()
                .frame(width: 363, height: 287)
                .scaleEffect(y: -1)
                .blur(radius: 21.6, opaque: true)
                .offset(y: 107)
            Image(restaurant.image)
                .resizable().scaledToFill()
                .frame(width: 363, height: 287)
                .scaleEffect(y: -1)
                .blur(radius: 21.6, opaque: true)
                .offset(y: -192)
            Image(restaurant.image)
                .resizable().scaledToFill()
                .frame(width: 305, height: 230)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.3),
                            .init(color: .black, location: 0.7),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .offset(y: -10)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay(alignment: .top) { scrim(from: .top) }
        .overlay(alignment: .bottom) { scrim(from: .bottom).offset(y: 73) }
        .overlay(alignment: .top) { review }
        .overlay(alignment: .bottomLeading) { details }
        .background(Color(hex: 0xD9D9D9))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func scrim(from edge: Edge) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.9), location: 0),
                .init(color: .black.opacity(0.45), location: 0.298),
                .init(color: .clear, location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: 164)
        .allowsHitTesting(false)
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            HStack(alignment: .top, spacing: 0) {
                Text(restaurant.review)
                    .font(.custom("BeVietnamPro-Medium", size: 12, relativeTo: .caption))
                    .lineSpacing(0.8)
                    .foregroundStyle(M.textPrimary)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("bot_quote")
            }
            if let reviewer = restaurant.reviewer {
                HStack(spacing: R.spacingSpace4) {
                    Image("bot_avatar").resizable().frame(width: 16, height: 16).clipShape(Circle())
                    Text(reviewer)
                        .font(.custom("BradleyHandITCTT-Bold", size: 13, relativeTo: .caption))
                        .foregroundStyle(M.textPrimary)
                        .opacity(0.8)
                }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(restaurant.name)
                .font(.custom("BeVietnamPro-SemiBold", size: 14, relativeTo: .subheadline))
                .tracking(-0.14)
                .foregroundStyle(M.textPrimary)
                .frame(height: 21.5)
            HStack(spacing: R.spacingSpace8) {
                HStack(spacing: 2) {
                    Text(restaurant.rating)
                        .font(.custom("BeVietnamPro-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color(hex: 0x117E27))
                    Image("bot_star").resizable().frame(width: 8.7, height: 8.3)
                }
                Text("• \(restaurant.distance) • \(restaurant.area)")
                    .font(.custom("BeVietnamPro-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(M.textPrimary)
                    .opacity(0.8)
            }
            .tracking(-0.082)
            .frame(height: 22)
            Text("\(restaurant.price) • \(restaurant.cuisine)")
                .font(.custom("BeVietnamPro-Regular", size: 12, relativeTo: .caption))
                .tracking(-0.082)
                .foregroundStyle(M.textPrimary)
                .opacity(0.8)
                .frame(height: 22)
            if let offer = restaurant.offer {
                HStack(spacing: R.spacingSpace4) {
                    Image("bot_offer")
                    Text(offer)
                        .font(.custom("BeVietnamPro-SemiBold", size: 10, relativeTo: .caption2))
                        .tracking(-0.23)
                        .foregroundStyle(Color(hex: 0x8972FE))
                }
            }
        }
        .lineLimit(1)
        .padding(R.spacingSpace16)
    }
}

// MARK: - Data

enum DiscoveryBotData {
    struct Restaurant: Identifiable {
        var id: String { name + image }
        let name: String
        let image: String
        let rating: String
        let distance: String
        let area: String
        let price: String
        let cuisine: String
        let review: String
        var reviewer: String?
        var offer: String?
    }

    static let restaurants: [Restaurant] = [
        Restaurant(name: "Monkey Bar", image: "bot_card_left", rating: "4.0", distance: "4 kms", area: "Cyberhub, Gurgaon",
                   price: "₹1800 for two", cuisine: "Asian",
                   review: "Great ambience for birthday celebrations, great music and cocktails"),
        Restaurant(name: "Cafe Delhi Heights", image: "bot_card_main", rating: "4.0", distance: "4 kms", area: "Cyberhub, Gurgaon",
                   price: "₹1800 for two", cuisine: "Asian",
                   review: "Cafe Delhi heights has great ambience with finger-licking & fresh food. Pesto pasta was the highlight of the day for us.",
                   reviewer: "Sagarika", offer: "FLAT 20% OFF"),
        Restaurant(name: "Monkey Bar", image: "bot_card_right", rating: "4.0", distance: "4 kms", area: "Cyberhub, Gurgaon",
                   price: "₹1800 for two", cuisine: "Asian",
                   review: "Great ambience for birthday celebrations, great music and cocktails"),
    ]
}

/// Item for presenting the bot full screen.
struct DiscoveryBotPresentation: Identifiable {
    let id = "discovery-bot"
}

// MARK: - Floating entry point

/// Floating "Let us know your plan" pill that opens the discovery bot.
struct DiscoveryBotEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: R.spacingSpace8) {
                Image("bot_sparkle")
                Text("Let us know your plan")
                    .backstageText(.title4)
                    .lineLimit(1)
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: 0xFAFAFA), location: 0),
                                .init(color: Color(hex: 0xEAEAEB), location: 0.206),
                                .init(color: Color(hex: 0x917BFF), location: 0.697),
                                .init(color: Color(hex: 0xCEDDF2), location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            .padding(.horizontal, R.spacingSpace16)
            .frame(height: 48)
            .background(M.surfaceTransparent, in: Capsule())
            .liquidGlass(in: Capsule(), interactive: true)
            .overlay(Capsule().stroke(Color(hex: 0xCCAEFF), lineWidth: 1))
            .shadow(color: Color(rgba: 0xFAFAFA3D), radius: 6)
            .shadow(color: .black.opacity(0.2), radius: 17, y: -5)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Open discovery bot")
        .accessibilityHint("Let us know your plan")
    }
}

#Preview {
    DiscoveryBotView()
}
