# Agent Routing

AlpenLedger uses a deterministic router before any specialist agent or model
provider is selected. The router is intentionally narrow: it classifies the
user request, selects specialist responsibilities, and produces a typed tool
plan from `AgentToolRegistry.productionDefaults`.

The router does not execute tools and has no write permission. It only returns:

- the classified intent,
- selected specialists,
- registered tool names,
- required tool scopes,
- active workspace/entity/tax-year references,
- unavailable requested tools, if any,
- a single clarification question when required context is missing.

The router must not invent context IDs. If a request needs an entity or tax year
and the current context does not provide one, the plan carries a clarification
question instead of pretending the missing scope is known.

Supported v1 routes cover the core product workflows:

- missing tax evidence and filing readiness,
- business expenses without invoices or receipts,
- VAT explanation,
- business/corporate tax export preparation,
- reconciliation review,
- transaction classification,
- document intake,
- provenance and audit explanation,
- general read-only finance questions.

Unsafe requests such as unrestricted file access, unrestricted SQL, shell
execution, or destructive database operations route to `unsupported` and
produce no tool plan.

Tests in `AgentRouterTests` prove that common routes only return registered
tools, carry active context refs, ask for missing context, and avoid finalizing
filing packages or using confirmed-write tools during planning.

`scripts/verify-agent-tool-safety.sh` is the focused gate for the executable
tool boundary. It rejects production tool declarations that allow unrestricted
file access, raw SQL, or shell execution; rejects direct filesystem, shell, or
native file-picker access in agent-facing sources; and runs the
`AgentToolPolicy` tests that verify scope, provenance, and explicit approval
requirements.

Copilot actions that create review work also use the tool boundary. The
app-model task action routes through `issues.open_or_update` with
`.issuesWrite` scope so low-risk issue writes receive the same provenance and
agent-tool audit event as model-planned tool calls.
