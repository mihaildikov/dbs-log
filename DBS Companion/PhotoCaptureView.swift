import SwiftUI
import UIKit

struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    var onForm: (ParsedEventDraft) -> Void
    var onManual: () -> Void

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var didAutoPresent = false
    @State private var capturedImage: UIImage?
    @State private var status: Status = .idle
    @State private var draft: ParsedEventDraft?

    private let analyzer = PhotoEventAnalyzer()

    enum Status: Equatable {
        case idle
        case analyzing
        case error(String)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let draft {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event detected")
                        .font(.title2.weight(.semibold))
                    if let type = draft.type {
                        Text("Type: \(type.displayName)")
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if let time = draft.timestamp {
                        Text("Time: \(time.formatted(date: .omitted, time: .shortened))")
                    }
                    if let source = draft.source {
                        Text("Source: \(source)")
                    }
                    if let notes = draft.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Button {
                        onForm(draft)
                    } label: {
                        Label("Go to form", systemImage: "doc.plaintext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Retake photo") {
                    retake()
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    Text("Capture a Medtronic Percept event screen")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.top)

                    HStack(spacing: 12) {
                        Button {
                            showLibrary = true
                        } label: {
                            Label("Pick photo", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showCamera = true
                        } label: {
                            Label("Take photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if case .analyzing = status {
                        ProgressView("Analyzing photo...")
                    }

                    if case .error(let message) = status {
                        Text(message)
                            .foregroundStyle(.red)
                    }

                    Button("Manual entry") {
                        onManual()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showCamera, onDismiss: handleDismiss) {
            DBSEventCameraView { image in
                capturedImage = image
            }
        }
        .sheet(isPresented: $showLibrary, onDismiss: handleDismiss) {
            CameraPicker(image: $capturedImage, source: .photoLibrary)
        }
        .navigationTitle("DBS Event")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didAutoPresent {
                didAutoPresent = true
                showCamera = true
            }
        }
    }

    private func handleDismiss() {
        guard let image = capturedImage else {
            status = .idle
            return
        }
        Task {
            status = .analyzing
            do {
                let parsed = try await analyzer.analyze(image: image)
                await MainActor.run {
                    self.draft = parsed
                    self.status = .idle
                }
            } catch {
                await MainActor.run {
                    self.status = .error(errorMessage(for: error))
                    self.draft = nil
                }
            }
        }
    }

    private func retake() {
        capturedImage = nil
        draft = nil
        status = .idle
        showCamera = true
    }

    private func errorMessage(for error: Error) -> String {
        guard let analyzerError = error as? PhotoEventAnalyzer.AnalyzerError else {
            return "Couldn't detect event details from photo"
        }

        switch analyzerError {
        case .templateMissing:
            return "Template image missing from the app bundle"
        case .templateMismatch:
            return "Photo doesn't match the DBS event template"
        case .noText:
            return "Couldn't read the DBS event details"
        case .invalidImage:
            return "Invalid photo captured"
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let source: UIImagePickerController.SourceType

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(source) {
            picker.sourceType = source
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
