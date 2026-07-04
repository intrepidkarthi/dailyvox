//
//  ContentView.swift
//  solyn
//
//  Main tab-based navigation container for the app.
//
//  Created by Karthikeyan NG on 01/12/25.
//

import SwiftUI
import CoreData

/// Main content view with tab-based navigation.
/// Uses TabView on all devices. On iPadOS 18+, the tab bar adapts to a sidebar.
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Record", systemImage: "mic.circle.fill")
            }

            NavigationStack {
                TimelineView()
            }
            .tabItem {
                Label("Journal", systemImage: "book.closed.fill")
            }

            NavigationStack {
                DigitalTwinView()
            }
            .tabItem {
                Label("Twin", systemImage: "star.circle.fill")
            }

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Insights", systemImage: "sparkle.magnifyingglass")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .onAppear {
            // On iOS 26+, let the system render the native Liquid Glass tab bar.
            // A manual UITabBarAppearance override forces an opaque background and
            // defeats the glass material, so we only apply the warm configured
            // appearance on releases before iOS 26.
            if #available(iOS 26.0, *) {
                // No override — inherit the native Liquid Glass tab bar.
            } else {
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
