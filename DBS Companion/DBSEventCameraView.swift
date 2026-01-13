import AVFoundation
import Combine
import SwiftUI

struct DBSEventCameraView: View {
    @Environment(\.dismiss) private var dismiss

    let onCapture: (UIImage) -> Void

    @StateObject private var model = DBSEventCameraModel()

    var body: some View {
        ZStack {
            CameraPreview(session: model.session)
                .ignoresSafeArea()

            GeometryReader { proxy in
                Image("event_recorded_template_alpha")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width * DBSEventTemplateLayout.templateScale)
                    .position(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0 + (DBSEventTemplateLayout.templateYOffset * proxy.size.height))
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()

                if let status = model.statusText {
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    model.captureManually()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(model.canManualCapture ? Color.white : Color.white.opacity(0.4), lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(model.canManualCapture ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 58, height: 58)
                    }
                }
                .disabled(!model.canManualCapture)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            model.onCapture = { image in
                onCapture(image)
                dismiss()
            }
            model.start()
        }
        .onDisappear {
            model.stop()
        }
    }
}

private final class DBSEventCameraModel: NSObject, ObservableObject {
    @Published var canManualCapture = false
    @Published var statusText: String? = "Looking for DBS template..."

    let session = AVCaptureSession()

    var onCapture: ((UIImage) -> Void)?

    private let sessionQueue = DispatchQueue(label: "dbs.camera.session")
    private let videoQueue = DispatchQueue(label: "dbs.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var isConfigured = false
    private var didCapture = false
    private var lastAnalysis = Date.distantPast
    private var isCapturing = false
    private var matchStreak = 0
    private var lastMatch = Date.distantPast
    private var firstMatch = Date.distantPast
    private let requiredMatchStreak = 3
    private let autoCaptureDelay: TimeInterval = 1.5

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.statusText = "Camera access is required"
                    }
                }
            }
        default:
            statusText = "Camera access is required"
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureManually() {
        guard canManualCapture else { return }
        capturePhoto()
    }

    private func configureAndStart() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.didCapture = false
                self.isCapturing = false
                self.matchStreak = 0
                self.lastMatch = .distantPast
                self.firstMatch = .distantPast
                self.canManualCapture = false
                self.statusText = "Looking for DBS template..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    if !self.didCapture {
                        self.canManualCapture = true
                        self.statusText = "Hold steady or tap to capture"
                    }
                }
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            return
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            applyPortraitOrientation(to: connection)
        }
        if let connection = photoOutput.connection(with: .video) {
            applyPortraitOrientation(to: connection)
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func applyPortraitOrientation(to connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 90
        } else {
            connection.videoOrientation = .portrait
        }
    }
}

extension DBSEventCameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.isCapturing = false
                self.statusText = "Capture failed"
            }
            return
        }

        DispatchQueue.main.async {
            self.didCapture = true
            self.statusText = "Captured"
            self.onCapture?(image)
        }
    }
}

extension DBSEventCameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !didCapture, !isCapturing else { return }
        let now = Date()
        if now.timeIntervalSince(lastAnalysis) < 0.7 { return }
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let template = DBSEventTemplateStore.shared else {
            return
        }

        let matches = (try? template.matches(pixelBuffer: pixelBuffer, orientation: .right)) ?? false
        if matches {
            DispatchQueue.main.async {
                let now = Date()
                if now.timeIntervalSince(self.lastMatch) < 0.8 {
                    self.matchStreak += 1
                } else {
                    self.matchStreak = 1
                    self.firstMatch = now
                }
                self.lastMatch = now
                self.statusText = "Template detected"
                if self.matchStreak >= self.requiredMatchStreak,
                   now.timeIntervalSince(self.firstMatch) >= self.autoCaptureDelay {
                    self.capturePhoto()
                }
            }
        } else if matchStreak > 0 {
            DispatchQueue.main.async {
                self.matchStreak = 0
                self.firstMatch = .distantPast
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
