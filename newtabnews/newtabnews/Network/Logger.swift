//
//  Logger.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/03/25.
//

import Foundation

class Logger {
    static func info(_ message: String) {
        #if DEBUG
        print("\n\("🌟".greenColor) \(message)\n")
        #endif
    }
    
    static func error(_ message: String) {
        #if DEBUG
        print("\n\("🚨".redColor) \(message)\n")
        #endif
    }
    
    static func separator() {
        #if DEBUG
        print("\n\("-----------------------------".yellowColor)\n")
        #endif
    }
    
    static func prettyPrintJSON(from data: Data) {
        #if DEBUG
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            info("✅ Response received:\n\(prettyString)")
        } else {
            info("✅ Response received (raw):\n\(String(data: data, encoding: .utf8) ?? "❌ Invalid UTF-8")")
        }
        separator()
        #endif
    }
}

extension String {
    var redColor: String { return "\u{001B}[0;31m\(self)\u{001B}[0;39m" }
    var greenColor: String { return "\u{001B}[0;32m\(self)\u{001B}[0;39m" }
    var yellowColor: String { return "\u{001B}[0;33m\(self)\u{001B}[0;39m" }
    var blueColor: String { return "\u{001B}[0;34m\(self)\u{001B}[0;39m" }
}
