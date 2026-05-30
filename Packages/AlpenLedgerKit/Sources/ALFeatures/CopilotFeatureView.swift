import SwiftUI
import ALDesignSystem
import ALDomain

public struct CopilotFeatureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let snapshot: CopilotSnapshot
    private let performAction: (CopilotAction) -> Void

    public init(
        snapshot: CopilotSnapshot,
        performAction: @escaping (CopilotAction) -> Void
    ) {
        self.snapshot = snapshot
        self.performAction = performAction
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                contextRow
                promptsPane
                answersStack
            }
            .padding(AppTheme.contentPadding)
            .transition(AppTheme.chromeTransition(reduceMotion: reduceMotion))
        }
        .navigationTitle(snapshot.title)
        .navigationSubtitle(snapshot.subtitle)
    }

    private var contextRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: AppTheme.spacingM)],
            spacing: AppTheme.spacingM
        ) {
            ForEach(snapshot.contextItems) { item in
                SummaryTile(
                    item.title,
                    value: item.value,
                    subtitle: "",
                    tone: item.tone,
                    style: .compact,
                    subtitlePresentation: .secondary,
                    systemImage: item.systemImage
                )
            }
        }
    }

    private var promptsPane: some View {
        InspectorPane("Suggested Questions", subtitle: snapshot.subtitle) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: AppTheme.spacingM)],
                spacing: AppTheme.spacingM
            ) {
                ForEach(snapshot.prompts) { prompt in
                    Button {
                        performAction(prompt.action)
                    } label: {
                        HStack(alignment: .top, spacing: AppTheme.spacingS) {
                            Image(systemName: prompt.systemImage)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(prompt.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(prompt.subtitle)
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(AppTheme.subduedForegroundColor)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: AppTheme.spacingS)
                        }
                        .padding(AppTheme.spacingS)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("copilot.prompt.\(accessibilitySlug(prompt.id))")
                }
            }
        }
    }

    private var answersStack: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            ForEach(snapshot.answers) { answer in
                answerCard(answer)
                    .accessibilityIdentifier("copilot.answer.\(accessibilitySlug(answer.id))")
            }
        }
    }

    private func answerCard(_ answer: CopilotSnapshot.AnswerCard) -> some View {
        InspectorPane(answer.question, subtitle: answer.summary, style: .card) {
            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                HStack(spacing: AppTheme.spacingS) {
                    StatusBadge(answer.statusText, tone: answer.tone)
                    Spacer()
                    Image(systemName: answer.systemImage)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    ForEach(answer.claims) { claim in
                        claimRow(claim)
                    }
                }

                if answer.followUpQuestions.isEmpty == false {
                    Divider()
                    followUpRows(answer)
                }

                if answer.sources.isEmpty == false {
                    Divider()
                    sourceRows(answer.sources)
                }

                HStack(spacing: AppTheme.spacingS) {
                    Button(answer.primaryActionTitle) {
                        performAction(answer.primaryAction)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("copilot.answer.\(accessibilitySlug(answer.id)).primaryAction")

                    if let secondaryActionTitle = answer.secondaryActionTitle,
                       let secondaryAction = answer.secondaryAction {
                        Button(secondaryActionTitle) {
                            performAction(secondaryAction)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("copilot.answer.\(accessibilitySlug(answer.id)).secondaryAction")
                    }
                }
            }
        }
    }

    private func followUpRows(_ answer: CopilotSnapshot.AnswerCard) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text("Follow-up questions")
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            ForEach(answer.followUpQuestions) { followUp in
                HStack(alignment: .top, spacing: AppTheme.spacingS) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                        Text(followUp.text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(followUp.sourceRefs.count) source\(followUp.sourceRefs.count == 1 ? "" : "s")")
                            .font(AppTheme.metaFont)
                            .foregroundStyle(AppTheme.subduedForegroundColor)
                    }

                    Spacer(minLength: AppTheme.spacingS)

                    Button(followUp.primaryActionTitle) {
                        performAction(followUp.primaryAction)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "copilot.answer.\(accessibilitySlug(answer.id)).followUp.\(accessibilitySlug(followUp.id)).primaryAction"
                    )
                }
                .accessibilityIdentifier(
                    "copilot.answer.\(accessibilitySlug(answer.id)).followUp.\(accessibilitySlug(followUp.id))"
                )
            }
        }
    }

    private func claimRow(_ claim: CopilotSnapshot.ClaimItem) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Image(systemName: claim.kind.systemImage)
                .foregroundStyle(claim.kind.foregroundStyle)
                .frame(width: 20)

            Text(claim.text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sourceRows(_ sources: [CopilotSnapshot.SourceItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text("Sources")
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            ForEach(sources) { source in
                Button {
                    performAction(.openSource(source.ref))
                } label: {
                    HStack(alignment: .top, spacing: AppTheme.spacingS) {
                        Image(systemName: source.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(source.subtitle)
                                .font(AppTheme.metaFont)
                                .foregroundStyle(AppTheme.subduedForegroundColor)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("copilot.source.\(accessibilitySlug(source.id))")
            }
        }
    }
}

private extension AgentAnswerClaimKind {
    var systemImage: String {
        switch self {
        case .observedFact:
            "eye"
        case .derivedValue:
            "function"
        case .userOverride:
            "slider.horizontal.3"
        case .agentSuggestion:
            "sparkles"
        case .missingInformation:
            "questionmark.circle"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .observedFact:
            .blue
        case .derivedValue:
            .green
        case .userOverride:
            .orange
        case .agentSuggestion:
            .purple
        case .missingInformation:
            .secondary
        }
    }
}
