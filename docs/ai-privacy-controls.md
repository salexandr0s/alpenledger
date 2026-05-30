# AI privacy controls

AlpenLedger defaults to local-only AI. In that mode, model providers cannot use
network access or send workspace data off-device.

Hybrid and external-assistant modes are modeled as explicit opt-in runtime modes.
They do not make a provider usable by themselves. A provider that requires
network access or sends data off-device must also pass all of these checks before
execution:

- the active privacy mode allows network access,
- the user consent settings allow network access,
- the active privacy mode allows off-device data,
- the user consent settings allow off-device data,
- the provider ID is explicitly approved when the provider requires approval,
- the requested input scope fits the configured redaction policy.

The redaction policy is enforced at provider execution time. `metadataOnly`
permits only metadata-scoped requests to off-device providers. `redactedSnippets`
also permits redacted snippets, but still blocks full local workspace data from
leaving the device.

Settings surfaces the current AI/privacy mode, network and cloud status,
consent state, redaction policy, approved providers, and each provider's
available/blocked state. Local-only mode ignores environment-provided consent so
misconfiguration cannot silently enable off-device providers.

Model-provider execution records activity before a provider starts, after it
completes, and when policy or execution failures stop it. The activity snapshot
includes the provider, capability, input scope, privacy mode, network/off-device
flags, sent-off-device result, and block or error reason. Settings renders the
latest activity so users can see whether a provider is idle, running, completed,
blocked, or failed.
