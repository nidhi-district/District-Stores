import SwiftUI

// Hubs: the model behind the listing and detail pages (Figma "Hub mode", Hlog4VZFrclCmyGmLXTu6q,
// listing 14220:31227, detail 14234:95159). All content is sample data.

// MARK: - Hub types

enum HubType: String, CaseIterable, Identifiable {
    case mall, highStreet, market, hotel, beach, airport, business, park

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mall: "Malls"
        case .highStreet: "High Street"
        case .market: "Markets"
        case .hotel: "Hotels"
        case .beach: "Beaches"
        case .airport: "Airports"
        case .business: "Business"
        case .park: "Parks"
        }
    }

    /// The category tile's 3D art. Airports, business parks and parks have no art in the Figma yet and use an emoji.
    var art: String? {
        switch self {
        case .mall: "hub_cat_malls"
        case .highStreet: "hub_cat_highstreet"
        case .market: "hub_cat_markets"
        case .hotel: "hub_cat_hotels"
        case .beach: "hub_cat_beaches"
        case .airport, .business, .park: nil
        }
    }

    var emoji: String {
        switch self {
        case .airport: "✈️"
        case .business: "🏢"
        case .park: "🌳"
        default: ""
        }
    }

    /// The tile art's size from the Figma category rail.
    var artSize: CGFloat {
        switch self {
        case .mall: 51
        case .highStreet: 49
        case .market: 45
        case .hotel: 59
        case .beach: 47
        case .airport, .business, .park: 40
        }
    }

    /// The Figma's detail states: mall "anatomy", "Less tabs case", "Only 1 tab" and "Airport".
    fileprivate var layout: HubLayout {
        switch self {
        case .mall, .highStreet, .market: .full
        case .hotel, .beach, .business: .fewTabs
        case .park: .singleList
        case .airport: .airport
        }
    }

    fileprivate var tabs: [HubTab] {
        switch self {
        case .mall, .highStreet: [.topFinds, .restaurants, .stores, .cafes, .desserts, .bar]
        case .market: [.topFinds, .restaurants, .stores, .cafes, .desserts]
        case .hotel: [.restaurants, .bar, .salon]
        case .beach: [.restaurants, .bar, .activities]
        case .business: [.restaurants, .cafes, .desserts]
        case .park, .airport: []
        }
    }

    /// "Find in hub" sits in the bar of hubs with a mapped indoor directory.
    fileprivate var hasFindInHub: Bool {
        switch self {
        case .mall, .business, .airport: true
        case .highStreet, .market, .hotel, .beach, .park: false
        }
    }
}

enum HubLayout { case full, fewTabs, singleList, airport }

enum HubTab: String, Identifiable {
    case topFinds, restaurants, stores, cafes, desserts, bar, salon, activities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topFinds: "Top finds"
        case .restaurants: "Restaurants"
        case .stores: "Stores"
        case .cafes: "Cafes"
        case .desserts: "Desserts"
        case .bar: "Bar"
        case .salon: "Salon"
        case .activities: "Activities"
        }
    }

    var icon: String {
        switch self {
        case .topFinds: "hub_tab_top"
        case .restaurants: "hub_tab_restaurants"
        case .stores: "hub_tab_stores"
        case .cafes: "hub_tab_cafes"
        case .desserts: "hub_tab_desserts"
        case .bar: "hub_tab_bar"
        case .salon: "hub_tab_salon"
        case .activities: "hub_tab_activities"
        }
    }

    var listTitle: String {
        switch self {
        case .topFinds, .restaurants: "All restaurants"
        case .stores: "All stores"
        case .cafes: "All cafes"
        case .desserts: "All desserts"
        case .bar: "All bars"
        case .salon: "All salons"
        case .activities: "All activities"
        }
    }

    var kind: HubPlace.Kind {
        switch self {
        case .topFinds, .restaurants: .restaurant
        case .stores: .store
        case .cafes: .cafe
        case .desserts: .dessert
        case .bar: .bar
        case .salon: .salon
        case .activities: .entertainment
        }
    }
}

// MARK: - Hub

enum HubStatus {
    case open(until: String)
    case closed(opens: String)
}

struct HubStat: Hashable {
    let icon: String
    let label: String

