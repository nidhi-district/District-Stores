import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Type

/// Home's type, matched to the production District app's Home, which sets a step smaller and lighter than Backstage's Hub mode
/// styles: 20pt section headings, 14pt lines under them, 15pt card titles and 13pt details.
enum HomeType {
    case section, line, chip, cardTitle, meta, offer, eventTitle, storeName, band, button

    var font: Font {
        switch self {
        case .section: .custom("BeVietnamPro-SemiBold", size: 20, relativeTo: .title3)
        case .line: .custom("BeVietnamPro-Regular", size: 14, relativeTo: .subheadline)
        case .chip: .custom("BeVietnamPro-Medium", size: 13, relativeTo: .footnote)
        case .cardTitle: .custom("BeVietnamPro-Medium", size: 15, relativeTo: .subheadline)
        case .meta: .custom("BeVietnamPro-Regular", size: 13, relativeTo: .footnote)
        case .offer: .custom("BeVietnamPro-Medium", size: 13, relativeTo: .footnote)
        case .eventTitle: .custom("BeVietnamPro-Medium", size: 16, relativeTo: .callout)
        case .storeName: .custom("BeVietnamPro-SemiBold", size: 17, relativeTo: .headline)
        case .band: .custom("BeVietnamPro-SemiBold", size: 15, relativeTo: .subheadline)
        case .button: .custom("BeVietnamPro-Regular", size: 15, relativeTo: .subheadline)
        }
    }

    var tracking: CGFloat { self == .section ? -0.2 : 0 }
}

extension View {
    func homeText(_ type: HomeType) -> some View {
        font(type.font).tracking(type.tracking)
    }
}

// MARK: - Rails

/// Home's vertical rails, after the production District app: Dining, Events, Stores and Activities. Each has a heading that
/// leads to the vertical, a line under it, filter chips, a row of cards, and a button to see everything in the chosen filter.
struct HomeRails: View {
    var openStores: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HomeRail(title: "Dining", line: "Discover top restaurants & save on every bill",
                     filters: HomeRailsData.diningFilters, items: HomeRailsData.dining,
                     explore: { "Explore all \($0) spots" }) { HomePlaceCard(place: $0) }
            HomeRail(title: "Events", line: "Buy tickets to the hottest events",
                     filters: HomeRailsData.eventFilters, items: HomeRailsData.events,
                     explore: { "Explore all \($0) events" }) { HomeEventCard(event: $0) }
            HomeRail(title: "Stores", line: "Shop in-store, pay via District & save",
                     filters: HomeRailsData.storeFilters, items: HomeRailsData.stores,
                     explore: { "Explore all \($0) stores" }, onOpen: openStores) { HomeStoreCard(store: $0) }
            HomeRail(title: "Activities", line: "Try fun outings near you",
                     filters: [], items: { _ in HomeRailsData.activities },
                     explore: { _ in "Explore all activities" }) { HomePlaceCard(place: $0) }
        }
    }
}

/// One rail. Changing the filter swaps the cards and the button's words, and takes the row back to its start.
private struct HomeRail<Item: Identifiable, Card: View>: View {
    let title: String
    let line: String
    let filters: [String]
    let items: (String) -> [Item]
    let explore: (String) -> String
    var onOpen: () -> Void = {}
    @ViewBuilder let card: (Item) -> Card
    @State private var filter: String?

    private var current: String { filter ?? filters.first ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: R.spacingSpace4) {
                    Text(title)
                        .homeText(.section)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(M.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, R.spacingSpace16)

            Text(line)
                .homeText(.line)
                .foregroundStyle(M.textSecondary)
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace8)

