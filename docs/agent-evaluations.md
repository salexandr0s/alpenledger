# Agent Evaluations

AlpenLedger keeps a small checked-in agent evaluation suite for the deterministic
agent boundaries that must not regress silently.

The current suite lives in `config/agent-evaluations.json` and focuses on
routing. Each case declares:

- the user message,
- whether workspace/entity/tax-year/canton context is present,
- the expected intent,
- the expected specialists,
- the exact registered tool plan,
- tools that must never be planned for that prompt,
- an expected clarification question when context is missing.

`AgentEvaluationHarness` evaluates the catalog through `AgentRouter` and reports
case-level failures for intent, specialist, tool-plan, forbidden-tool,
unavailable-tool, clarification, and malformed-case regressions.

The catalog intentionally includes unsafe requests. Those cases must route to
`unsupported`, return no tools, and avoid raw SQL, shell, and confirmed-write
tool plans.

Run:

```sh
scripts/verify-agent-evaluations.sh
```

The readiness gate includes this verifier so router drift is caught together
with package, fixture, schema, copilot, and app checks.