    static func restaurants(_ n: Int) -> HubStat { HubStat(icon: "hub_ic_utensils", label: "\(n) restaurants") }
    static func movies(_ n: Int) -> HubStat { HubStat(icon: "hub_ic_clapper", label: "\(n) Movies") }
    static func stores(_ n: Int) -> HubStat { HubStat(icon: "hub_ic_cart", label: "\(n) Stores") }
}

struct HubBuzz: Identifiable {
    var id: String { title }
    let title: String
    var subtitle: String? = nil
    let image: String
}

struct HubHours: Identifiable {
    var id: String { day }
    let day: String
    let time: String
}

struct HubFacility: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
}

struct Hub: Identifiable, Equatable {
    let id: String
    let name: String
    let type: HubType
    /// Card line, e.g. "Sector 50, Gurugram".
    let locality: String
    /// Card distance pill, e.g. "3 km".
    let distance: String
    let blurb: String
    let chips: [String]
    let image: String
    var imageAlignment: Alignment = .center
    var googleRating: String? = nil
    var vibes: Set<String> = []

    // Detail page
    var heroImage: String? = nil
    var heroAlignment: Alignment = .center
    var detailDistance: String
    var detailArea: String
    var rating: String? = "4.3"
    var ratingCount: String = "(12.1k)"
    var status: HubStatus? = .open(until: "Closes 1 AM")
    var stats: [HubStat]
    /// Figma "Dominant colour glow in background".
    var glow: Color
    var address: String
    var brandLogo: String? = nil
    var buzz: [HubBuzz] = HubsData.defaultBuzz
    var layout: HubLayout
    var tabs: [HubTab]
    var hasFindInHub: Bool

    static func == (a: Hub, b: Hub) -> Bool { a.id == b.id }

    init(_ name: String, type: HubType, locality: String, distance: String, blurb: String, chips: [String], image: String,
         imageAlignment: Alignment = .center, googleRating: String? = nil, vibes: Set<String> = [],
         heroImage: String? = nil, heroAlignment: Alignment = .center, detailDistance: String? = nil, detailArea: String? = nil,
         rating: String? = "4.3", status: HubStatus? = .open(until: "Closes 1 AM"), stats: [HubStat],
         glow: Color = Color(hex: 0x748599), address: String? = nil, brandLogo: String? = nil, buzz: [HubBuzz] = HubsData.defaultBuzz,
         tabs: [HubTab]? = nil, hasFindInHub: Bool? = nil) {
        id = name
        self.name = name
        self.type = type
        self.locality = locality
        self.distance = distance
        self.blurb = blurb
        self.chips = chips
        self.image = image
        self.imageAlignment = imageAlignment
        self.googleRating = googleRating
        self.vibes = vibes
        self.heroImage = heroImage
        self.heroAlignment = heroAlignment
        self.detailDistance = detailDistance ?? distance.replacingOccurrences(of: " ", with: "")
        self.detailArea = detailArea ?? locality
        self.rating = rating
        self.status = status
        self.stats = stats
        self.glow = glow
        self.address = address ?? "\(name), \(locality), India"
        self.brandLogo = brandLogo
        self.buzz = buzz
        layout = type.layout
        self.tabs = tabs ?? type.tabs
        self.hasFindInHub = hasFindInHub ?? type.hasFindInHub
    }

    var hero: String { heroImage ?? image }

    /// The distance pill's value as a number, for sorting.
    var distanceKm: Double {
        Double(distance.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " km", with: "")) ?? .greatestFiniteMagnitude
    }
}

// MARK: - Places inside a hub

struct HubPlace: Identifiable {
    enum Kind { case restaurant, cafe, dessert, bar, store, entertainment, salon }

    var id: String { name }
    let name: String
    let kinds: Set<Kind>
    /// Nil for stores, which show their logo instead of a photo.
    var photo: String? = nil
    var logo: String? = nil
    var rating: String? = nil
    var isNew = false
    var isAd = false
    var cuisine: String = ""
    var floor: Int = 1
    var price: String? = nil
    var offer: String? = "Flat 10% OFF"
    var shopNumber: String? = nil
    var tags: Set<String> = []

    var floorLabel: String {
        switch floor {
        case 0: "Underground"
        case 1: "Floor 1"
        case 2: "Floor 2"
        default: "Floor \(floor)"
        }
    }

    var ratedFourPlus: Bool { (rating.flatMap(Double.init) ?? 0) >= 4 }
}

