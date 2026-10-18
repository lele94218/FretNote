import SwiftUI

@main
struct FretNoteApp: App, Localizable {
    var language: AppLanguage { appearance.language }
    @StateObject private var audio = AudioInput()
    @StateObject private var practice = PracticeStore()
    @StateObject private var appearance = AppearancePreferences()
    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio, practice: practice)
                .environmentObject(appearance)
                .environment(\.appLanguage, appearance.language)
                .environment(\.locale, appearance.language.locale)
                .environment(\.interfaceScale, appearance.fontScale)
                .preferredColorScheme(appearance.theme.colorScheme)
                .frame(minWidth: 1040, minHeight: 740)
                .onChange(of: audio.running) { running in
                    if !running && practice.active { practice.end() }
                }
        }
        .defaultSize(width: 1160, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button(appearance.sidebarVisible ? L("隐藏侧栏") : L("显示侧栏")) { appearance.sidebarVisible.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
            }
            CommandMenu(L("练习")) {
                Button(practice.active ? L("结束练习") : L("开始练习")) {
                    if practice.active { practice.end() } else { practice.start() }
                }.keyboardShortcut(.return, modifiers: .command)
                    .disabled(practice.learning || practice.showSummary || (!practice.active && !audio.running))
                Button(L("提示位置")) { practice.reveal() }.keyboardShortcut("h", modifiers: [.command, .shift])
                    .disabled(!practice.active || practice.completed)
                Button(L("跳过")) { practice.skip() }.keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(!practice.active || practice.completed)
                Divider()
                Button(audio.running ? L("停止监听") : L("开启输入")) {
                    if audio.running { audio.stop() } else { Task { await audio.start() } }
                }.keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(practice.learning || audio.starting || audio.devices.isEmpty)
            }
        }
        Settings {
            AppSettingsView(audio: audio)
                .environmentObject(appearance)
                .environment(\.appLanguage, appearance.language)
                .environment(\.locale, appearance.language.locale)
                .environment(\.interfaceScale, appearance.fontScale)
                .preferredColorScheme(appearance.theme.colorScheme)
        }
    }
}
