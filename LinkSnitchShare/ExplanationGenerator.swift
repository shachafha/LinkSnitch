import Foundation

struct AnalysisPresentation {
    let title: String
    let statusText: String
    let explanation: String
}

struct ExplanationGenerator {
    static func generate(for analysis: URLAnalysis) -> AnalysisPresentation {
        let destination = analysis.registeredDomain ?? analysis.host ?? "an unknown destination"

        switch analysis.status {
        case .safe:
            return AnalysisPresentation(
                title: "Link Check",
                statusText: analysis.status.title,
                explanation: "Safe. This link appears to go to \(destination) and did not show common phishing signals."
            )

        case .warning:
            let reason = analysis.findings.first ?? "It shows phishing-style patterns."
            return AnalysisPresentation(
                title: "Link Check",
                statusText: analysis.status.title,
                explanation: "Warning. This link points to \(destination). \(reason)"
            )
        }
    }
}
