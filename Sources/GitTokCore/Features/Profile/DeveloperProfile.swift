import Foundation

public enum ContributionGoal: String, Codable, CaseIterable, Sendable {
    case firstContribution, learnCodebase, developSkills, findCommunity
    public var title: String {
        switch self {
        case .firstContribution: "Make my first contribution"
        case .learnCodebase: "Understand an unfamiliar codebase"
        case .developSkills: "Build skills through real projects"
        case .findCommunity: "Find a project to return to"
        }
    }
}
public struct DeveloperProfile: Codable, Equatable, Sendable {
    public var knownTechnologies: [String]
    public var learningTechnologies: [String]
    public var domains: [String]
    public var goal: ContributionGoal?
    public init(knownTechnologies: [String] = [], learningTechnologies: [String] = [], domains: [String] = [], goal: ContributionGoal? = nil) {
        self.knownTechnologies = Self.unique(knownTechnologies)
        self.learningTechnologies = Self.unique(learningTechnologies)
        self.domains = Self.unique(domains)
        self.goal = goal
    }
    public var interests: [String] { Self.unique(knownTechnologies + learningTechnologies + domains) }
    static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
public enum OnboardingStep: Int, Codable, CaseIterable, Sendable { case welcome, skills, learning, domains, goals }
public struct OnboardingDraft: Codable, Equatable, Sendable {
    public var step: OnboardingStep
    public var profile: DeveloperProfile
    public init(step: OnboardingStep = .welcome, profile: DeveloperProfile = DeveloperProfile()) { self.step = step; self.profile = profile }
}
public enum PreferenceOwner: Hashable, Sendable {
    case guest
    case account(instance: String, userID: String)
    public var storageID: String {
        switch self {
        case .guest: "guest"
        case let .account(instance, userID): "account." + Data((instance + "\0" + userID).utf8).base64EncodedString()
        }
    }
}

public enum OnboardingDisposition: String, Codable, Sendable { case notStarted, completed, skipped }

/// Shared selection identity for existing, migrated, and newly offered choices.
public enum ProfileSelection {
    public static func contains(_ value: String, in values: [String]) -> Bool {
        values.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }
    public static func options(available: [String], selected: [String]) -> [String] {
        DeveloperProfile.unique(available + selected)
    }
    public static func toggling(_ value: String, in values: [String]) -> [String] {
        contains(value, in: values) ? values.filter { $0.caseInsensitiveCompare(value) != .orderedSame } : values + [value]
    }
}
