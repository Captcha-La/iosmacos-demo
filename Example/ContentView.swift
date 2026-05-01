//
//  ContentView.swift
//  CaptchalaDemo
//
//  Entry UI. Tap "Verify with Captcha" to run the full flow.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Captchala

// The demo is UIKit-based (iOS + Mac Catalyst). The Xcode project's
// SUPPORTED_PLATFORMS declares iphoneos/iphonesimulator + SUPPORTS_MACCATALYST=YES,
// so under normal conditions we never land on a pure-macOS slice. The
// #if canImport(UIKit) guard is defensive — if a downstream environment
// retargets to native macOS, we still compile and surface a clear notice
// instead of stalling SwiftPM resolution.

#if canImport(UIKit)

// MARK: - App configuration

enum DemoConfig {
    /// demo_app is special: the backend's force_type / force_difficulty gate
    /// only allows this app_key to override challenge type/difficulty from
    /// the client. In production, integrators MUST NOT control difficulty
    /// from the client — once you swap in your own app_key, the panel's
    /// type selector is ignored and the risk engine auto-routes
    /// (slider / passive / etc).
    static let appKey: String = "demo_app"
    static let action: String = "login"
    static let theme: String = "light"
    static let lang: String = ""
    /// Integrator's business UID. In a real integration this should come
    /// from the logged-in session; demo hardcodes a sample value.
    static let demoUid: String = "demo-user-12345"
    /// In production, point this at your own backend endpoint. Your backend
    /// holds the credentials and proxies to the Captchala server API,
    /// then returns the resulting token to the app. For convenience the
    /// demo hits the dashboard demo endpoint directly.
    static let tokenEndpoint: String =
        "https://demo-v1.captcha.la/demo/issue-captcha-token"
}

/// Fetches a one-shot server_token from the integrator backend (dashboard
/// demo backend in this sample). Production apps should call their own
/// backend, which proxies to the Captchala server API.
func fetchServerToken() async -> String? {
    guard let url = URL(string:
        "\(DemoConfig.tokenEndpoint)?app_key=\(DemoConfig.appKey)" +
        "&action=\(DemoConfig.action)&uid=\(DemoConfig.demoUid)") else {
        return nil
    }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = json["data"] as? [String: Any],
              let token = body["server_token"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    } catch {
        return nil
    }
}

