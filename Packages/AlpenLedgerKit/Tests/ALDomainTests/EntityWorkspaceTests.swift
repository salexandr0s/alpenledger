import Foundation
import Testing
@testable import ALDomain

private func iso8601Encoder() -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}

private func iso8601Decoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}

private let fixedDate = Date(timeIntervalSince1970: 1710000000)

@Test
func entityWorkspaceInitDefaults() {
    let workspaceId = WorkspaceID()
    let entityId = LegalEntityID()
    let ew = EntityWorkspace(
        workspaceId: workspaceId,
        entityId: entityId,
        displayName: "Personal"
    )
    #expect(ew.workspaceId == workspaceId)
    #expect(ew.entityId == entityId)
    #expect(ew.displayName == "Personal")
    #expect(ew.isDefault == false)
}

@Test
func entityWorkspaceCodableRoundTrip() throws {
    let ew = EntityWorkspace(
        workspaceId: WorkspaceID(),
        entityId: LegalEntityID(),
        displayName: "Business",
        isDefault: true,
        lastAccessedAt: fixedDate,
        createdAt: fixedDate
    )
    let data = try iso8601Encoder().encode(ew)
    let decoded = try iso8601Decoder().decode(EntityWorkspace.self, from: data)
    #expect(decoded == ew)
}

@Test
func taxProfileInitAndCodable() throws {
    let profile = TaxProfile(
        entityId: LegalEntityID(),
        taxationType: .selfEmployed,
        canton: .zh,
        municipality: "Zurich",
        maritalStatus: .married,
        numberOfDependents: 2,
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
    #expect(profile.taxationType == .selfEmployed)
    #expect(profile.canton == .zh)
    #expect(profile.numberOfDependents == 2)

    let data = try iso8601Encoder().encode(profile)
    let decoded = try iso8601Decoder().decode(TaxProfile.self, from: data)
    #expect(decoded == profile)
}

@Test
func transactionCategoryInitAndCodable() throws {
    let parentId = TransactionCategoryID()
    let category = TransactionCategory(
        entityId: LegalEntityID(),
        code: "expense.travel",
        displayName: "Travel Expenses",
        parentId: parentId,
        taxRole: "deduction",
        isSystemDefined: true,
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
    #expect(category.code == "expense.travel")
    #expect(category.parentId == parentId)
    #expect(category.isSystemDefined == true)

    let data = try iso8601Encoder().encode(category)
    let decoded = try iso8601Decoder().decode(TransactionCategory.self, from: data)
    #expect(decoded == category)
}

@Test
func invoiceRecordInitAndCodable() throws {
    let invoice = InvoiceRecord(
        documentId: DocumentID(),
        entityId: LegalEntityID(),
        invoiceNumber: "INV-001",
        counterpartyName: "Acme GmbH",
        totalAmountMinor: 150000,
        currency: .chf,
        direction: .receivable,
        status: .sent,
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
    #expect(invoice.invoiceNumber == "INV-001")
    #expect(invoice.totalAmountMinor == 150000)
    #expect(invoice.direction == .receivable)
    #expect(invoice.status == .sent)

    let data = try iso8601Encoder().encode(invoice)
    let decoded = try iso8601Decoder().decode(InvoiceRecord.self, from: data)
    #expect(decoded == invoice)
}

@Test
func filingPackageInitAndCodable() throws {
    let pkg = FilingPackage(
        entityId: LegalEntityID(),
        taxYearId: TaxYearID(),
        status: .generated,
        generatedAt: fixedDate,
        exportFormat: "eCH-0217",
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
    #expect(pkg.status == .generated)
    #expect(pkg.exportFormat == "eCH-0217")
    #expect(pkg.finalizedAt == nil)
    #expect(pkg.finalizedBy == nil)
    #expect(pkg.submittedAt == nil)

    let data = try iso8601Encoder().encode(pkg)
    let decoded = try iso8601Decoder().decode(FilingPackage.self, from: data)
    #expect(decoded == pkg)
}

@Test
func documentEntityIdField() {
    let entityId = LegalEntityID()
    let doc = Document(
        workspaceId: WorkspaceID(),
        blobHash: "abc123",
        originalFilename: "receipt.pdf",
        mediaType: "application/pdf",
        detectedEntityId: entityId,
        entityId: entityId
    )
    #expect(doc.entityId == entityId)
    #expect(doc.detectedEntityId == entityId)
}

@Test
func invoiceDirectionCases() {
    #expect(InvoiceDirection.allCases.count == 2)
    #expect(InvoiceDirection.allCases.contains(.receivable))
    #expect(InvoiceDirection.allCases.contains(.payable))
}

@Test
func filingPackageStatusCases() {
    #expect(FilingPackageStatus.allCases.count == 5)
}

@Test
func taxationTypeCases() {
    #expect(TaxationType.allCases.count == 3)
    #expect(TaxationType.personal.rawValue == "personal")
    #expect(TaxationType.selfEmployed.rawValue == "selfEmployed")
    #expect(TaxationType.corporate.rawValue == "corporate")
}
