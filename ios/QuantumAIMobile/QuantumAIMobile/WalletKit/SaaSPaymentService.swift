import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

public final class SaaSPaymentService: ObservableObject {
    public let accessLabel = "Free of Charge"
    private static let context = CIContext()

    public init() {}

    fileprivate func generateQRCode(from string: String) -> PlatformImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            // QR kodu büyütmek için ölçeklendirme
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = Self.context.createCGImage(scaledImage, from: scaledImage.extent) {
                #if canImport(UIKit)
                return UIImage(cgImage: cgImage)
                #elseif canImport(AppKit)
                return NSImage(cgImage: cgImage, size: .zero)
                #else
                return nil
                #endif
            }
        }
        return nil
    }
}

public struct SaaSInvoiceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var payment = SaaSPaymentService()
    @StateObject private var observer = PaymentObserver()
    @State private var qrImage: PlatformImage?
    @State private var verificationTask: Task<Void, Never>?
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Erişim Bilgisi").font(.title2.bold())

            if let qr = qrImage {
                #if canImport(UIKit)
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                #elseif canImport(AppKit)
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                #endif
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Ücret: 0.00").bold()
                Text("Model: \(payment.accessLabel)").foregroundColor(.gray)
                Text("Bu App Store sürümünde ayrı bir ödeme veya kripto transferi gerekmez.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(QAITheme.accent)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            PrimaryButton(title: observer.isVerifying ? "Hazırlanıyor..." : "Ücretsiz Erişimi Onayla") {
                confirmPayment()
            }
            .disabled(observer.isVerifying)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .task {
            if qrImage == nil {
                qrImage = payment.generateQRCode(from: payment.accessLabel)
            }
        }
        .onDisappear {
            verificationTask?.cancel()
            verificationTask = nil
        }
    }

    private func confirmPayment() {
        guard !observer.isVerifying else { return }

        verificationTask?.cancel()
        verificationTask = Task {
            let isVerified = await observer.activateFreeAccess()

            guard isVerified, !Task.isCancelled else { return }

            await MainActor.run {
                env.settings.isAuthenticated = true
                GlobalSinirSistemi.paylasilan.veriPompala(
                    kategori: .sistem,
                    mesaj: "Ucretsiz erisim bu cihazda onaylandi",
                    veri: [:]
                )
                dismiss()
            }
        }
    }
}
