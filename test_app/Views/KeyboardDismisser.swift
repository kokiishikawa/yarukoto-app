//
//  KeyboardDismisser.swift
//  test_app
//

import SwiftUI
import UIKit

/// 文字の入力欄以外をタップしたら、キーボードを閉じる。
/// メモ欄は改行キーで閉じられないため。ウインドウ全体にタップの認識を1つだけ付ける
/// （シートも同じウインドウに出るので、編集画面にも効く）。
struct KeyboardDismisser: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    /// ウインドウに入った時点で、タップの認識をウインドウに付ける。
    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window,
                  !(window.gestureRecognizers ?? []).contains(where: { $0.name == Handler.name })
            else { return }
            let tap = UITapGestureRecognizer(target: Handler.shared, action: #selector(Handler.tapped(_:)))
            tap.name = Handler.name
            tap.cancelsTouchesInView = false // ボタンなどのタップはそのまま通す
            tap.delegate = Handler.shared
            window.addGestureRecognizer(tap)
        }
    }

    final class Handler: NSObject, UIGestureRecognizerDelegate {
        static let shared = Handler()
        static let name = "KeyboardDismisser"

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            recognizer.view?.endEditing(true)
        }

        /// 入力欄そのもののタップでは閉じない（カーソル移動などを邪魔しない）。
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if v is UITextField || v is UITextView { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
