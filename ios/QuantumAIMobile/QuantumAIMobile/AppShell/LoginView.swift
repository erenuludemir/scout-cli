import SwiftUI

public struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(QAITheme.accent)

            Text("Quantum AI Workspace")
                .font(.title.bold())
                .foregroundStyle(QAITheme.textPrimary)

            VStack(spacing: 12) {
                TextField("E-posta", text: $email)
                    .textFieldStyle(.roundedBorder)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                SecureField("Şifre", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            PrimaryButton(title: isLoggingIn ? "Hazırlanıyor..." : "Devam Et") {
                isLoggingIn = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    env.settings.isAuthenticated = true
                    isLoggingIn = false
                }
            }

            Button("Hesap Oluştur") {}
                .foregroundStyle(QAITheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }
}
