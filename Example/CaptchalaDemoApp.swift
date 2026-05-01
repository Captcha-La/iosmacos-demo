//
//  CaptchalaDemoApp.swift
//  CaptchalaDemo
//
//  Minimal SwiftUI demo that exercises the Captchala SDK end-to-end:
//    * Presents CaptchalaViewController via CaptchalaClient.verify(from:)
//    * Calls CaptchalaCrypto.sealPayload from CaptchalaCryptoFFI.swift
//
//  The SDK is referenced as a local Swift Package dependency declared in
//  Example.xcodeproj/project.pbxproj -> XCLocalSwiftPackageReference (path
//  ../ios_w5T5K/Captchala).
//

import SwiftUI

@main
struct CaptchalaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
