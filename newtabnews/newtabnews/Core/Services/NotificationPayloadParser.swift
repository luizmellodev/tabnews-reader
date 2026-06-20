//
//  NotificationPayloadParser.swift
//  newtabnews
//

import Foundation

struct ParsedNotificationPayload {
    let title: String
    let body: String
    let type: String?
    let owner: String?
    let slug: String?
    let stableId: String
    
    var hasContent: Bool {
        !title.isEmpty || !body.isEmpty
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "title": title,
            "body": body
        ]
        if let type { info["type"] = type }
        if let owner { info["owner"] = owner }
        if let slug { info["slug"] = slug }
        return info
    }
}

enum NotificationPayloadParser {
    static func parse(_ userInfo: [AnyHashable: Any]) -> ParsedNotificationPayload {
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"]
        
        var title = userInfo["title"] as? String
            ?? userInfo["gcm.notification.title"] as? String
            ?? ""
        var body = userInfo["body"] as? String
            ?? userInfo["gcm.notification.body"] as? String
            ?? ""
        
        if let alertString = alert as? String {
            if body.isEmpty { body = alertString }
        } else if let alertDict = alert as? [String: Any] {
            if title.isEmpty { title = alertDict["title"] as? String ?? "" }
            if body.isEmpty { body = alertDict["body"] as? String ?? "" }
        }
        
        let type = userInfo["type"] as? String
        let owner = userInfo["owner"] as? String
        let slug = userInfo["slug"] as? String
        
        let stableId = [
            type ?? "notification",
            owner ?? "",
            slug ?? "",
            title,
            body
        ].joined(separator: "|")
        
        return ParsedNotificationPayload(
            title: title.isEmpty ? "TabNews" : title,
            body: body,
            type: type,
            owner: owner,
            slug: slug,
            stableId: stableId
        )
    }
}