/// Simulates the integrator backend: takes the pass_token and validates
/// uid binding. In a real integration this step must run on the
/// integrator's own backend (which holds the app secret).
/// Returns a human-readable description string for UI display.
func validatePassToken(_ passToken: String) async -> String {
    guard let url = URL(string: "https://demo-v1.captcha.la/demo/validate-pass-token") else {
        return "validate failed: bad url"
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let form = "app_key=\(DemoConfig.appKey)&pass_token=\(passToken)&expected_uid=\(DemoConfig.demoUid)"
    req.httpBody = form.data(using: .utf8)
    do {
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = json["data"] as? [String: Any] else {
            return "validate failed: no data"
        }
        let valid = body["valid"] as? Bool ?? false
        if !valid {
            return "validate: invalid — \(body["error"] ?? "unknown")"
        }
        let uid = body["uid"] as? String ?? "(null)"
        let match = body["uid_match"] as? Bool ?? false
        return "validate: valid=true, uid=\(uid), match=\(match ? "✓" : "✗")"
    } catch {
        return "validate failed: \(error.localizedDescription)"
    }
}

// MARK: - Delegate bridge (NSObject so @objc protocol conformance works)

final class CaptchaDelegateBridge: NSObject, CaptchalaDelegate {

    /// Swift closures invoked from the Captchala delegate callbacks.
    var onSuccess: ((CaptchalaResult) -> Void)?
    var onFailure: ((CaptchalaError) -> Void)?
    var onClose:   (() -> Void)?

    func captcha(didSucceedWith result: CaptchalaResult) {
        onSuccess?(result)
    }

    func captcha(didFailWithError error: CaptchalaError) {
        onFailure?(error)
    }

    // Optional callbacks — forwarded for completeness.
    func captcha(didFailWith error: CaptchalaError) {
        onFailure?(error)
    }

    func captchaDidClose() {
        onClose?()
    }
}

// MARK: - ContentView

struct ContentView: View {

    // MARK: State

    @State private var result: String = "Tap to verify"
    @State private var isVerifying: Bool = false

    // Full config panel mirroring the Flutter demo. None of these
    // widgets are .disabled(isVerifying); they remain interactive.
    @State private var action: String = "login"
    @State private var lang: String = "" // Auto (system)
    @State private var theme: String = "light"
    @State private var enableVoice: Bool = true
    @State private var enableOfflineMode: Bool = true
    @State private var maskClosable: Bool = false

    private let actions: [String] = ["login", "register", "pay"]
    private let languages: [(label: String, value: String)] = [
        ("Auto (system)",    ""),
        ("简体中文",         "zh-CN"),
        ("繁體中文",         "zh-TW"),
        ("English",          "en"),
        ("日本語",           "ja"),
        ("한국어",           "ko"),
        ("Bahasa Melayu",    "ms"),
        ("Tiếng Việt",       "vi"),
        ("Bahasa Indonesia", "id"),
    ]
    private let themes: [String] = ["light", "dark", "system"]

    // The delegate bridge must outlive the verify call — store it in a
    // @StateObject-style holder so SwiftUI keeps a strong reference across
    // re-renders. A plain `let` on a value-type view would vanish.
    @State private var delegateBridge = CaptchaDelegateBridge()

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("CaptchaLa Demo")
                    .font(.largeTitle)
                    .bold()

                // MARK: - Config panel (mirrors Flutter demo)
                // Pickers + Toggles intentionally remain enabled while
                // verification is running.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Config (try tapping while captcha is loading)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    labeledPicker("Action",     value: $action,           options: actions.map { ($0, $0) })
                    labeledPicker("Language",   value: $lang,             options: languages)
                    labeledPicker("Theme",      value: $theme,            options: themes.map { ($0, $0) })

                    Toggle("Enable voice fallback",  isOn: $enableVoice)
                    Toggle("Enable offline mode",    isOn: $enableOfflineMode)
                    Toggle("Mask click closes",      isOn: $maskClosable)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                // MARK: - Captcha verify

            Button(action: startVerification) {
                HStack {
                    if isVerifying { ProgressView() }
                    Text(isVerifying ? "Verifying…" : "Verify with Captcha")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isVerifying)

            VStack(alignment: .leading, spacing: 4) {
                Text("Result").font(.caption.bold())
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

                Spacer()
            }
            .padding()
        }
    }

    @ViewBuilder
    private func labeledPicker(_ label: String,
                               value: Binding<String>,
                               options: [(label: String, value: String)]) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .font(.footnote)
            Picker(label, selection: value) {
                ForEach(options, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func startVerification() {
        guard let presenter = Self.topViewController() else {
            result = "Error: no key window / presenter available"
            return
        }

        // Wire delegate closures to @State.
        delegateBridge.onSuccess = { r in
            isVerifying = false
            let base = """
            pass_token: \(r.passToken)
            challenge_id: \(r.challengeId)
            ttl: \(r.ttl)s
            offline: \(r.isOffline), clientOnly: \(r.isClientOnly)
            """
            result = base + "\n\n(validating pass_token with backend...)"
            // Simulated integrator-side validation: in real integrations, the
            // pass_token is submitted to your business backend (login / order / etc.)
            Task { @MainActor in
                let info = await validatePassToken(r.passToken)
                result = base + "\n\n" + info
            }
        }
        delegateBridge.onFailure = { e in
            isVerifying = false
            result = "ERROR [\(e.code)]: \(e.message)"
        }
        delegateBridge.onClose = {
            // Only set if we weren't already resolved — the SDK emits close
            // alongside success/failure in some flows.
            if isVerifying {
                isVerifying = false
                result = "Closed before completion"
            }
        }

        isVerifying = true
        result = "Fetching server_token…"

        Task { @MainActor in
            // 1) Fetch a one-shot server_token from the integrator backend (dash in this demo)
            let initialToken = await fetchServerToken()
            if initialToken == nil {
                result = "⚠︎ server_token unavailable; continuing without binding (production must block)"
            } else {
                result = "Starting with server_token…"
            }

            let configBuilder = CaptchalaConfigBuilder()
                .appKey(DemoConfig.appKey)
                .action(action)
                .theme(theme)
                .lang(lang)
                .enableVoice(enableVoice)
                .enableOfflineMode(enableOfflineMode)
                // One-shot server token with auto-refresh on expiry.
                .serverToken(initialToken)
                .onServerTokenExpired { await fetchServerToken() }
            let config = configBuilder.build()

            CaptchalaClient.shared
                .initialize(config: config)
                .setDelegate(delegateBridge)
                .verify(from: presenter)
        }
    }

    // MARK: - Helpers

    /// Walks the active UIWindowScene's windows to find the topmost
    /// presented view controller.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter     { $0.activationState == .foregroundActive }

        guard let keyWindow = scenes
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
              ?? scenes.first?.windows.first
        else { return nil }

        var vc = keyWindow.rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }
}

#Preview {
    ContentView()
}

#else

// Pure-macOS fallback (no UIKit). The demo is designed for Catalyst,
// not native macOS. Real native-macOS integration uses the NSWindow path.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("FP Captcha Demo")
                .font(.largeTitle).bold()
            Text("This demo only supports iOS / Mac Catalyst.")
            Text("Pick \"My Mac (Mac Catalyst)\" in the Scheme destination.")
                .font(.system(.footnote, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

#endif
