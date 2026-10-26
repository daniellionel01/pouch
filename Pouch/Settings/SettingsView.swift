import KeyboardShortcuts
import PouchCore
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginNeedsApproval = LaunchAtLogin.needsApproval
    @State private var loginError: String?

    var body: some View {
        let theme = Theme.named(settings.theme)
        Form {
            Section {
                SettingsHeader()
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in updateLaunchAtLogin(enabled) }
                if loginNeedsApproval {
                    LabeledContent("Allow Pouch in Login Items to finish setting this up.") {
                        Button("Open Login Items…") { LaunchAtLogin.openSystemSettings() }
                    }
                    .font(.callout)
                }
                if let loginError {
                    Text(loginError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                KeyboardShortcuts.Recorder("Show or hide the shelf", name: .toggleShelf)
            }

            Section {
                Toggle("Collect new screenshots", isOn: $settings.collectScreenshots)
                Toggle("Show the shelf when a screenshot arrives", isOn: $settings.showOnNewScreenshot)
                    .disabled(!settings.collectScreenshots)
            } header: {
                Text("Screenshots")
            } footer: {
                Text("Screenshots show up once macOS saves them. Turn off **Show Floating Thumbnail** in the Screenshot app (⌘⇧5 → Options) and they'll land instantly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dragging") {
                Toggle("Remove items after dragging them out", isOn: $settings.removeAfterDragOut)
            }

            Section("Look and sound") {
                LabeledContent("Colorway") {
                    ColorwayPicker(selection: $settings.theme)
                }
                Toggle("Sound effects", isOn: $settings.soundsEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.theme, theme)
        .tint(theme.controlTint)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // The user may have changed Login Items in System Settings.
            refreshLaunchAtLogin()
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = "Couldn't update Login Items: \(error.localizedDescription)"
        }
        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
        loginNeedsApproval = LaunchAtLogin.needsApproval
    }
}

private struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            PouchPortrait()
                .scaleEffect(0.5)
                .frame(width: 46, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pouch")
                    .font(.system(size: 20, design: .serif).weight(.semibold))
                Text("Holds your files and screenshots while you switch apps. Version \(Bundle.main.shortVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Fabric swatches: a square of the flap color with its thread stitched
/// around the edge. The chosen one is outlined.
private struct ColorwayPicker: View {
    @Binding var selection: ThemeID

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ThemeID.allCases, id: \.self) { id in
                let theme = Theme.named(id)
                let isSelected = id == selection
                Button {
                    withAnimation(.pouchHover) { selection = id }
                } label: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.flap)
                        .fabricGrain(0.1)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(theme.thread.opacity(0.85), style: .stitch(width: 1)).padding(3))
                        .frame(width: 24, height: 24)
                        .padding(2.5)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: isSelected ? 1.5 : 0))
                }
                .buttonStyle(.plain)
                .help(theme.name)
                .accessibilityLabel(theme.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Text(Theme.named(selection).name)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
