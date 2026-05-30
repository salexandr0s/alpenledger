# Copilot answer grounding

AlpenLedger copilot answers must be assembled from typed claims, not free-form
model text.

The grounding boundary is `AgentAnswerComposer`:

- every answer has at least one claim,
- every claim has at least one source reference,
- every cited source reference must come from prior typed tool results or model
  responses,
- each claim is labeled as an observed fact, derived value, user override, agent
  suggestion, or missing information,
- confidence values must stay in `0...1`,
- unresolved follow-up questions are stored separately from grounded claims.

This keeps natural-language answers downstream of deterministic tools. If a
future agent cannot ground a claim in returned provenance, it must ask a question
or report missing evidence instead of constructing an answer.
