import SwiftUI
import AVFoundation
import Combine

struct LinkCheck: Identifiable, Codable, Hashable {
    let id: UUID
    let urlString: String
    let domain: String
    let isSafe: Bool
    let explanation: String
    let date: Date
}

@MainActor
final class LinkHistoryStore: ObservableObject {
    @Published private(set) var checks: [LinkCheck] = []

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        reload()
    }

    func reload() {
        checks = loadChecks()
    }

    func save(check: LinkCheck) {
        var updatedChecks = loadChecks()
        updatedChecks.removeAll { $0.id == check.id }
        updatedChecks.insert(check, at: 0)
        persist(updatedChecks)

        withAnimation(.easeInOut(duration: 0.2)) {
            checks = updatedChecks
        }
    }

    private func loadChecks() -> [LinkCheck] {
        guard let data = Self.defaults.data(forKey: Self.storageKey),
              let checks = try? decoder.decode([LinkCheck].self, from: data) else {
            return []
        }

        return checks.sorted { $0.date > $1.date }
    }

    private func persist(_ checks: [LinkCheck]) {
        guard let data = try? encoder.encode(checks) else {
            return
        }

        Self.defaults.set(data, forKey: Self.storageKey)
    }

    private static let storageKey = "link_check_history"

    // Configure the matching App Group in both targets for true app/extension sharing.
    private static let defaults = UserDefaults(suiteName: "group.com.shachafhaviv.LinkSnitch") ?? .standard
}

struct ContentView: View {
    var body: some View {
        HistoryView()
    }
}

struct HistoryView: View {
    @EnvironmentObject private var historyStore: LinkHistoryStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.checks.isEmpty {
                    ContentUnavailableView(
                        "No links analyzed yet",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Your recent link checks will appear here.")
                    )
                } else {
                    List(historyStore.checks) { check in
                        NavigationLink {
                            LinkCheckDetailView(check: check)
                        } label: {
                            LinkCheckRow(check: check)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recent Checks")
        }
        .onAppear {
            historyStore.reload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                historyStore.reload()
            }
        }
    }
}

private struct LinkCheckRow: View {
    let check: LinkCheck

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: check.isSafe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(check.isSafe ? .green : .yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(check.domain)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(LinkCheckDateFormatter.timestamp(for: check.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct LinkCheckDetailView: View {
    let check: LinkCheck
    @State private var speechPlayer = SpeechPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: check.isSafe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(check.isSafe ? .green : .yellow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.domain)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(LinkCheckDateFormatter.timestamp(for: check.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(check.explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Replay Voice") {
                    speechPlayer.speak(check.explanation)
                }
                .buttonStyle(.borderedProminent)
                .tint(check.isSafe ? .green : .orange)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum LinkCheckDateFormatter {
    static func timestamp(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if abs(date.timeIntervalSince(now)) < 3600 {
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        }

        if calendar.isDateInToday(date) {
            return "Today \(timeFormatter.string(from: date))"
        }

        return dateTimeFormatter.string(from: date)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private final class SpeechPlayer {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let warningPrefix = "Warning"
        if text.hasPrefix(warningPrefix) {
            let remainder = text.dropFirst(warningPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)

            let warningUtterance = makeUtterance(for: warningPrefix)
            warningUtterance.postUtteranceDelay = 0.25
            synthesizer.speak(warningUtterance)

            if !remainder.isEmpty {
                synthesizer.speak(makeUtterance(for: remainder))
            }

            return
        }

        synthesizer.speak(makeUtterance(for: text))
    }

    private func makeUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        return utterance
    }
}

#Preview {
    ContentView()
        .environmentObject(LinkHistoryStore())
}
