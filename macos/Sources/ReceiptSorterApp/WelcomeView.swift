import AppKit
import ReceiptSorterCore
import SwiftUI
import UniformTypeIdentifiers

/// A welcome screen shown when no receipts are loaded
struct WelcomeView: View {
  @Binding var apiKey: String
  @Binding var useLocalLLM: Bool
  @Binding var excelFilePath: String
  @Binding var organizationBasePath: String
  let isAuthorized: Bool
  let onSignIn: () -> Void

  @State private var showSettings = false
  @State private var isHovering = false

  private var isFullyConfigured: Bool {
    (!apiKey.isEmpty || useLocalLLM) && !excelFilePath.isEmpty && !organizationBasePath.isEmpty
  }

  private var configuredCount: Int {
    var count = 0
    if !apiKey.isEmpty || useLocalLLM { count += 1 }
    if !excelFilePath.isEmpty { count += 1 }
    if !organizationBasePath.isEmpty { count += 1 }
    return count
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 32) {
          Spacer(minLength: 40)

          // Header
          VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
              .font(.system(size: 56, weight: .light))
              .foregroundStyle(
                LinearGradient(
                  colors: [.blue, .purple],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )

            VStack(spacing: 8) {
              Text("Welcome to Receipt Sorter")
                .font(.largeTitle)
                .fontWeight(.semibold)

              Text("Extract, organize, and export your receipts with AI")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .padding(.horizontal)

          // Setup Status
          GroupBox {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Setup Progress")
                  .font(.headline)

                Spacer()

                Text("\(configuredCount)/3")
                  .font(.caption)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 4)
                  .background(
                    Capsule()
                      .fill(
                        isFullyConfigured ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                  )
                  .foregroundColor(isFullyConfigured ? .green : .orange)
              }

              setupItem(
                icon: useLocalLLM ? "cpu" : "key",
                title: useLocalLLM ? "Local AI" : "Gemini API",
                isConfigured: useLocalLLM || !apiKey.isEmpty
              )

              setupItem(
                icon: "doc.badge.arrow.up",
                title: "Excel File",
                isConfigured: !excelFilePath.isEmpty
              )

              setupItem(
                icon: "folder.badge.gearshape",
                title: "Organization Folder",
                isConfigured: !organizationBasePath.isEmpty
              )

              Button {
                showSettings = true
              } label: {
                Label("Configure", systemImage: "gearshape")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .padding(.top, 8)
            }
          }
          .padding(.horizontal, 24)

          Spacer(minLength: 20)
        }
      }

      // Drop Zone
      VStack(spacing: 12) {
        Divider()

        ZStack {
          RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
              style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .foregroundColor(isHovering ? .blue : .secondary.opacity(0.3))
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(isHovering ? Color.blue.opacity(0.1) : Color.clear)
            )

          VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
              .font(.system(size: 32))
              .foregroundColor(isHovering ? .blue : .secondary)

            Text("Drop receipts here to get started")
              .font(.body)
              .foregroundColor(isHovering ? .blue : .secondary)

            if !isFullyConfigured {
              Text("Configure settings above for best experience")
                .font(.caption)
                .foregroundColor(.orange)
            }
          }
        }
        .frame(height: 120)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
          isHovering = hovering
        }
      }
      .padding(.bottom, 24)

      // Cloud Sync
      if !isAuthorized {
        VStack(spacing: 0) {
          Divider()

          Button(action: onSignIn) {
            HStack {
              Image(systemName: "cloud")
              Text("Sign in for Cloud Sync")
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.vertical, 12)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $showSettings) {
      Text("Settings opened in ModernSettingsView")
        .padding()
        .frame(width: 400, height: 300)
    }
  }

  private func setupItem(icon: String, title: String, isConfigured: Bool) -> some View {
    HStack(spacing: 12) {
      Image(systemName: isConfigured ? "checkmark.circle.fill" : icon)
        .foregroundColor(isConfigured ? .green : .orange)
        .frame(width: 24)

      Text(title)
        .font(.body)

      Spacer()

      if isConfigured {
        Image(systemName: "checkmark")
          .foregroundColor(.green)
          .font(.caption)
      }
    }
  }
}