            if !filters.isEmpty {
                chips
                    .padding(.top, R.spacingSpace20)
            }

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(items(current)) { card($0) }
                }
                .scrollTargetLayout()
            }
            .carousel()
            // A new filter is a new row, starting from its first card.
            .id(current)
            .transition(.opacity)
            .padding(.top, R.spacingSpace20)

            Button(action: onOpen) {
                HStack(spacing: R.spacingSpace8) {
                    Text(explore(current))
                        .homeText(.button)
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(M.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                        .fill(LinearGradient(colors: [M.hubPureWhite.opacity(0.05), M.hubPureWhite.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                        .strokeBorder(M.hubPureWhite.opacity(0.12), lineWidth: R.stroke1Px)
                }
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace16)
        }
        .animation(.smooth(duration: 0.25), value: current)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(filters, id: \.self) { name in
                    let selected = name == current
                    Button { filter = name } label: {
                        Text(name)
                            .homeText(.chip)
                            .foregroundStyle(M.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Capsule().fill(M.hubPureWhite.opacity(selected ? 0.1 : 0)))
                            .overlay {
                                Capsule().strokeBorder(selected ? M.textPrimary : M.hubPureWhite.opacity(0.16),
                                                       lineWidth: selected ? 1.5 : R.stroke1Px)
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: current)
    }
}

// MARK: - Cards

/// A restaurant or an outing: photo, rating on its lower edge, name, distance and price, and the offer.
private struct HomePlaceCard: View {
    let place: HomeRailsData.Place
    private static let width: CGFloat = 204
    private static let photoHeight: CGFloat = 128

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(place.image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.width, height: Self.photoHeight)
                .clipped()
                .overlay(alignment: .topTrailing) { RailBookmark(name: place.name).padding(R.spacingSpace8) }
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(place.name)
                    .homeText(.cardTitle)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(place.meta)
                    .homeText(.meta)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                if let offer = place.offer {
                    RailOffer(text: offer)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, R.spacingSpace12)
            .padding(.top, 16)
            .padding(.bottom, R.spacingSpace12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: Self.width)
        .background(M.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(alignment: .topLeading) {
            RailRating(value: place.rating)
                .padding(.leading, 10)
                .offset(y: Self.photoHeight - RailRating.height / 2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// An event: a tall poster, then where, what and when.
private struct HomeEventCard: View {
    let event: HomeRailsData.Event
    private static let width: CGFloat = 156

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(event.image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.width, height: 208)
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
                .overlay(alignment: .topTrailing) { RailBookmark(name: event.title).padding(R.spacingSpace8) }
            HStack(spacing: R.spacingSpace4) {
                // The same pin as Home's location header.
                Image("home_ic_location")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 14)
                    .foregroundStyle(M.textOffer)
                Text(event.venue)
                    .homeText(.meta)
                    .foregroundStyle(M.textPrimary.opacity(0.88))
                    .lineLimit(1)
            }
            .padding(.top, R.spacingSpace12)
            Text(event.title)
                .homeText(.eventTitle)
                .foregroundStyle(M.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .padding(.top, 6)
            Text(event.date)
                .homeText(.meta)
                .foregroundStyle(M.textTertiary)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .frame(width: Self.width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A store: its photo with the offer along the bottom, then its name, distance and where it is.
private struct HomeStoreCard: View {
    let store: HomeRailsData.Store
    private static let width: CGFloat = 236

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(store.image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.width, height: 168)
                .clipped()
                .overlay(alignment: .bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(store.offer)
                            .homeText(.band)
                    }
                    .foregroundStyle(M.hubPureWhite)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .background(LinearGradient(colors: [M.surfaceOfferPrimary, M.surfaceOfferPrimary.opacity(0.82)],
                                               startPoint: .leading, endPoint: .trailing))
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
                .overlay(alignment: .topTrailing) { RailBookmark(name: store.name).padding(R.spacingSpace8) }
            Text(store.name)
                .homeText(.storeName)
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
                .padding(.top, R.spacingSpace12)
            Text(store.meta)
                .homeText(.line)
                .foregroundStyle(M.textSecondary)
                .lineLimit(1)
                .padding(.top, R.spacingSpace4)
        }
        .frame(width: Self.width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card pieces

private struct RailBookmark: View {
    let name: String
    @State private var saved = false

    var body: some View {
        Button { saved.toggle() } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(M.hubPureWhite)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                .padding(6)
                .contentShape(Rectangle())
                .padding(-6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: saved)
        .accessibilityLabel(saved ? "Saved" : "Save \(name)")
    }
}

/// The green rating chip that sits across a card's photo and its details.
private struct RailRating: View {
    static let height: CGFloat = 24
    let value: String

    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.custom("BeVietnamPro-SemiBold", size: 13, relativeTo: .caption))
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(M.hubPureWhite)
        .padding(.horizontal, 6)
        .frame(height: Self.height)
        .background(Color(hex: 0x1F8F3F), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(M.surfaceSecondary, lineWidth: 2)
                .padding(-2)
        }
        .accessibilityLabel("Rated \(value)")
    }
}

private struct RailOffer: View {
    let text: String

    var body: some View {
        HStack(spacing: R.spacingSpace4) {
            Image(systemName: "tag.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .homeText(.offer)
        }
        .foregroundStyle(M.textOffer)
    }
}

// MARK: - Data

enum HomeRailsData {
    struct Place: Identifiable {
        var id: String { name }
        let name: String
        let image: String
        let rating: String
        let meta: String
        var offer: String? = nil
    }

    struct Event: Identifiable {
        var id: String { title }
        let title: String
        let venue: String
        let date: String
        let image: String
    }

    struct Store: Identifiable {
        var id: String { name }
        let name: String
        let image: String
        let offer: String
        let meta: String
    }

    // Dining

    static let diningFilters = ["Family Friendly", "Buffet", "Romantic", "Drink & Dine", "Pizza & More"]

    private static let zambar = Place(name: "Zambar", image: "hub_place_zambar", rating: "4.3", meta: "3.4 km • ₹1600 for two", offer: "Flat 15% OFF")
    private static let biggChill = Place(name: "Bigg Chill Cafe", image: "hub_place_bigchill", rating: "4.6", meta: "4.1 km • ₹1400 for two", offer: "Flat 10% OFF")
    private static let potbelly = Place(name: "The Potbelly Divine", image: "hub_place_potbelly", rating: "4.4", meta: "5.2 km • ₹1200 for two", offer: "Flat 20% OFF")
    private static let hearth = Place(name: "Hearth & Slice", image: "hub_place_oven", rating: "4.5", meta: "2.9 km • ₹1100 for two", offer: "Flat 10% OFF")
    private static let vellam = Place(name: "Vellam", image: "hub_place_vellam", rating: "4.5", meta: "3.7 km • ₹1800 for two", offer: "Flat 15% OFF")
    private static let brook = Place(name: "The Brook", image: "hub_place_brook", rating: "4.2", meta: "6.0 km • ₹2200 for two", offer: "Flat 10% OFF")
    private static let velvet = Place(name: "The Velvet Lounge", image: "hub_place_velvet", rating: "4.3", meta: "4.8 km • ₹2400 for two", offer: "Flat 20% OFF")
    private static let botanist = Place(name: "The Drunken Botanist", image: "hub_place_botanist", rating: "4.4", meta: "3.1 km • ₹2000 for two", offer: "Flat 15% OFF")
    private static let staple = Place(name: "Staple Bar and Bistro", image: "hub_place_staple", rating: "4.2", meta: "5.6 km • ₹1800 for two", offer: "Flat 10% OFF")
    private static let woodFire = Place(name: "Wood Fire Pizzeria", image: "hub_place_pizza", rating: "4.3", meta: "2.4 km • ₹900 for two", offer: "Flat 20% OFF")

    static func dining(_ filter: String) -> [Place] {
        switch filter {
        case "Buffet": [vellam, zambar, brook, potbelly]
        case "Romantic": [velvet, brook, vellam, botanist]
        case "Drink & Dine": [botanist, staple, velvet, brook]
        case "Pizza & More": [woodFire, hearth, biggChill]
        default: [zambar, biggChill, potbelly, hearth]
        }
    }

    // Events

    static let eventFilters = ["Music", "Nightlife", "Markets", "Performances"]

    static func events(_ filter: String) -> [Event] {
        switch filter {
        case "Nightlife":
            [Event(title: "Velvet Fridays", venue: "The Velvet Lounge, Sector 29", date: "Fri, 20 Nov, 10:00 PM", image: "hub_place_velvet"),
             Event(title: "Botanist After Dark", venue: "The Drunken Botanist, Cyber Hub", date: "Sat, 21 Nov, 9:00 PM", image: "hub_place_botanist"),
             Event(title: "Retro Bollywood Night", venue: "The Brook, Golf Course Rd", date: "Sat, 21 Nov, 9:30 PM", image: "hub_place_brook")]
        case "Markets":
            [Event(title: "Sunday Flea at Cyber Hub", venue: "Cyber Hub, Gurgaon", date: "Sun, 22 Nov, 11:00 AM", image: "hub_fly_flea"),
             Event(title: "The Big Summer Sale Weekend", venue: "Ambience Mall, Gurgaon", date: "Sat, 21 Nov, 10:00 AM", image: "hub_fly_sale"),
             Event(title: "2D Café Brunch Pop-up", venue: "Galleria Market, Gurgaon", date: "Sun, 22 Nov, 12:00 PM", image: "hub_fly_brunch")]
        case "Performances":
            [Event(title: "Winter Wonderland on Ice", venue: "iSKATE, Ambience Mall", date: "Sat, 21 Nov, 5:00 PM", image: "hub_fly_iskate"),
             Event(title: "Neon Skies Live", venue: "Airia Mall, Gurgaon", date: "Sun, 22 Nov, 6:00 PM", image: "plan_concert_hero")]
        default:
            [Event(title: "Jamming with Soul Strings Project", venue: "Beerlin, Gurgaon", date: "Sat, 21 Nov, 7:30 PM", image: "vibe_concert"),
             Event(title: "Neon Skies Live", venue: "Airia Mall, Gurgaon", date: "Sun, 22 Nov, 6:00 PM", image: "plan_concert_hero"),
             Event(title: "Sunday Sessions: Jazz Brunch", venue: "The Brook, Golf Course Rd", date: "Sun, 22 Nov, 12:30 PM", image: "hub_fly_brunch")]
        }
    }

    // Stores

    static let storeFilters = ["Apparel", "Footwear", "Accessories"]

    static func stores(_ filter: String) -> [Store] {
        switch filter {
        case "Footwear":
            [Store(name: "Flying Machine", image: "sdp_store_flying_machine", offer: "Flat ₹250 OFF", meta: "4.5 km • Cyber Hub"),
             Store(name: "Puma", image: "pd_speedcat", offer: "Flat ₹600 OFF", meta: "3.9 km • Ambience Mall"),
             Store(name: "New Balance", image: "pd_nb9060", offer: "Flat ₹800 OFF", meta: "5.0 km • Galleria Market"),
             Store(name: "ASICS", image: "pd_gel1130", offer: "Flat ₹500 OFF", meta: "4.2 km • Sector 29")]
        case "Accessories":
            [Store(name: "Daily Objects", image: "sdp_store_daily_objects", offer: "Flat ₹200 OFF", meta: "4.5 km • Ambience Mall"),
             Store(name: "Nappa Dori", image: "article_nappa_1", offer: "Flat ₹500 OFF", meta: "6.2 km • Khan Market")]
        default:
            [Store(name: "Nicobar", image: "rack_nicobar_kaftan", offer: "Flat ₹700 OFF", meta: "3.7 km • Sector 54, Gurgaon"),
             Store(name: "Snitch", image: "sdp_store_snitch", offer: "Flat ₹300 OFF", meta: "4.5 km • Ambience Mall"),
             Store(name: "Zara", image: "rack_zara_dress", offer: "Flat ₹500 OFF", meta: "3.2 km • Ambience Mall"),
             Store(name: "H&M", image: "rack_hm_overcoat", offer: "Flat ₹400 OFF", meta: "3.8 km • Cyber Hub")]
        }
    }

    // Activities

    static let activities = [
        Place(name: "Smaash", image: "hub_rail_smaash", rating: "4.4", meta: "2.8 km • Ambience Mall", offer: "Flat 20% OFF"),
        Place(name: "iSKATE", image: "hub_place_iskate", rating: "4.6", meta: "3.0 km • Ambience Mall", offer: "Flat 10% OFF"),
        Place(name: "Timezone", image: "hub_rail_timezone", rating: "4.3", meta: "3.1 km • One Horizon", offer: "Flat 15% OFF"),
        Place(name: "Sky Jumper", image: "hub_rail_skyjumper", rating: "4.5", meta: "3.3 km • Mehrauli", offer: "Flat 10% OFF"),
        Place(name: "Hampley’s Play", image: "hub_rail_hampley", rating: "4.2", meta: "3.4 km • Cyber Hub"),
    ]
}
