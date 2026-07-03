//
//  ContentView.swift
//  xSpark
//
//  Main window — modelled on macOS System Settings: hero header, an
//  Accessibility-permission gate, grouped inset setting lists with
//  tinted icon chips, and a how-it-works card. Adapts to light/dark via
//  semantic system colors and is fully localizable (see Localizable.xcstrings).
//

import SwiftUI
import AppKit
import LucideIcons

struct ContentView: View {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    private let accent = Color(red: 0.1, green: 0.7, blue: 0.3)

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                if !prefs.accessibilityGranted {
                    accessibilityCard
                }
                group(eyebrow: "Cut & Paste") {
                    toggleRow(
                        title: "Enable Cut & Paste",
                        subtitle: "Use ⌘X / ⌘V in Finder to move files.",
                        icon: Lucide.scissors,
                        isOn: $prefs.cutAndPasteEnabled
                    )
                    divider
                    toggleRow(
                        title: "Play sound on cut",
                        subtitle: "Play a system sound when ⌘X marks files.",
                        icon: Lucide.volume2,
                        isOn: $prefs.playSound
                    )
                    if prefs.playSound {
                        divider
                        soundPickerRow
                    }
                }
                group(eyebrow: "Appearance & Behavior") {
                    toggleRow(
                        title: "Launch at login",
                        subtitle: "Start xSpark automatically when you log in.",
                        icon: Lucide.power,
                        isOn: $prefs.launchAtLogin
                    )
                    divider
                    toggleRow(
                        title: "Hide Dock icon",
                        subtitle: "Run quietly from the menu bar only.",
                        icon: Lucide.eyeOff,
                        isOn: $prefs.hideDockIcon
                    )
                }
                howItWorksCard
                footer
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 480, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { prefs.refreshAccessibility() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 10, y: 4)

            Text("xSpark")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Cut & paste files in Finder — the Windows way.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                keyCap("⌘X"); Text("cut").foregroundStyle(.secondary)
                Image(nsImage: Lucide.arrowRight)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(.tertiary)
                keyCap("⌘V"); Text("move here").foregroundStyle(.secondary)
            }
            .font(.system(size: 11.5, weight: .medium))
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private func keyCap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }

    // MARK: - Accessibility gate

    private var accessibilityCard: some View {
        card {
            HStack(alignment: .top, spacing: 12) {
                iconChip(icon: Lucide.triangleAlert)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Accessibility access required")
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("xSpark needs Accessibility permission to send ⌘X / ⌘V keystrokes to Finder.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Open System Settings") { prefs.openAccessibilitySettings() }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                        Button("Re-check") { prefs.refreshAccessibility() }
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Grouped settings

    private var soundPickerRow: some View {
        HStack(spacing: 12) {
            iconChip(icon: Lucide.music)
            Text("Sound")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Picker("", selection: $prefs.cutSoundName) {
                ForEach(XSConstants.systemSounds, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Button {
                prefs.previewSound()
            } label: {
                Image(nsImage: Lucide.circlePlay)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.borderless)
            .help(Text("Preview", comment: "Button to preview the selected cut sound"))
        }
        .padding(.vertical, 8)
    }

    private func toggleRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: NSImage,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            iconChip(icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 9)
    }

    /// Minimal, monochrome icon tile: a soft gray/white square that tracks the
    /// window's own light/dark appearance instead of a per-row accent color.
    private func iconChip(icon: NSImage) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06))
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .overlay(
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - How it works

    private var howItWorksCard: some View {
        group(eyebrow: nil) {
            Text("How it works")
                .font(.system(size: 13.5, weight: .semibold))
                .padding(.bottom, 2)
            step(number: 1, text: "Select files in Finder and press ⌘X. A floating tag confirms what was cut.")
            step(number: 2, text: "Go to the destination folder and press ⌘V.")
            step(number: 3, text: "The files are moved (not copied) to the new location.")
        }
    }

    private func step(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06))
                        .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                )
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("xSpark \(appVersion)")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }

    // MARK: - Building blocks

    private var divider: some View {
        Divider().padding(.leading, 38)
    }

    /// A card with an optional small-caps eyebrow label above it, matching
    /// macOS System Settings' grouped-list presentation.
    private func group<Content: View>(
        eyebrow: LocalizedStringKey?,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            card { VStack(spacing: 0, content: content) }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 6, y: 2)
    }
}

#Preview {
    ContentView().environmentObject(Preferences.shared)
}
