import UIKit
import UniformTypeIdentifiers
import AVFoundation

final class ShareViewController: UIViewController {
    private struct ResultStyle {
        let title: String
        let iconName: String
        let gradientColors: [UIColor]

        static let loading = ResultStyle(
            title: "Analyzing...",
            iconName: "hourglass",
            gradientColors: [
                UIColor.systemGray5,
                UIColor.systemGray4
            ]
        )

        static let safe = ResultStyle(
            title: "Safe",
            iconName: "checkmark.circle.fill",
            gradientColors: [
                UIColor.systemMint.withAlphaComponent(0.95),
                UIColor.systemGreen.withAlphaComponent(0.9),
                UIColor.systemTeal.withAlphaComponent(0.98)
            ]
        )

        static let warning = ResultStyle(
            title: "Warning",
            iconName: "exclamationmark.triangle.fill",
            gradientColors: [
                UIColor.systemYellow.withAlphaComponent(0.9),
                UIColor.systemOrange.withAlphaComponent(0.95)
            ]
        )
    }

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let gradientLayer = CAGradientLayer()

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let explanationLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let footerLabel = UILabel()
    private let contentStackView = UIStackView()
    private let scrollView = UIScrollView()

    private var hasRenderedResult = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureLayout()
        configureInitialState()
        processSharedItem()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func configureView() {
        view.layer.insertSublayer(gradientLayer, at: 0)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.white.withAlphaComponent(0.96)
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 102, weight: .bold)
        iconView.layer.shadowColor = UIColor.black.withAlphaComponent(0.2).cgColor
        iconView.layer.shadowOpacity = 1
        iconView.layer.shadowRadius = 10
        iconView.layer.shadowOffset = CGSize(width: 0, height: 4)

