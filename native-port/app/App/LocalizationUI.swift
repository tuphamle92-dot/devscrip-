import UIKit

enum LocalizedUI {
    static func chooseLanguage(from controller: UIViewController, changed: @escaping () -> Void) {
        let alert = UIAlertController(title: "Tiếng Việt / English", message: nil, preferredStyle: .alert)
        for (code, name) in [("vi", "Tiếng Việt"), ("en", "English")] {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                L10n.language = code
                changed()
            })
        }
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        controller.present(alert, animated: true)
    }
    static func apply(to view: UIView) {
        if let label = view as? UILabel, let text = label.text { label.text = L10n.text(text) }
        if let button = view as? UIButton {
            if var config = button.configuration {
                if let title = config.title { config.title = L10n.text(title) }
                if let subtitle = config.subtitle { config.subtitle = L10n.text(subtitle) }
                button.configuration = config
            } else if let title = button.title(for: .normal) { button.setTitle(L10n.text(title), for: .normal) }
        }
        if let field = view as? UITextField, let placeholder = field.placeholder { field.placeholder = L10n.text(placeholder) }
        for child in view.subviews { apply(to: child) }
    }
}
