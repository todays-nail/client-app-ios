//
//  LoginEntryViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class LoginEntryViewModel: ObservableObject {
    enum ComingSoonKind: String {
        case webLogin = "사장님 웹 로그인"
        case terms = "이용약관"
        case privacy = "개인정보처리방침"
    }

    enum ActiveAlert: Identifiable {
        case error(message: String)
        case comingSoon(kind: ComingSoonKind)

        var id: String {
            switch self {
            case .error:
                return "error"
            case .comingSoon(let kind):
                return "comingSoon.\(kind.rawValue)"
            }
        }
    }

    @Published var activeAlert: ActiveAlert?

    func presentError(_ message: String) {
        activeAlert = .error(message: message)
    }

    func showComingSoon(_ kind: ComingSoonKind) {
        activeAlert = .comingSoon(kind: kind)
    }
}
