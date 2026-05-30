# Copilot state storage

Copilot state is local workspace data. It is stored in the encrypted workspace
database and separated from authoritative finance/tax records.

The persistence model uses four records:

- `AgentConversation` stores a local chat session, active entity/year context,
  and lifecycle status.
- `AgentMessage` stores conversation history. Messages may cite domain objects
  through `sourceRefs`, but message text is not an authoritative ledger, tax, or
  document fact.
- `AgentRunTrace` stores the orchestration audit trail for a user turn:
  router intent, selected specialists, planned tools and scopes, context refs,
  model/provider and prompt template metadata, off-device status, tool-call
  outcomes, and approval decisions.
- `AgentPendingApproval` stores reviewable confirmed-write requests with the
  tool name, reviewed input hash, required scopes, target refs, reviewer
  decision metadata, and a conversion path to `AgentToolConfirmation` only after
  approval.

Unresolved follow-up questions are stored on messages as separate data. Future
UI and agent flows should render those as questions or blockers, not as grounded
claims.
