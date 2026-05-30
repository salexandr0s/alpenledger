# Rule-Pack Validation

AlpenLedger rule packs are deterministic code and fixture contracts. A rule
pack is release-eligible only when it is listed in `config/rule-pack-catalog.json`
and passes the focused validation gate.

The catalog records:
- jurisdiction and ruleset version,
- adapter type,
- supported entity kinds,
- expected canonical concept codes,
- fixture pack and golden expected-facts file,
- tests that prove the pack is covered.

Validation checks must prove that:
- registered adapters match the catalog metadata,
- expected concept codes are stable and syntactically valid,
- computed facts are declared by the rule pack,
- computed fact value fields match their value type,
- computed facts have source provenance,
- rule packs never emit user overrides,
- golden fixture outputs match the expected fact set.

Rule-pack validation is local-only. It does not call model providers and must not
send tax fixture contents off-device.
