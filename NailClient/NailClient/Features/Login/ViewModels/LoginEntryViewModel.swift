//
//  LoginEntryViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class LoginEntryViewModel: ObservableObject {
    enum ActiveAlert: Identifiable {
        case error(message: String)

        var id: String {
            switch self {
            case .error:
                return "error"
            }
        }
    }

    @Published var activeAlert: ActiveAlert?

    func presentError(_ message: String) {
        activeAlert = .error(message: message)
    }
}
