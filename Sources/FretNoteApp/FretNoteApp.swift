import SwiftUI

@main
struct FretNoteApp: App {
    @StateObject private var audio = AudioInput()
    @StateObject private var practice = PracticeStore()
    @StateObject private var appearance = AppearancePreferences()
    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio, practice: practice)
                .environmentObject(appearance)
                .environment(\.interfaceScale, appearance.fontScale)
                .preferredColorScheme(appearance.theme.colorScheme)
                .frame(minWidth: 1040, minHeight: 740)
                .onAppear { audio.onNote = { [weak practice] midi in practice?.receive(midi) } }
                .onChange(of: audio.running) { running in
                    if !running && practice.active { practice.end() }
                }
        }
        .defaultSize(width: 1160, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button(appearance.sidebarVisible ? "隐藏侧栏" : "显示侧栏") { appearance.sidebarVisible.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
            }
            CommandMenu("练习") {
                Button(practice.active ? "结束练习" : "开始练习") {
                    if practice.active { practice.end() } else { practice.start() }
                }.keyboardShortcut(.return, modifiers: .command)
                    .disabled(practice.learning || practice.showSummary || (!practice.active && !audio.running))
                Button("提示位置") { practice.reveal() }.keyboardShortcut("h", modifiers: [.command, .shift])
                    .disabled(!practice.active || practice.completed)
                Button("跳过") { practice.skip() }.keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(!practice.active || practice.completed)
                Divider()
                Button(audio.running ? "停止监听" : "开启输入") {
                    if audio.running { audio.stop() } else { Task { await audio.start() } }
                }.keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(practice.learning || audio.starting || audio.devices.isEmpty)
            }
        }
        Settings {
            AppSettingsView(audio: audio)
                .environmentObject(appearance)
                .environment(\.interfaceScale, appearance.fontScale)
                .preferredColorScheme(appearance.theme.colorScheme)
        }
    }
}