/// A floor of a hub's directory.
struct HubFloor: Identifiable, Hashable {
    var id: String { title }
    let badge: String
    let title: String
    /// Nil means every floor.
    let floor: Int?
}

/// A collapsible group on the floors directory and the airport page.
struct HubCategory: Identifiable {
    var id: String { title + zone }
    let title: String
    let kind: HubPlace.Kind
    let icon: String
    let tint: Color
    /// The airport zone this group is in ("Post-security"); empty on the floors directory.
    var zone: String = ""
    var countNoun = "options"
}

// MARK: - Sample data

enum HubsData {
    /// Listing title rail: "Worth stepping out for".
    struct Pick: Identifiable {
        var id: String { title }
        let title: String
        let hub: String
        let line: String
        let image: String
    }

    /// In the Figma's order, so the rail opens on the brunch card with the flea market peeking on the left.
    static let picks: [Pick] = [
        Pick(title: "Have brunch at 2D cafe", hub: "Ambience Mall",
             line: "A vibrant spot where art meets flavor with unique 2D-themed decor and treats.", image: "hub_fly_brunch"),
        Pick(title: "Enjoy Coffee at Savourworks", hub: "Ambience Mall",
             line: "Up to 50% off 40+ brands - plus an ice rink and IMAX for a full day out, not just shopping.", image: "hub_fly_sale"),
        Pick(title: "Skate at iSKATE", hub: "DLF Promenade",
             line: "India's largest rink, with cafés and plenty of shopping right around it.", image: "hub_fly_iskate"),
        Pick(title: "Enjoy Flea markets", hub: "Ambience Mall",
             line: "50+ indie stalls, street food, and a live band under fairy lights.", image: "hub_fly_flea"),
    ]

    /// Listing mid-page rail: "Perfect for Kid's day out".
    struct KidSpot: Identifiable {
        var id: String { name }
        let name: String
        let line: String
        let image: String
    }

    static let kidSpots: [KidSpot] = [
        KidSpot(name: "Timezone", line: "3.1 km • One Horizon", image: "hub_rail_timezone"),
        KidSpot(name: "Hampley’s Play", line: "3.4 km • Cyber Hub", image: "hub_rail_hampley"),
        KidSpot(name: "Sky Jumper", line: "3.3 km • Mehrauli", image: "hub_rail_skyjumper"),
        KidSpot(name: "Smaash", line: "2.8 km • Ambience Mall", image: "hub_rail_smaash"),
    ]

    /// Only "Family outing", "Kids play zone" and "Chill hangout" can be read in the Figma; the rest are placeholders.
    static let vibes = ["Family outing", "Kids play zone", "Weekend plans", "Date night", "Foodies", "Chill hangout", "Luxury"]

    static let defaultBuzz: [HubBuzz] = [
        HubBuzz(title: "Dining Carnival", subtitle: "40+ restaurants", image: "hub_buzz_dining"),
        HubBuzz(title: "iSkate", image: "hub_buzz_iskate"),
        HubBuzz(title: "1+1 on Starbucks", subtitle: "Till 22 Sept", image: "hub_buzz_starbucks"),
    ]

