//
//  PostRequest+Discover.swift
//  newtabnews
//

import Foundation

extension PostRequest {
    var isRootPost: Bool {
        parentId == nil && title?.isEmpty == false
    }

    func postDate() -> Date? {
        guard let createdAt else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: createdAt) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }

    func ageInDays() -> Int? {
        guard let date = postDate() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day
        return days
    }

    func isOlderThan(days: Int) -> Bool {
        guard let age = ageInDays() else { return false }
        return age > days
    }

    func isWithinAgeRange(minDays: Int?, maxDays: Int?) -> Bool {
        guard let age = ageInDays() else { return false }

        if let minDays, age < minDays {
            return false
        }

        if let maxDays, age > maxDays {
            return false
        }

        return true
    }

    func matchesDiscover(
        minTabcoins: Int,
        minAgeDays: Int? = nil,
        maxAgeDays: Int? = nil
    ) -> Bool {
        guard isRootPost else { return false }
        guard (tabcoins ?? 0) >= minTabcoins else { return false }
        return isWithinAgeRange(minDays: minAgeDays, maxDays: maxAgeDays)
    }
}

extension Array where Element == PostRequest {
    func rootPostsOnly() -> [PostRequest] {
        filter { $0.isRootPost }
    }

    func sortedByTabcoinsDescending() -> [PostRequest] {
        sorted { ($0.tabcoins ?? 0) > ($1.tabcoins ?? 0) }
    }

    func excludingKeys(_ usedKeys: Set<String>) -> [PostRequest] {
        filter { !usedKeys.contains($0.stableKey) }
    }

    func topDiscoverPosts(
        limit: Int,
        minTabcoins: Int,
        minAgeDays: Int? = nil,
        maxAgeDays: Int? = nil,
        excluding usedKeys: Set<String> = []
    ) -> ([PostRequest], Set<String>) {
        var updatedKeys = usedKeys
        let selected = rootPostsOnly()
            .excludingKeys(updatedKeys)
            .filter { $0.matchesDiscover(minTabcoins: minTabcoins, minAgeDays: minAgeDays, maxAgeDays: maxAgeDays) }
            .sortedByTabcoinsDescending()
            .prefix(limit)

        let posts = Array(selected)
        posts.forEach { updatedKeys.insert($0.stableKey) }
        return (posts, updatedKeys)
    }

    /// Mistura duas fatias (ex.: clássicos antigos + clássicos de ~1 mês) e completa por tabcoins.
    func topDiscoverPostsMixed(
        limit: Int,
        primaryLimit: Int,
        primary: (posts: [PostRequest], minTabcoins: Int, minAgeDays: Int?, maxAgeDays: Int?),
        secondary: (posts: [PostRequest], minTabcoins: Int, minAgeDays: Int?, maxAgeDays: Int?),
        excluding usedKeys: Set<String> = []
    ) -> ([PostRequest], Set<String>) {
        var updatedKeys = usedKeys

        let primaryPick = primary.posts
            .rootPostsOnly()
            .excludingKeys(updatedKeys)
            .filter {
                $0.matchesDiscover(
                    minTabcoins: primary.minTabcoins,
                    minAgeDays: primary.minAgeDays,
                    maxAgeDays: primary.maxAgeDays
                )
            }
            .sortedByTabcoinsDescending()
            .prefix(primaryLimit)

        primaryPick.forEach { updatedKeys.insert($0.stableKey) }

        let secondaryPick = secondary.posts
            .rootPostsOnly()
            .excludingKeys(updatedKeys)
            .filter {
                $0.matchesDiscover(
                    minTabcoins: secondary.minTabcoins,
                    minAgeDays: secondary.minAgeDays,
                    maxAgeDays: secondary.maxAgeDays
                )
            }
            .sortedByTabcoinsDescending()
            .prefix(primaryLimit)

        secondaryPick.forEach { updatedKeys.insert($0.stableKey) }

        let combined = Array(primaryPick) + Array(secondaryPick)

        if combined.count >= limit {
            let trimmed = Array(combined.sortedByTabcoinsDescending().prefix(limit))
            return (trimmed, updatedKeys)
        }

        let allPools = primary.posts + secondary.posts
        let filler = allPools
            .rootPostsOnly()
            .excludingKeys(updatedKeys)
            .filter {
                $0.matchesDiscover(
                    minTabcoins: Swift.min(primary.minTabcoins, secondary.minTabcoins),
                    minAgeDays: nil,
                    maxAgeDays: nil
                )
            }
            .sortedByTabcoinsDescending()

        var result = combined
        for post in filler {
            guard result.count < limit else { break }
            result.append(post)
            updatedKeys.insert(post.stableKey)
        }

        return (Array(result.sortedByTabcoinsDescending().prefix(limit)), updatedKeys)
    }
}
