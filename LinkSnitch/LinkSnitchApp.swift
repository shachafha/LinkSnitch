//
//  LinkSnitchApp.swift
//  LinkSnitch
//
//  Created by shachaf haviv on 22/03/2026.
//

import SwiftUI

@main
struct LinkSnitchApp: App {
    @StateObject private var historyStore = LinkHistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
        }
    }
}
