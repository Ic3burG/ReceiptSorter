import ReceiptSorterCore
import SwiftUI
import UserNotifications

struct OnboardingView: View {
  @Binding var isPresented: Bool

  // Onboarding State
  @State private var currentStep = 0
  @AppStorage("geminiApiKey") private var apiKey: String = ""
  @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

  var body: some View {
    ZStack {
      // Background Layer
      Color(NSColor.windowBackgroundColor)
        .ignoresSafeArea()

      // Abstract Glass Shapes for Visual Interest
      GeometryReader { proxy in
        Circle()
          .fill(
            LinearGradient(
              colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 400, height: 400)
          .blur(radius: 60)
          .offset(x: -100, y: -100)

        Circle()
          .fill(
            LinearGradient(
              colors: [.green.opacity(0.3), .cyan.opacity(0.3)],
              startPoint: .bottomTrailing,
              endPoint: .topLeading
            )
          )
          .frame(width: 300, height: 300)
          .blur(radius: 50)
          .position(x: proxy.size.width + 50, y: proxy.size.height + 50)
      }
      .ignoresSafeArea()

      // Content Card
      VStack {
        // Steps Indicator
        HStack(spacing: 8) {
          ForEach(0..<4) { index in
            Capsule()
              .fill(index == currentStep ? Color.primary : Color.secondary.opacity(0.3))
              .frame(width: index == currentStep ? 24 : 8, height: 8)
              .animation(.spring(), value: currentStep)
          }
        }
        .padding(.top, 40)

        // Content Switcher implies Paging
        ZStack {
          if currentStep == 0 {
            WelcomeStep().transition(.opacity)
          } else if currentStep == 1 {
            PermissionsStep().transition(.opacity)
          } else if currentStep == 2 {
            ConfigurationStep(apiKey: $apiKey, useLocalLLM: $useLocalLLM).transition(.opacity)
          } else if currentStep == 3 {
            ReadyStep(onExplore: completeOnboarding).transition(.opacity)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut, value: currentStep)

        // Navigation Buttons (if not on last step)
        if currentStep < 3 {
          HStack {
            if currentStep > 0 {
              Button("Back") {
                withAnimation { currentStep -= 1 }
              }
              .buttonStyle(.bordered)
            }

            Spacer()

            Button("Next") {
              withAnimation { currentStep += 1 }
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(40)
        }
      }
      .background(.ultraThinMaterial)
      .cornerRadius(24)
      .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
      .frame(width: 600, height: 500)
    }
  }

  private func completeOnboarding() {
    hasCompletedOnboarding = true
    isPresented = false
  }
}

// MARK: - Steps

struct WelcomeStep: View {
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "sparkles.rectangle.stack.fill")
        .font(.system(size: 80))
        .foregroundStyle(
          LinearGradient(
            colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        )

      VStack(spacing: 8) {
        Text("Welcome to Receipt Sorter")
          .font(.largeTitle)

        Text("Your intelligent assistant for organizing and extracting data from receipts.")
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundColor(.secondary)
          .padding(.horizontal, 40)
      }
    }
  }
}

struct PermissionsStep: View {
  @State private var filesGranted = false
  @State private var notificationsGranted = false

  var body: some View {
    VStack(spacing: 32) {
      Text("Permissions")
        .font(.title)

      VStack(spacing: 16) {
        // Notifications
        GroupBox {
          HStack {
            Image(systemName: "bell.badge.fill")
              .font(.title2)
              .foregroundColor(.red)
              .frame(width: 40)

            VStack(alignment: .leading) {
              Text("Notifications")
                .font(.headline)
              Text("Get notified when processing completes.")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if notificationsGranted {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            } else {
              Button("Enable") {
                requestNotifications()
              }
              .buttonStyle(.bordered)
            }
          }
        }

        // File Access Explanation
        GroupBox {
          HStack {
            Image(systemName: "folder.fill")
              .font(.title2)
              .foregroundColor(.blue)
              .frame(width: 40)

            VStack(alignment: .leading) {
              Text("File Access")
                .font(.headline)
              Text("We ask for secure folder access.")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "info.circle")
              .foregroundColor(.secondary)
              .help("Access is granted when you select files.")
          }
        }
      }
      .padding(.horizontal, 40)
    }
  }

  func requestNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
      granted, _ in
      DispatchQueue.main.async {
        self.notificationsGranted = granted
      }
    }
  }
}

struct ConfigurationStep: View {
  @Binding var apiKey: String
  @Binding var useLocalLLM: Bool

  var body: some View {
    VStack(spacing: 32) {
      Text("Configuration")
        .font(.title)

      VStack(spacing: 24) {
        GroupBox {
          Toggle("Use Local Intelligence", isOn: $useLocalLLM)
            .toggleStyle(.switch)
            .font(.headline)
        }

        if !useLocalLLM {
          VStack(alignment: .leading, spacing: 8) {
            Text("Gemini API Key")
              .font(.headline)

            HStack {
              Image(systemName: "key.fill")
                .foregroundColor(.secondary)
              SecureField("Enter API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .privacySensitive()
            }

            Link("Get API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
              .font(.caption)
          }
          .transition(.opacity)
        } else {
          Text("Local models run directly on your Mac. No data leaves your device.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
      }
      .padding(.horizontal, 40)
    }
  }
}

struct ReadyStep: View {
  var onExplore: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Image(systemName: "rocket.fill")
        .font(.system(size: 80))
        .foregroundStyle(
          LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top)
        )
        .shadow(color: .orange.opacity(0.5), radius: 20, x: 0, y: 10)

      VStack(spacing: 8) {
        Text("You're All Set!")
          .font(.largeTitle)

        Text("Your receipt sorter is ready to categorize and extract data efficiently.")
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundColor(.secondary)
      }
      .padding(.bottom, 20)

      Button {
        onExplore()
      } label: {
        Label("Get Started", systemImage: "arrow.right")
      }
      .buttonStyle(.borderedProminent)
      .frame(width: 200)
    }
  }
}