    static let hubs: [Hub] = [
        Hub("Good City Centre", type: .mall, locality: "Sector 50, Gurugram", distance: "3 km",
            blurb: "A vibrant destination featuring a mix of popular stores, cozy eateries, and is family-friendly",
            chips: ["🛒 Daily essentials", "🍽️ Family restaurants", "🎬 Movie theater", "👶 Play area", "🏪 Retail stores"],
            image: "hub_good_city", vibes: ["Family outing", "Kids play zone"],
            stats: [.restaurants(18), .movies(1), .stores(42)], glow: Color(hex: 0x7A8CA0)),
        Hub("Omaxe Celebration Mall", type: .mall, locality: "Sohna Road, Gurugram", distance: "5 km",
            blurb: "A lively spot with popular shops, inviting eateries, and a welcoming atmosphere for families.",
            chips: ["🛍️ Shopping brands", "🎬 Cinema hall", "🍔 Fast food joints", "🎮 Entertainment zone"],
            image: "hub_omaxe", vibes: ["Family outing", "Weekend plans"],
            stats: [.restaurants(14), .movies(1), .stores(36)], glow: Color(hex: 0x6F8FA8)),
        Hub("Cyber Hub", type: .highStreet, locality: "Cyber City, Gurugram", distance: "8 km",
            blurb: "Vibrant dining and entertainment hub with live music and trendy restaurants.",
            chips: ["🎤 Live music events", "🛍️ Shopping brands", "🍽️ Global cuisines", "🛍️ Boutique stores"],
            image: "hub_cyber", vibes: ["Date night", "Foodies", "Chill hangout"],
            stats: [.restaurants(52), .stores(12)], glow: Color(hex: 0x8A7C6E)),
        Hub("Galleria Market", type: .market, locality: "Sector-28, Gurugram", distance: "10 km",
            blurb: "Galleria Market in Gurgaon buzzes with trendy shops, cozy cafes, and delicious street food stalls.",
            chips: ["🍜 Street food hub", "🛍️ Trendy shops", "☕ Cafés & bakeries", "💇 Salons & spas"],
            image: "hub_galleria", googleRating: "4.4", vibes: ["Foodies", "Chill hangout"],
            stats: [.restaurants(30), .stores(64)], glow: Color(hex: 0x7F7468)),
        Hub("MGF Metropolitan Mall", type: .mall, locality: "MG Road, Gurugram", distance: "12 km",
            blurb: "A premier shopping spot, featuring leading brands, cozy cafés, and fun activities for kids.",
            chips: ["🛍️ Fashion stores", "🎬 Multiplex cinema", "☕ Cozy cafés", "🎮 Gaming arcade", "🍕 Food court"],
            image: "hub_mgf", googleRating: "4.4", vibes: ["Family outing", "Kids play zone"],
            stats: [.restaurants(22), .movies(1), .stores(70)], glow: Color(hex: 0x6E8494)),
        Hub("Ambience Mall", type: .mall, locality: "NH-8, Gurugram", distance: "13 km",
            blurb: "Gurgaon's biggest shopping destination with top brands, great cafés and plenty for kids.",
            chips: ["🛍️ Premium brands", "👶 Kids' play zone", "⛸️ Ice skating rink", "🎬 PVR cinemas"],
            image: "hub_ambience", imageAlignment: .top, vibes: ["Family outing", "Kids play zone", "Weekend plans"],
            stats: [.restaurants(47), .movies(2), .stores(120)], glow: Color(hex: 0x8C7A70)),
        Hub("32nd Avenue", type: .highStreet, locality: "Sector 15, Gurugram", distance: "15 km",
            blurb: "Top shopping with popular brands, cozy cafés, and kids' fun.",
            chips: ["☕ Artisan cafés", "🌿 Open-air seating", "🎭 Art galleries", "🍷 Fine dining"],
            image: "hub_32nd", vibes: ["Date night", "Chill hangout"],
            stats: [.restaurants(28), .stores(16)], glow: Color(hex: 0x8D6D4B)),
        Hub("Khan Market", type: .market, locality: "Central Delhi", distance: "35 km",
            blurb: "Explore Khan Market, known for its trendy shops, charming cafés, and a welcoming vibe for families.",
            chips: ["📚 Bookstores", "👗 Designer boutiques", "☕ Iconic cafés", "🍝 International cuisine"],
            image: "hub_khan", imageAlignment: .bottom, vibes: ["Foodies", "Chill hangout", "Date night"],
            heroImage: "hub_khan_hero", detailDistance: "28.3km", detailArea: "Rabindra Nagar, New Delhi",
            status: .closed(opens: "Opens 11am"), stats: [.restaurants(7), .stores(59)], glow: Color(hex: 0xA68B10),
            address: "2nd Floor, Xo Bar, Aipl Joy Central A unit of Studio, Sector 65, Gurugram, Haryana 122002, India",
            buzz: [HubBuzz(title: "Dining Carnival", subtitle: "40+ restaurants", image: "hub_buzz_dining"),
                   HubBuzz(title: "Faqir Chand bookstore", image: "hub_buzz_faqir"),
                   HubBuzz(title: "1+1 on Starbucks", subtitle: "Till 22 Sept", image: "hub_buzz_starbucks")]),
        Hub("The Chanakya", type: .mall, locality: "Chanakyapuri, Delhi", distance: "3.5 km",
            blurb: "An ultra-luxury destination with designer boutiques, gourmet dining, and a premium cinema experience.",
            chips: ["👗 Designer labels", "🍷 Fine dining", "🎬 Luxury cinema", "💎 Premium lifestyle"],
            image: "hub_chanakya", vibes: ["Luxury", "Date night"],
            stats: [.restaurants(12), .movies(1), .stores(40)], glow: Color(hex: 0x6D7F93)),
        Hub("DLF Emporio", type: .mall, locality: "Vasant Kunj, Delhi", distance: "3.5 km",
            blurb: "Delhi's most exclusive luxury mall featuring international fashion houses and high-end dining.",
            chips: ["🛍️ Luxury brands", "👠 High fashion", "🍽️ Gourmet restaurants", "💍 Jewellery stores"],
            image: "hub_emporio", vibes: ["Luxury"],
            stats: [.restaurants(10), .stores(80)], glow: Color(hex: 0x5F7F9E)),
        Hub("Select Citywalk", type: .mall, locality: "Saket, Delhi", distance: "3.5 km",
            blurb: "A vibrant open-air shopping destination with top brands, great food, and lively entertainment.",
            chips: ["🛍️ Top brands", "🎤 Live events", "🍔 Food plaza", "🎬 PVR cinemas"],
            image: "hub_select", vibes: ["Weekend plans", "Family outing", "Chill hangout"],
            stats: [.restaurants(38), .movies(1), .stores(140)], glow: Color(hex: 0x8C7468)),
        Hub("Pacific Mall", type: .mall, locality: "Tagore Garden, Delhi", distance: "3.5 km",
            blurb: "A popular family-friendly mall with diverse shopping, entertainment, and a buzzing food court.",
            chips: ["🛒 Value shopping", "🎮 Gaming zone", "🍕 Food court", "👶 Kids' activities"],
            image: "hub_pacific", vibes: ["Family outing", "Kids play zone"],
            stats: [.restaurants(20), .movies(1), .stores(90)], glow: Color(hex: 0x6F89A3)),
        Hub("DLF Promenade", type: .mall, locality: "DLF Phase 4, Saket", distance: "28 km",
            blurb: "Gurgaon's biggest shopping destination with top brands, great cafés and plenty for kids.",
            chips: ["🛍️ Premium brands", "⛸️ iSKATE rink", "🍽️ Dining Carnival", "🎬 2 Movies"],
            image: "hub_promenade", vibes: ["Family outing", "Weekend plans", "Foodies"],
            detailDistance: "28.3km", stats: [.restaurants(47), .movies(2), .stores(59)]),
        Hub("The Leela Ambience", type: .hotel, locality: "NH-8, Gurugram", distance: "13 km",
            blurb: "A grand city hotel with celebrated restaurants, a rooftop bar and an award-winning spa.",
            chips: ["🍽️ Fine dining", "🍸 Rooftop bar", "💆 Luxury spa", "🏊 Infinity pool"],
            image: "hub_hotel_leela", vibes: ["Luxury", "Date night"],
            status: .open(until: "Open 24 hours"), stats: [.restaurants(6)], glow: Color(hex: 0x8E6F96)),
        Hub("Taj Palace", type: .hotel, locality: "Chanakyapuri, Delhi", distance: "4 km",
            blurb: "Classic Delhi luxury with legendary dining rooms, poolside evenings and an in-house spa.",
            chips: ["🍽️ Heritage dining", "🍸 Cocktail lounge", "💆 Spa", "🛍️ Boutique arcade"],
            image: "hub_hotel_taj", vibes: ["Luxury", "Date night"],
            status: .open(until: "Open 24 hours"), stats: [.restaurants(5)], glow: Color(hex: 0x4A70A8)),
        Hub("Baga Beach", type: .beach, locality: "North Goa", distance: "1,880 km",
            blurb: "Goa's liveliest stretch of sand, lined with beach shacks, water sports and sunset parties.",
            chips: ["🏖️ Beach shacks", "🌊 Water sports", "🍹 Sunset bars", "🎶 Live music"],
            image: "hub_beach_baga", vibes: ["Weekend plans", "Chill hangout"],
            status: .open(until: "Shacks close 11 PM"), stats: [.restaurants(24)], glow: Color(hex: 0x4B98B0)),
        Hub("Juhu Beach", type: .beach, locality: "Juhu, Mumbai", distance: "1,410 km",
            blurb: "Mumbai's favourite seaside evening, with street food stalls and sea-facing cafés.",
            chips: ["🌅 Sunset walks", "🍜 Street food", "☕ Sea-facing cafés", "👶 Family friendly"],
            image: "hub_beach_juhu", vibes: ["Family outing", "Foodies"],
            status: .open(until: "Stalls close 11 PM"), stats: [.restaurants(16)], glow: Color(hex: 0xB08D6E)),
        Hub("Chhatrapati Shivaji Maharaj Airport (T2)", type: .airport, locality: "Mumbai", distance: "1,410 km",
            blurb: "Gurgaon's biggest shopping destination with top brands, great cafés and plenty for kids.",
            chips: ["🍽️ Restaurants near gate", "☕ Cafés", "🍸 Bars", "🛍️ Duty free"],
            image: "hub_airport", detailDistance: "28.3km", status: nil,
            stats: [.restaurants(104), .stores(3)], glow: Color(hex: 0xB4AAA8), brandLogo: "hub_logo_adani"),
        Hub("AIPL Business Club", type: .business, locality: "Sector-58, Gurgaon", distance: "28 km",
            blurb: "Premium Grade A office spaces with cafés, dining and business amenities in Gurugram.",
            chips: ["🏢 Grade A offices", "☕ Cafés", "🍽️ Restaurants", "🅿️ Parking"],
            image: "hub_aipl", detailDistance: "28.3km", rating: nil,
            stats: [.restaurants(7), .stores(59)], glow: Color(hex: 0x7F89BE)),
        Hub("Sunder Nursery", type: .park, locality: "Rabindra Nagar, New Delhi", distance: "28 km",
            blurb: "Perfect for picnics, peaceful walks, heritage views and a couple of lovely cafés.",
            chips: ["🌳 Heritage garden", "🧺 Picnic spots", "☕ Garden cafés", "🌸 Seasonal blooms"],
            image: "hub_sunder", vibes: ["Family outing", "Chill hangout", "Date night"],
            detailDistance: "28.3km", status: nil, stats: [.restaurants(7)], glow: Color(hex: 0x8D6D4B)),
    ]

