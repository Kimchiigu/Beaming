//
//  Role.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

enum Role: String, CaseIterable, Codable, Hashable {
    case deaf
    case hearing
    case nonBinary

    var title: String {
        switch self {
        case .deaf:
            return "Deaf"
        case .hearing:
            return "Hearing"
        case .nonBinary:
            return "non-binary"
        }
    }
}

