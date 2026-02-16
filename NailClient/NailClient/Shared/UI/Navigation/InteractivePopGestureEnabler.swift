//
//  InteractivePopGestureEnabler.swift
//  NailClient
//

import SwiftUI
import UIKit

struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopGestureViewController {
        InteractivePopGestureViewController()
    }

    func updateUIViewController(_ uiViewController: InteractivePopGestureViewController, context: Context) {
        uiViewController.enableInteractivePopGestureIfNeeded()
    }
}

final class InteractivePopGestureViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractivePopGestureIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableInteractivePopGestureIfNeeded()
    }

    func enableInteractivePopGestureIfNeeded() {
        guard let navigationController = navigationController ?? parent?.navigationController else { return }
        guard let popGesture = navigationController.interactivePopGestureRecognizer else { return }

        popGesture.isEnabled = navigationController.viewControllers.count > 1
        popGesture.delegate = nil
    }
}

extension View {
    func enableInteractivePopGesture() -> some View {
        background(
            InteractivePopGestureEnabler()
                .frame(width: 0, height: 0)
        )
    }
}