    static func hub(named name: String) -> Hub? { hubs.first { $0.name == name } }

    /// The landing's rail. Omaxe sits out: its photo's black lower band only works under the listing card's fade.
    static let nearby: [Hub] = ["Good City Centre", "Cyber Hub", "Galleria Market", "MGF Metropolitan Mall", "Ambience Mall", "Select Citywalk"]
        .compactMap(hub(named:))

    // MARK: Places

    static let places: [HubPlace] = [
        HubPlace(name: "Staple Bar and Bistro", kinds: [.restaurant, .bar], photo: "hub_place_staple",
                 isNew: true, cuisine: "Italian", price: "₹1000 for two", tags: ["Casual", "Dim lights"]),
        HubPlace(name: "The Velvet Lounge", kinds: [.restaurant, .bar], photo: "hub_place_velvet",
                 rating: "4.1", cuisine: "Fusion", floor: 2, price: "₹1000 for two", offer: "Happy Hour 20% OFF", tags: ["Dim lights", "Fine Dining"]),
        HubPlace(name: "Bigg chill cafe", kinds: [.restaurant, .dessert], photo: "hub_place_bigchill", logo: "hub_logo_bigchill",
                 rating: "4.2", cuisine: "Fusion", price: "₹1000 for two", tags: ["Popular", "Casual", "Dim lights", "Under 5km"]),
        HubPlace(name: "Zambar", kinds: [.restaurant], photo: "hub_place_zambar", logo: "hub_logo_zambar",
                 rating: "4.2", cuisine: "Italian", price: "₹1000 for two", tags: ["Popular", "Fine Dining"]),
        HubPlace(name: "The Potbelly Divine", kinds: [.restaurant], photo: "hub_place_potbelly",
                 rating: "4.4", isAd: true, cuisine: "Indian", price: "₹800 for two", tags: ["Popular", "Casual", "Under 5km"]),
        HubPlace(name: "Vellam - Elevated Southern Cuisine", kinds: [.restaurant], photo: "hub_place_vellam",
                 rating: "4.3", cuisine: "South Indian", floor: 2, price: "₹1400 for two", tags: ["Fine Dining"]),
        HubPlace(name: "The Brook", kinds: [.restaurant], photo: "hub_place_brook",
                 rating: "4.0", cuisine: "Tibetan", floor: 3, price: "₹900 for two", tags: ["Casual", "Under 5km"]),
        HubPlace(name: "The Drunken Botanist", kinds: [.restaurant, .bar], photo: "hub_place_botanist",
                 rating: "3.9", cuisine: "Continental", floor: 3, price: "₹1800 for two", tags: ["Dim lights"]),
        HubPlace(name: "Wood Fire Pizzeria", kinds: [.restaurant], photo: "hub_place_pizza",
                 rating: "4.3", cuisine: "Pizza", floor: 0, price: "₹700 for two", tags: ["Quick Bites", "Under 5km"]),
        HubPlace(name: "Hearth & Slice", kinds: [.restaurant], photo: "hub_place_oven",
                 rating: "4.1", cuisine: "Italian", floor: 0, price: "₹600 for two", tags: ["Quick Bites"]),
        HubPlace(name: "Cafe Dori", kinds: [.cafe], photo: "hub_place_staple",
                 isNew: true, cuisine: "Italian", price: "₹600 for two", tags: ["Dim lights", "Under 5km"]),
        HubPlace(name: "Corstasso Coffee", kinds: [.cafe], photo: "hub_place_velvet",
                 rating: "4.1", cuisine: "Fusion", floor: 2, price: "₹1000 for two", offer: "Happy Hour 20% OFF", tags: ["Under 5km"]),
        HubPlace(name: "Meltado", kinds: [.cafe, .dessert], photo: "hub_place_velvet",
                 rating: "4.1", cuisine: "Fusion", floor: 3, price: "₹1000 for two", offer: "Happy Hour 20% OFF", tags: ["Dim lights"]),
        HubPlace(name: "Zara", kinds: [.store], logo: "hub_logo_zara", cuisine: "Fashion", floor: 3, tags: ["Popular", "Fashion"]),
        HubPlace(name: "Nicobar", kinds: [.store], logo: "logo_nicobar", cuisine: "Ethnic", floor: 3, tags: ["Popular", "Luxury", "Ethnic"]),
        HubPlace(name: "Uniqlo", kinds: [.store], logo: "hub_logo_uniqlo", cuisine: "Fashion", floor: 2, tags: ["Popular", "Fashion"]),
        HubPlace(name: "adidas", kinds: [.store], logo: "hub_logo_adidas", cuisine: "Sports", floor: 3, tags: ["Popular", "Sports"]),
        HubPlace(name: "Chumbak", kinds: [.store], logo: "hub_logo_chumbak", cuisine: "Lifestyle", floor: 1, tags: ["Ethnic", "Fashion"]),
        HubPlace(name: "iSKATE - India's largest rink", kinds: [.entertainment], photo: "hub_place_iskate", logo: "hub_logo_iskate",
                 cuisine: "Ice skating", floor: 2, tags: ["Must-Do", "Sports"]),
        HubPlace(name: "Timezone", kinds: [.entertainment], photo: "hub_rail_timezone", cuisine: "Arcade", floor: 3, tags: ["Must-Do", "Gaming"]),
        HubPlace(name: "Smaash", kinds: [.entertainment], photo: "hub_rail_smaash", cuisine: "Gaming", floor: 3, tags: ["Gaming", "Special Events"]),
        HubPlace(name: "Sky Jumper", kinds: [.entertainment], photo: "hub_rail_skyjumper", cuisine: "Trampoline park", floor: 2, tags: ["Sports", "Must-Do"]),
        HubPlace(name: "Geetanjali salon", kinds: [.salon], photo: "hub_place_geetanjali", logo: "hub_logo_geetanjali", floor: 2,
                 offer: nil, shopNumber: "2nd Floor | Shop 248/249", tags: ["Salons"]),
        HubPlace(name: "Tony & Guy", kinds: [.salon], photo: "hub_place_toni", logo: "hub_logo_toni", floor: 2,
                 offer: nil, shopNumber: "2nd Floor | Shop 250/251", tags: ["Salons", "Spas"]),
    ]

