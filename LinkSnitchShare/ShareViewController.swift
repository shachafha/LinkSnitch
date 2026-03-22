import UIKit
import UniformTypeIdentifiers
import AVFoundation

final class ShareViewController: UIViewController {
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let explanationLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureLayout()
        configureInitialState()
        processSharedItem()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.numberOfLines = 1

        explanationLabel.font = .preferredFont(forTextStyle: .body)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0

        doneButton.configuration = .filled()
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true
    }

    private func configureLayout() {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            statusLabel,
            explanationLabel,
            doneButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [stackView, activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    private func configureInitialState() {
        titleLabel.text = "Link Check"
        statusLabel.text = "Analyzing..."
        statusLabel.textColor = .secondaryLabel
        explanationLabel.text = "Reviewing the shared link for phishing signals."
        doneButton.isEnabled = false
        activityIndicator.startAnimating()
    }

    private func processSharedItem() {
        loadSharedURL { [weak self] urlString in
            guard let self else { return }

            DispatchQueue.main.async {
                let presentation: AnalysisPresentation

                if let urlString {
                    let analysis = URLAnalyzer.analyze(urlString: urlString)
                    presentation = ExplanationGenerator.generate(for: analysis)
                } else {
                    let fallback = URLAnalysis(
                        originalURL: "",
                        host: nil,
                        registeredDomain: nil,
                        status: .warning,
                        findings: ["No shareable link was found."]
                    )
                    presentation = ExplanationGenerator.generate(for: fallback)
                }

                self.render(presentation)
                self.speak(text: presentation.explanation)
            }
        }
    }

    private func render(_ presentation: AnalysisPresentation) {
        titleLabel.text = presentation.title
        statusLabel.text = presentation.statusText
        statusLabel.textColor = presentation.statusText == "Warning" ? .systemRed : .systemGreen
        explanationLabel.text = presentation.explanation
        doneButton.isEnabled = true
        activityIndicator.stopAnimating()
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
}
