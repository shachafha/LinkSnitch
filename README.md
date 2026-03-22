# LinkSnitch

LinkSnitch is a lightweight iOS link checker built to catch obvious phishing signals the moment a URL is shared.

It works in two places:
- `Share Extension`: analyze a link immediately from Safari, Messages, Mail, or any app that exposes the iOS share sheet.
- `Main App`: review a clean history of recent checks with status, explanation, and replayable text-to-speech.

![LinkSnitch Demo](assets/demo.gif)

## Why It Exists

Phishing links are often designed to look familiar at a glance and suspicious only when you slow down.

LinkSnitch makes that slowdown instant:
- it extracts the real destination
- checks for common phishing patterns
- explains the result in plain language
- reads the warning out loud

The goal is not to be a full browser security engine. The goal is fast human-readable signal.

## What The Experience Looks Like

### Safe Result

![Safe Result](assets/safe.png)

### Warning Result

![Warning Result](assets/warning.png)

## Features

- iOS Share Extension for one-tap link analysis
- Bold full-screen result UI for `Safe` and `Warning`
- Spoken explanations using `AVSpeechSynthesizer`
- History screen in the main app for recent analyzed links
- Lightweight persistence using shared `UserDefaults`
- Heuristic phishing detection tuned for clarity, not noise

## Detection Heuristics

LinkSnitch currently looks for:

- brand mismatch for names like `amazon`, `paypal`, `netflix`, `apple`, `google`
- suspicious top-level domains such as `xyz`, `top`, `click`, `zip`
- too many subdomains
- brand names that appear only in the path
- suspicious path keywords like `login`, `verify`, `secure`, `account`, `update`
- raw IP-address URLs
- punycode domains starting with `xn--`

The output is intentionally short and speech-friendly so the result can be understood quickly.

## Architecture

The project is intentionally small and pragmatic.

- [`LinkSnitch/LinkSnitch/ContentView.swift`](LinkSnitch/LinkSnitch/ContentView.swift)
  Main app history UI in SwiftUI, plus lightweight storage and detail playback.
- [`LinkSnitch/LinkSnitch/LinkSnitchApp.swift`](LinkSnitch/LinkSnitch/LinkSnitchApp.swift)
  App entry point.
- [`LinkSnitch/LinkSnitchShare/ShareViewController.swift`](LinkSnitch/LinkSnitchShare/ShareViewController.swift)
  Full-screen share extension result UI, automatic processing, speech, and history save.
- [`LinkSnitch/LinkSnitchShare/URLAnalyzer.swift`](LinkSnitch/LinkSnitch/LinkSnitchShare/URLAnalyzer.swift)
  URL parsing and phishing heuristics.
- [`LinkSnitch/LinkSnitchShare/ExplanationGenerator.swift`](LinkSnitch/LinkSnitch/LinkSnitchShare/ExplanationGenerator.swift)
  Converts analysis into a short human explanation.

## Technical Notes

- Built with `SwiftUI` for the main app and `UIKit` for the share extension screen
- Uses `AVFoundation` for text-to-speech
- Uses App Group-backed `UserDefaults` so the app and extension share history
- Avoids heavy persistence layers like Core Data because the data model is simple

## Flow

1. Share a URL to LinkSnitch.
2. The extension extracts the shared link automatically.
3. `URLAnalyzer` computes phishing signals.
4. `ExplanationGenerator` produces a short explanation.
5. The share UI presents a bold `Safe` or `Warning` result.
6. The explanation is spoken aloud.
7. The result is saved to history for later review in the app.

## Status

This project is intentionally focused: fast, local, readable phishing checks with a polished iOS-native feel.

If you want to extend it, good next steps would be:
- richer URL normalization
- more domain intelligence
- stronger brand impersonation rules
- import/share support from more sources
- test coverage around heuristic edge cases