    static func places(_ kind: HubPlace.Kind) -> [HubPlace] { places.filter { $0.kinds.contains(kind) } }

    /// The park's single list, in the Figma's order ("Only 1 tab", 14234:98418).
    static let gardenPlaces: [HubPlace] = ["Cafe Dori", "Corstasso Coffee", "Meltado", "Staple Bar and Bistro", "The Velvet Lounge", "The Brook"]
        .compactMap { name in places.first { $0.name == name } }

    static let hours: [HubHours] = [
        HubHours(day: "Monday", time: "11:00 AM - 10:00 PM"),
        HubHours(day: "Tuesday", time: "11:00 AM - 10:00 PM"),
        HubHours(day: "Wednesday", time: "11:00 AM - 10:00 PM"),
        HubHours(day: "Thursday", time: "11:00 AM - 10:00 PM"),
        HubHours(day: "Friday", time: "11:00 AM - 11:00 PM"),
        HubHours(day: "Saturday", time: "12:00 PM - 11:00 PM"),
        HubHours(day: "Sunday", time: "12:00 PM - 9:00 PM"),
    ]

    static let facilities: [HubFacility] = [
        HubFacility(icon: "hub_fac_water", title: "Free water stations"),
        HubFacility(icon: "hub_fac_washroom", title: "Washrooms"),
        HubFacility(icon: "hub_fac_parking", title: "Free parking"),
        HubFacility(icon: "hub_fac_smoking", title: "Smoking zone"),
        HubFacility(icon: "hub_fac_wifi", title: "Free Wi-Fi"),
        HubFacility(icon: "hub_fac_baby", title: "Baby care room"),
        HubFacility(icon: "hub_fac_atm", title: "ATM"),
        HubFacility(icon: "hub_fac_firstaid", title: "First aid"),
        HubFacility(icon: "hub_fac_elevator", title: "Elevators"),
    ]

