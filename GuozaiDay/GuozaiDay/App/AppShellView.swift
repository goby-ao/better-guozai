import SwiftUI
import UIKit

enum AppShellLayout {
    case automatic
    case sidebar
    case tabs
}

struct AppShellView: View {
    private let layout: AppShellLayout

    @State private var selectedSidebarDestination: AppDestination? = .today
    @State private var selectedTab: AppDestination = .today

    @State private var todayPath = NavigationPath()
    @State private var growthPath = NavigationPath()
    @State private var badgesPath = NavigationPath()
    @State private var parentPath = NavigationPath()

    init(layout: AppShellLayout = .automatic) {
        self.layout = layout
    }

    var body: some View {
        Group {
            switch resolvedLayout {
            case .sidebar:
                sidebarShell
            case .tabs:
                tabShell
            case .automatic:
                EmptyView()
            }
        }
        .tint(GuozaiColor.oceanDeep)
    }

    private var resolvedLayout: AppShellLayout {
        switch layout {
        case .automatic:
            UIDevice.current.userInterfaceIdiom == .pad ? .sidebar : .tabs
        case .sidebar, .tabs:
            layout
        }
    }

    private var sidebarShell: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarBrandHeader()

                List(selection: $selectedSidebarDestination) {
                    ForEach(AppDestination.allCases) { destination in
                        NavigationLink(value: destination) {
                            SidebarDestinationRow(destination: destination)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background(GuozaiColor.canvasWarm)
            .navigationSplitViewColumnWidth(
                min: GuozaiLayout.sidebarMinimumWidth,
                ideal: GuozaiLayout.sidebarIdealWidth,
                max: GuozaiLayout.sidebarMaximumWidth
            )
        } detail: {
            NavigationStack {
                (selectedSidebarDestination ?? .today).rootView
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            phoneTab(.today, path: $todayPath)
            phoneTab(.growth, path: $growthPath)
            phoneTab(.badges, path: $badgesPath)
            phoneTab(.parent, path: $parentPath)
        }
        .toolbarBackground(GuozaiColor.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private func phoneTab(
        _ destination: AppDestination,
        path: Binding<NavigationPath>
    ) -> some View {
        NavigationStack(path: path) {
            destination.rootView
        }
        .tabItem {
            Label(
                destination.title,
                systemImage: selectedTab == destination
                    ? destination.selectedSystemImage
                    : destination.systemImage
            )
        }
        .tag(destination)
    }
}

private struct SidebarBrandHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            HStack(spacing: GuozaiSpacing.small) {
                ZStack {
                    Circle()
                        .fill(GuozaiColor.mangoSoft)

                    Image(systemName: "sun.max.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(GuozaiColor.mango)
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                Text("果仔的一天")
                    .guozaiTextStyle(.sectionTitle)
                    .foregroundStyle(GuozaiColor.oceanDeep)
            }

            Text("每天一点点，长成自己的样子")
                .guozaiTextStyle(.supporting)
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, GuozaiSpacing.large)
        .padding(.top, GuozaiSpacing.xLarge)
        .padding(.bottom, GuozaiSpacing.medium)
        .accessibilityElement(children: .combine)
    }
}

private struct SidebarDestinationRow: View {
    let destination: AppDestination

    var body: some View {
        Label(destination.title, systemImage: destination.systemImage)
            .guozaiTextStyle(.body)
            .foregroundStyle(GuozaiColor.ink)
            .frame(maxWidth: .infinity, minHeight: GuozaiLayout.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(destination.title))
    }
}
