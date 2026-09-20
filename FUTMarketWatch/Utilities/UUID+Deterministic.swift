import Foundation
import CryptoKit

extension UUID {
    /// Dérive un UUID stable et reproductible à partir d'une chaîne (ex. un ID FUTBIN).
    /// MD5 sert uniquement à obtenir 16 octets déterministes pour construire l'UUID — aucun
    /// usage cryptographique/sécurité ici, juste un identifiant stable réutilisable d'un appel
    /// à l'autre sans avoir à faire correspondre des UUID aléatoires entre deux exécutions.
    init(deterministicFrom seed: String) {
        let digest = Insecure.MD5.hash(data: Data(seed.utf8))
        self = digest.withUnsafeBytes { rawBuffer in
            let bytes = Array(rawBuffer.bindMemory(to: UInt8.self))
            return NSUUID(uuidBytes: bytes) as UUID
        }
    }
}
