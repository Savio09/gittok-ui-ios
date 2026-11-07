import SwiftUI
import GitTokCore

struct OnboardingFlow: View {
    let preferences: DiscoveryPreferences
    let editing: Bool
    let onFinish: () -> Void
    let onSignIn: () -> Void
    @State private var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AccountSession.self) private var account
    init(preferences: DiscoveryPreferences, editing: Bool = false, onFinish: @escaping () -> Void, onSignIn: @escaping () -> Void) {
        self.preferences = preferences; self.editing = editing; self.onFinish = onFinish; self.onSignIn = onSignIn
        _draft = State(initialValue: preferences.onboardingDraft ?? OnboardingDraft(profile: preferences.profile))
    }
    private let technologies = ["Swift", "SwiftUI", "TypeScript", "JavaScript", "Python", "Go", "Rust", "Java", "Kotlin", "C", "C++", "Dart", "React", "Vue", "Node.js", "Django", "FastAPI", "Gin"]
    private let domains = ["Frontend", "Backend", "Mobile", "Developer tools", "Library", "Command line", "Local-first", "Open source"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrandWordmark(size: 31).padding(.top, 16)
                    if draft.step == .welcome { welcome }
                    else {
                        Text("\(draft.step.rawValue) OF 4 · YOUR DISCOVERY PROFILE").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(Folio.accentText)
                        Text(title).font(Folio.serif(36, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                        Text(subtitle).font(.body).foregroundStyle(Folio.secondary)
                        if draft.step == .goals { goals }
                        else { choices }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 28).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
                .background(Folio.paper)
                .safeAreaInset(edge: .bottom, spacing: 0) { actions }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if draft.step != .welcome { Button("Back", systemImage: "chevron.left") { draft.step = OnboardingStep(rawValue: draft.step.rawValue - 1) ?? .welcome }.accessibilityIdentifier("onboarding.back") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if editing { Button("Cancel") { preferences.discardOnboardingDraft(); onFinish() }.accessibilityIdentifier("onboarding.cancel") }
                        else { Button("Skip for now") { finish(skipped: true) }.accessibilityIdentifier("onboarding.skip") }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }.tint(Folio.accentText)
            .sheet(isPresented: Binding(get: { account.isPresented }, set: { account.isPresented = $0 })) { AccountSheet() }
            .onChange(of: draft) { _, value in preferences.saveOnboardingDraft(value) }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: draft.step)
            .sensoryFeedback(.selection, trigger: draft.profile)
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("OPEN SOURCE.\nPERSONAL CURIOSITY.").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Folio.accentText)
            Text("Find the projects\nworth your time.").font(Folio.serif(44, relativeTo: .largeTitle)).tracking(-1.2).accessibilityAddTraits(.isHeader)
            Text("Get the idea. Follow the evidence. Choose where you want to go deeper.").font(.title3).foregroundStyle(Folio.secondary)
            VStack(alignment: .leading, spacing: 20) {
                welcomeRow("sparkle.magnifyingglass", "Discover with direction", "Tell us what you know and what you want to learn.")
                welcomeRow("play.rectangle", "Understand before you clone", "Short visual walkthroughs make unfamiliar projects easier to explore.")
                welcomeRow("text.magnifyingglass", "Stay close to the source", "Check the evidence behind an explanation, then continue on GitHub.")
            }.padding(20).background(Folio.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Folio.rule))
            if !account.signedIn {
                Button("Already have an account? Sign in", action: onSignIn).font(.footnote.weight(.medium)).frame(minHeight: 44).accessibilityIdentifier("onboarding.sign-in")
            }
        }.accessibilityIdentifier("onboarding.welcome")
    }
    private func welcomeRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Folio.accentText).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.footnote).foregroundStyle(Folio.secondary) }
        }
    }
    private var title: String {
        switch draft.step {
        case .welcome: "Welcome"
        case .skills: "Start with what you know."
        case .learning: "Make room for something new."
        case .domains: "What catches your curiosity?"
        case .goals: "What brings you here?"
        }
    }
    private var subtitle: String {
        switch draft.step {
        case .welcome: ""
        case .skills: "Choose the languages and frameworks you already feel comfortable using."
        case .learning: "Pick technologies you’d like a real project to help you learn."
        case .domains: "Choose the kinds of software you’d enjoy exploring. You can change these later."
        case .goals: "There’s no right starting point. Choose what you’d like to do next."
        }
    }
    private var selection: [String] {
        switch draft.step {
        case .skills: draft.profile.knownTechnologies
        case .learning: draft.profile.learningTechnologies
        default: draft.profile.domains
        }
    }
    private var choices: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 12) {
            ForEach(ProfileSelection.options(available: draft.step == .domains ? domains : technologies, selected: selection), id: \.self) { value in
                let selected = ProfileSelection.contains(value, in: selection)
                Button { toggle(value) } label: {
                    HStack { Text(value).multilineTextAlignment(.leading); Spacer(minLength: 4); Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle") }
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(selected ? Folio.accentText : Folio.ink)
                        .background(selected ? Folio.accentLight : Folio.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Folio.accent : Folio.rule))
                }.accessibilityValue(selected ? "Selected" : "Not selected").accessibilityIdentifier("onboarding.choice.\(value)")
            }
        }
    }
    private func toggle(_ value: String) {
        let values = ProfileSelection.toggling(value, in: selection)
        switch draft.step {
        case .skills: draft.profile.knownTechnologies = values
        case .learning: draft.profile.learningTechnologies = values
        default: draft.profile.domains = values
        }
    }
    private var goals: some View {
        VStack(spacing: 12) {
            ForEach(ContributionGoal.allCases, id: \.self) { value in
                Button { draft.profile.goal = value } label: {
                    HStack(spacing: 12) { Text(value.title).multilineTextAlignment(.leading); Spacer(minLength: 8); Image(systemName: draft.profile.goal == value ? "checkmark.circle.fill" : "circle") }
                        .font(.body).padding(18).frame(maxWidth: .infinity, minHeight: 64).foregroundStyle(draft.profile.goal == value ? Folio.accentText : Folio.ink)
                        .background(draft.profile.goal == value ? Folio.accentLight : Folio.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Folio.rule))
                }.accessibilityIdentifier("onboarding.goal.\(value.rawValue)").accessibilityValue(draft.profile.goal == value ? "Selected" : "Not selected")
            }
        }
    }
    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if draft.step == .goals { finish() }
                else { draft.step = OnboardingStep(rawValue: draft.step.rawValue + 1) ?? .goals }
            } label: { HStack { Text(draft.step == .welcome ? "Make it yours" : draft.step == .goals ? editing ? "Save profile" : "Explore projects" : "Continue"); Spacer(); Image(systemName: "arrow.right") } }
                .buttonStyle(FolioButtonStyle()).accessibilityIdentifier("onboarding.continue")
            Text("Your choices stay editable in You.").font(.caption).foregroundStyle(Folio.secondary)
        }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 12).background(Folio.paper)
    }
    private func finish(skipped: Bool = false) { preferences.completeOnboarding(draft.profile, skipped: skipped); onFinish() }
}
