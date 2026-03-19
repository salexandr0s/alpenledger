import Foundation
import Testing
@testable import ALDomain

@Test
func transactionReferenceObjectRefIsStable() {
    let transactionId = TransactionID()
    let ref = ObjectRef(kind: .transaction, id: transactionId.rawValue)

    #expect(ref.kind == .transaction)
    #expect(ref.id == transactionId.rawValue.uuidString.lowercased())
}