        titleLabel.font = .systemFont(ofSize: 42, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        explanationLabel.font = .systemFont(ofSize: 18, weight: .medium)
        explanationLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0

        doneButton.configuration = .filled()
        doneButton.configuration?.title = "Done"
        doneButton.configuration?.baseBackgroundColor = .white
        doneButton.configuration?.baseForegroundColor = .label
        doneButton.configuration?.cornerStyle = .capsule
        doneButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        doneButton.layer.shadowOpacity = 1
        doneButton.layer.shadowRadius = 10
        doneButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        doneButton.isEnabled = false

        footerLabel.text = "LinkSnitch"
        footerLabel.font = .systemFont(ofSize: 13, weight: .medium)
        footerLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        footerLabel.textAlignment = .center

        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 34
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        [iconView, titleLabel, explanationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.addArrangedSubview($0)
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        [doneButton, footerLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -24),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 28),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -28),
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStackView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -56),

            iconView.heightAnchor.constraint(equalToConstant: 108),
            iconView.widthAnchor.constraint(equalToConstant: 108),

            doneButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            doneButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            doneButton.heightAnchor.constraint(equalToConstant: 52),
            doneButton.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -14),

            footerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            explanationLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            explanationLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor)
        ])
    }

    private func configureInitialState() {
        apply(style: .loading, explanation: "Reviewing this link for phishing signals.")
        contentStackView.alpha = 0
        doneButton.alpha = 0
        footerLabel.alpha = 0
    }

    private func processSharedItem() {
        loadSharedURL { [weak self] urlString in
            guard let self else { return }

            DispatchQueue.main.async {
                let presentation: AnalysisPresentation
                let style: ResultStyle

                if let urlString {
                    let analysis = URLAnalyzer.analyze(urlString: urlString)
                    presentation = ExplanationGenerator.generate(for: analysis)
                    style = analysis.status == .safe ? .safe : .warning
                    self.saveHistoryEntry(urlString: urlString, analysis: analysis, explanation: presentation.explanation)
                } else {
                    let fallback = URLAnalysis(
                        originalURL: "",
                        host: nil,
                        registeredDomain: nil,
                        status: .warning,
                        findings: ["No shareable link was found."]
                    )
                    presentation = ExplanationGenerator.generate(for: fallback)
                    style = .warning
                }

                self.updateUI(with: presentation, style: style)
            }
        }
    }

    private func updateUI(with result: AnalysisPresentation, style: ResultStyle) {
        apply(style: style, explanation: result.explanation)
        doneButton.isEnabled = true

        if !hasRenderedResult {
            hasRenderedResult = true

            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
                self.contentStackView.alpha = 1
                self.doneButton.alpha = 1
                self.footerLabel.alpha = 1
            } completion: { _ in
                self.speak(text: result.explanation)
            }

            return
        }

        speak(text: result.explanation)
    }

    private func apply(style: ResultStyle, explanation: String) {
        gradientLayer.colors = style.gradientColors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        iconView.image = UIImage(systemName: style.iconName)
        titleLabel.text = style.title
        explanationLabel.text = explanation
    }

    private func speak(text: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let warningPrefix = "Warning"
        if text.hasPrefix(warningPrefix) {
            let remainder = text.dropFirst(warningPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)

            let warningUtterance = makeUtterance(for: warningPrefix)
            warningUtterance.postUtteranceDelay = 0.25
            speechSynthesizer.speak(warningUtterance)

            if !remainder.isEmpty {
                speechSynthesizer.speak(makeUtterance(for: remainder))
            }

            return
        }

        speechSynthesizer.speak(makeUtterance(for: text))
    }

    private func makeUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        return utterance
    }

    private func loadSharedURL(completion: @escaping (String?) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments,
              !attachments.isEmpty else {
            completion(nil)
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, error in
                    if let error {
                        print("Error loading URL item: \(error)")
                        completion(nil)
                        return
                    }

                    if let url = item as? URL {
                        completion(url.absoluteString)
                        return
                    }

                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8) {
                        completion(urlString)
                        return
                    }

                    completion(nil)
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(textType) {
                provider.loadItem(forTypeIdentifier: textType, options: nil) { item, error in
                    if let error {
                        print("Error loading text item: \(error)")
                        completion(nil)
                        return
                    }

                    if let text = item as? String {
                        completion(text)
                        return
                    }

                    if let url = item as? URL {
                        completion(url.absoluteString)
                        return
                    }

                    completion(nil)
                }
                return
            }
        }

        completion(nil)
    }

    @objc
    private func doneButtonTapped() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func saveHistoryEntry(urlString: String, analysis: URLAnalysis, explanation: String) {
        HistoryPersistence.save(
            urlString: urlString,
            domain: historyDomain(for: urlString, analysis: analysis),
            isSafe: analysis.status == .safe,
            explanation: explanation
        )
    }

    private func historyDomain(for urlString: String, analysis: URLAnalysis) -> String {
        if let domain = analysis.registeredDomain ?? analysis.host {
            return domain
        }

        return urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum HistoryPersistence {
    private struct PersistedLinkCheck: Codable {
        let id: UUID
        let urlString: String
        let domain: String
        let isSafe: Bool
        let explanation: String
        let date: Date
    }

    private static let storageKey = "link_check_history"
    private static let defaults = UserDefaults(suiteName: "group.com.shachafhaviv.LinkSnitch") ?? .standard

    static func save(urlString: String, domain: String, isSafe: Bool, explanation: String) {
        let check = PersistedLinkCheck(
            id: UUID(),
            urlString: urlString,
            domain: domain,
            isSafe: isSafe,
            explanation: explanation,
            date: Date()
        )

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var checks: [PersistedLinkCheck] = []

        if let data = defaults.data(forKey: storageKey),
           let decodedChecks = try? decoder.decode([PersistedLinkCheck].self, from: data) {
            checks = decodedChecks
        }

        checks.insert(check, at: 0)

        if let data = try? encoder.encode(checks) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
