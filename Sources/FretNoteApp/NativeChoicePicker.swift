import SwiftUI

struct NativeChoicePicker<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    var accessibilityTitle: String = ""
    @Environment(\.interfaceScale) private var scale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var enabled

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.autoenablesItems = false
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.target = context.coordinator
        button.action = #selector(Coordinator.select(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let titles = options.map(label)
        // Audio level updates redraw the parent frequently. Do not rebuild a tracking menu.
        if button.itemTitles != titles {
            button.removeAllItems()
            for (index, title) in titles.enumerated() {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.tag = index
                button.menu?.addItem(item)
            }
        }
        if let selectedIndex = options.firstIndex(of: selection) {
            button.selectItem(at: selectedIndex)
        } else {
            button.select(nil)
            button.title = "无可用选项"
        }
        let font = NSFont.systemFont(ofSize: 12 * scale)
        button.font = font
        button.menu?.font = font
        button.menu?.minimumWidth = 112
        button.setAccessibilityLabel(accessibilityTitle)
        button.isEnabled = enabled && !options.isEmpty
        button.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        button.sizeToFit()
        button.invalidateIntrinsicContentSize()
    }

    final class Coordinator: NSObject {
        var parent: NativeChoicePicker
        init(parent: NativeChoicePicker) { self.parent = parent }
        @objc func select(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.enabled, parent.options.indices.contains(index) else { return }
            parent.selection = parent.options[index]
        }
    }
}