    static let floors: [HubFloor] = [
        HubFloor(badge: "", title: "All", floor: nil),
        HubFloor(badge: "UG", title: "Underground", floor: 0),
        HubFloor(badge: "1", title: "1st floor", floor: 1),
        HubFloor(badge: "2", title: "2nd floor", floor: 2),
        HubFloor(badge: "3", title: "3rd floor", floor: 3),
    ]

    static let floorCategories: [HubCategory] = [
        HubCategory(title: "Restaurants", kind: .restaurant, icon: "hub_cat_fork", tint: Color(rgba: 0xDDCEF51A)),
        HubCategory(title: "Shops", kind: .store, icon: "hub_cat_shirt", tint: Color(rgba: 0xEAF8B51A), countNoun: "stores"),
        HubCategory(title: "Bar", kind: .bar, icon: "hub_cat_wine", tint: Color(rgba: 0xE125D11A), countNoun: "bars"),
        HubCategory(title: "Cafes", kind: .cafe, icon: "hub_cat_coffee", tint: Color(rgba: 0xF8BDB51A), countNoun: "cafes"),
    ]

    static let airportTabs = ["All", "Pre-security", "Post-security", "Arrival Hall"]

    static let airportCategories: [HubCategory] = [
        HubCategory(title: "Restaurants near gate", kind: .restaurant, icon: "hub_cat_fork", tint: Color(rgba: 0xB5CFF81A), zone: "Post-security"),
        HubCategory(title: "Restaurants", kind: .restaurant, icon: "hub_cat_fork", tint: Color(rgba: 0xB5CFF81A), zone: "Pre-security"),
        HubCategory(title: "Cafes", kind: .cafe, icon: "hub_cat_coffee", tint: Color(rgba: 0xF8BDB51A), zone: "Post-security"),
        HubCategory(title: "Bar", kind: .bar, icon: "hub_cat_wine", tint: Color(rgba: 0xD464C71A), zone: "Post-security"),
        HubCategory(title: "Shops", kind: .store, icon: "hub_cat_shirt", tint: Color(rgba: 0xEAF8B51A), zone: "Post-security", countNoun: "stores"),
        HubCategory(title: "Cafes", kind: .cafe, icon: "hub_cat_coffee", tint: Color(rgba: 0xF8BDB51A), zone: "Arrival Hall"),
    ]

    /// Section chips on the mall page's Top finds.
    static let offerFilters: [(title: String, kind: HubPlace.Kind)] = [
        ("Restaurants", .restaurant), ("Shops", .store), ("Bar", .bar), ("Cafes", .cafe), ("Entertainment", .entertainment),
    ]
}
