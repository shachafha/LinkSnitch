import Foundation

struct URLAnalysis {
    enum Status {
        case safe
        case warning

        var title: String {
            switch self {
            case .safe:
                return "Safe"
            case .warning:
                return "Warning"
            }
        }
    }

    let originalURL: String
    let host: String?
    let registeredDomain: String?
    let status: Status
    let findings: [String]
}

struct URLAnalyzer {
    private static let monitoredBrands = ["amazon", "paypal", "netflix", "apple", "google"]
    private static let suspiciousTLDs = ["xyz", "top", "click", "zip"]
    private static let suspiciousKeywords = ["login", "verify", "secure", "account", "update"]

    static func analyze(urlString: String) -> URLAnalysis {
        guard let components = normalizedComponents(from: urlString) else {
            return URLAnalysis(
                originalURL: urlString,
                host: nil,
                registeredDomain: nil,
                status: .warning,
                findings: ["This link could not be parsed safely."]
            )
        }

        let host = normalizedHost(from: components)
        let registeredDomain = registeredDomain(from: host)
        let lowercasedPath = combinedPathAndQuery(from: components)

        var findings: [String] = []

        if let host, isIPAddress(host) {
            findings.append("The link uses an IP address instead of a normal website name.")
        }

        if let host, host.hasPrefix("xn--") || host.contains(".xn--") {
            findings.append("The domain uses punycode, which can hide lookalike characters.")
        }

        if let host, hasTooManySubdomains(host) {
            findings.append("The domain has many subdomains, which is common in disguised phishing links.")
        }

        if let host, hasSuspiciousTLD(host) {
            findings.append("The domain ends with an unusual top-level domain often seen in scam links.")
        }

        if containsSuspiciousKeyword(in: lowercasedPath) {
            findings.append("The link uses urgent account or login language.")
        }

        if let brandFinding = brandMismatchFinding(host: host, pathAndQuery: lowercasedPath) {
            findings.append(brandFinding)
        }

        if let pathOnlyBrandFinding = pathOnlyBrandFinding(host: host, pathAndQuery: lowercasedPath) {
            findings.append(pathOnlyBrandFinding)
        }

        let status: URLAnalysis.Status = findings.isEmpty ? .safe : .warning

        return URLAnalysis(
            originalURL: urlString,
            host: host,
            registeredDomain: registeredDomain,
            status: status,
            findings: findings
        )
    }

    private static func normalizedComponents(from urlString: String) -> URLComponents? {
        if let components = URLComponents(string: urlString), components.host != nil {
            return components
        }

        if let components = URLComponents(string: "https://\(urlString)"), components.host != nil {
            return components
        }

        return nil
    }

    private static func normalizedHost(from components: URLComponents) -> String? {
        components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func combinedPathAndQuery(from components: URLComponents) -> String {
        let path = components.percentEncodedPath.lowercased()
        let query = components.percentEncodedQuery?.lowercased() ?? ""
        return query.isEmpty ? path : "\(path)?\(query)"
    }

    private static func registeredDomain(from host: String?) -> String? {
        guard let host, !host.isEmpty else {
            return nil
        }

        if isIPAddress(host) {
            return host
        }

        let parts = host.split(separator: ".")
        guard parts.count >= 2 else {
            return host
        }

        return parts.suffix(2).joined(separator: ".")
    }

    private static func hasSuspiciousTLD(_ host: String) -> Bool {
        guard let tld = host.split(separator: ".").last?.lowercased() else {
            return false
        }

        return suspiciousTLDs.contains(tld)
    }

    private static func hasTooManySubdomains(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        return parts.count > 4
    }

    private static func containsSuspiciousKeyword(in pathAndQuery: String) -> Bool {
        suspiciousKeywords.contains { pathAndQuery.contains($0) }
    }

    private static func brandMismatchFinding(host: String?, pathAndQuery: String) -> String? {
        guard let host else {
            return nil
        }

        for brand in monitoredBrands {
            let brandInHost = host.contains(brand)
            let brandInPath = pathAndQuery.contains(brand)

            if brandInPath && !brandInHost {
                return "This link mentions \(brand) outside the real domain."
            }

            if brandInHost, let registeredDomain = registeredDomain(from: host), !registeredDomain.contains(brand) {
                return "The address uses \(brand) in the host, but the real domain is \(registeredDomain)."
            }
        }

        return nil
    }

    private static func pathOnlyBrandFinding(host: String?, pathAndQuery: String) -> String? {
        guard let host else {
            return nil
        }

        for brand in monitoredBrands where pathAndQuery.contains(brand) && !host.contains(brand) {
            return "\(brand.capitalized) appears only in the path, not in the domain."
        }

        return nil
    }

    private static func isIPAddress(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else {
            return false
        }

        return parts.allSatisfy { part in
            guard let value = Int(part), (0...255).contains(value) else {
                return false
            }

            return String(value) == part
        }
    }
}
