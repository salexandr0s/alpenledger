import CryptoKit
import Foundation
import ALDomain

public struct WorkspaceCrypto: Sendable {
    public let databasePassphrase: String
    public let blobKey: SymmetricKey

    public init(masterKeyData: Data, encryptionSalt: Data) {
        let inputKey = SymmetricKey(data: masterKeyData)
        let databaseKeyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: encryptionSalt,
            info: Data("alpenledger.database".utf8),
            outputByteCount: 32
        )
        let blobKeyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: encryptionSalt,
            info: Data("alpenledger.blob".utf8),
            outputByteCount: 32
        )
        self.databasePassphrase = Data(databaseKeyData.withUnsafeBytes { Data($0) }).base64EncodedString()
        self.blobKey = SymmetricKey(data: blobKeyData.withUnsafeBytes { Data($0) })
    }

    public static func generateMasterKey() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    }

    public static func generateSalt() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    }

    public static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
