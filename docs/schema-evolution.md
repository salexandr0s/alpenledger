# Schema Evolution

AlpenLedger workspaces are user-owned local databases. Schema changes must be
append-only, auditable, and recoverable enough that a migration failure never
silently corrupts financial truth.

## Migration Rules

- Register every database change in `Migrations.swift` with a stable identifier
  in `AlpenLedgerDatabaseMigrations`.
- Never rename or reorder an existing migration identifier after it has shipped.
- Prefer additive migrations: new tables, nullable columns, indexes, and
  backfilled derived state.
- Destructive changes require a replacement migration that preserves the
  original data until a verified export/backup path exists.
- Data backfills must be deterministic and must not invent accounting or tax
  values. If a value cannot be derived from existing persisted data, leave it
  nullable or create an explicit review issue in application code.
- Foreign-key behavior, unique constraints, and FTS/index changes must be
  covered by migration or repository tests before release.

## Required Evidence

Every schema change must update or preserve these checks:

- Empty-database migration smoke coverage.
- Full migration idempotency coverage.
- Legacy-data migration coverage when a migration backfills or transforms data.
- Database health reporting for required tables and migration-ledger state.
- Backup/restore tests when persisted workspace data shape changes.

## Adding a Migration

1. Add the migration identifier to `AlpenLedgerDatabaseMigrations`.
2. Register the migration in `makeAlpenLedgerDatabaseMigrator()`.
3. Add required table names to `requiredTables` when introducing a table.
4. Add or update repository tests for the new persisted model.
5. Add a migration test for new indexes, columns, FTS tables, or data backfills.
6. Run `scripts/verify-readiness.sh` before marking checklist evidence complete.

## Recovery Strategy

Before any migration that changes existing user data, AlpenLedger should take or
prompt for a local backup. Current tests prove backup/restore and health-report
behavior; release readiness still requires customer-scale recovery drills for
large workspaces and corrupted files.
