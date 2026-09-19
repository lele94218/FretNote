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
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
