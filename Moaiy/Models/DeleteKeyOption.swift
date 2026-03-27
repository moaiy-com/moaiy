//
//  DeleteKeyOption.swift
//  Moaiy
//
//  Shared key deletion strategy options.
//

import Foundation

enum DeleteKeyOption: String, Identifiable {
    case secretOnly
    case publicOnly
    case both

    var id: String { rawValue }
}
