import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// App root: native tab containers with a custom floating Liquid Glass bar that stays centred and
/// shrinks in place on scroll (the system bar on iOS 26 collapses into a corner instead).
struct ContentView: View {
    enum Destination: Hashable, CaseIterable {
        case stores, explore, search

        var title: String {
            switch self {
            case .explore: "Explore"
            case .search: "Search"
            case .stores: "Stores"
            }
        }

        var icon: String {
            switch self {
            case .explore: "safari"
            case .search: "magnifyingglass"
            case .stores: "bag"
            }
        }

        var selectedIcon: String {
            switch self {
            case .explore: "safari.fill"
            case .search: "magnifyingglass"
            case .stores: "bag.fill"
            }
        }
    }

    @State private var selection: Destination = .stores
    @State private var compact = false

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Destination.allCases, id: \.self) { destination in
                screen(for: destination)
                    .tag(destination)
                    .hidingSystemTabBar()
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
            }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(selection: $selection, compact: compact)
                .padding(.bottom, R.spacingSpace8)
        }
        .environment(\.tabBarCompactHandler, TabBarCompactHandler { value in
            if compact != value { compact = value }
        })
        .onChange(of: selection) { compact = false }
        .tint(M.iconPrimary)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func screen(for destination: Destination) -> some View {
        switch destination {
        case .explore: EditorialView()
        case .search: SearchView()
        case .stores: StoresView()
        }
    }
}

private extension View {
    /// The custom floating bar replaces the system tab bar.
    @ViewBuilder
    func hidingSystemTabBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}

// MARK: - Floating tab bar

struct FloatingTabBar: View {
    @Binding var selection: ContentView.Destination
    let compact: Bool
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassGroup(spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace4) {
                ForEach(ContentView.Destination.allCases, id: \.self) { item in
                    let selected = item == selection
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { selection = item }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: selected ? item.selectedIcon : item.icon)
                                .font(.system(size: compact ? 17 : 19, weight: .semibold))
                            if !compact {
                                Text(item.title)
                                    .backstageText(.finePrint2)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .foregroundStyle(selected ? M.iconPrimary : M.iconSecondary)
                        .frame(width: compact ? 48 : 76, height: compact ? 44 : 54)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(M.surfaceTransparent)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(R.spacingSpace4)
            .liquidGlass(in: Capsule(), interactive: true)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: compact)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

// MARK: - Scroll → compact bar

/// Lets a scrolling screen ask the floating bar to shrink (scrolling down) or expand.
struct TabBarCompactHandler {
    let set: (Bool) -> Void
    init(_ set: @escaping (Bool) -> Void) { self.set = set }
    func callAsFunction(_ value: Bool) { set(value) }
}

private struct TabBarCompactHandlerKey: EnvironmentKey {
    static let defaultValue = TabBarCompactHandler { _ in }
}

extension EnvironmentValues {
    var tabBarCompactHandler: TabBarCompactHandler {
        get { self[TabBarCompactHandlerKey.self] }
        set { self[TabBarCompactHandlerKey.self] = newValue }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
