import Foundation
import GRDB
import ALDomain

extension EntityID: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        description.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let rawValue = String.fromDatabaseValue(dbValue), let uuid = UUID(uuidString: rawValue) else {
            return nil
        }
        return Self(rawValue: uuid)
    }
}

extension ObjectRef: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        stringValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ObjectRef? {
        guard let value = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return ObjectRef.parse(value)
    }
}

extension CurrencyCode: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CurrencyCode? {
        guard let raw = String.fromDatabaseValue(dbValue) else { return nil }
        return CurrencyCode(rawValue: raw)
    }
}

extension CantonCode: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CantonCode? {
        guard let raw = String.fromDatabaseValue(dbValue) else { return nil }
        return CantonCode(rawValue: raw)
    }
}

extension Workspace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "workspaces"
}
extension LegalEntity: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "legalEntities"
}
extension TaxYear: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxYears"
}
extension LedgerAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ledgerAccounts"
}
extension FinancialAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "financialAccounts"
}
extension ImportJob: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "importJobs"
}
extension StatementImport: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "statementImports"
}
extension Transaction: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "transactions"
}
extension Document: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "documents"
}
extension EvidenceLink: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "evidenceLinks"
}
extension Requirement: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "requirements"
}
extension Issue: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "issues"
}
extension AgentProposal: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentProposals"
}
extension AuditEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "auditEvents"
}

extension TaxFact: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxFacts"

    public init(row: Row) {
        self.init(
            id: row["id"],
            fingerprint: row["fingerprint"],
            entityId: row["entityId"],
            taxYearId: row["taxYearId"],
            jurisdictionCode: row["jurisdictionCode"],
            conceptCode: row["conceptCode"],
            valueType: TaxFactValueType(rawValue: row["valueType"]) ?? .text,
            moneyMinor: row["moneyMinor"],
            textValue: row["textValue"],
            boolValue: row["boolValue"],
            dateValue: row["dateValue"],
            currency: {
                guard let raw: String = row["currency"] else { return nil }
                return CurrencyCode(rawValue: raw)
            }(),
            status: TaxFactStatus(rawValue: row["status"]) ?? .derived,
            rulesetVersion: row["rulesetVersion"],
            provenanceRefs: TaxFact.decodeProvenanceRefs(from: row["provenanceRefs"]),
            confidence: row["confidence"],
            supersedesFactId: row["supersedesFactId"],
            isCurrent: row["isCurrent"],
            overrideReason: row["overrideReason"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["fingerprint"] = fingerprint
        container["entityId"] = entityId
        container["taxYearId"] = taxYearId
        container["jurisdictionCode"] = jurisdictionCode
        container["conceptCode"] = conceptCode
        container["valueType"] = valueType.rawValue
        container["moneyMinor"] = moneyMinor
        container["textValue"] = textValue
        container["boolValue"] = boolValue
        container["dateValue"] = dateValue
        container["currency"] = currency?.rawValue
        container["status"] = status.rawValue
        container["rulesetVersion"] = rulesetVersion
        container["provenanceRefs"] = TaxFact.encodeProvenanceRefs(provenanceRefs)
        container["confidence"] = confidence
        container["supersedesFactId"] = supersedesFactId
        container["isCurrent"] = isCurrent
        container["overrideReason"] = overrideReason
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    private static func encodeProvenanceRefs(_ refs: [ObjectRef]) -> String {
        guard let data = try? JSONEncoder.alpenLedger.encode(refs),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func decodeProvenanceRefs(from rawValue: String?) -> [ObjectRef] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let refs = try? JSONDecoder.alpenLedger.decode([ObjectRef].self, from: data)
        else {
            return []
        }
        return refs
    }
}
