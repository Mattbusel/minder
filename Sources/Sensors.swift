import AVFoundation
import CoreMotion
import Vision
import UIKit

/// Front camera, face rectangles only, about ten reads a second. Frames are
/// never stored: each buffer is handed to Vision and released.
final class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "minder.face")
    private var configured = false
    private var lastRead: CFTimeInterval = 0
    var onFace: ((CGPoint) -> Void)?

    static var authorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { done(ok) } }
    }

    func start() {
        guard FaceTracker.authorized else { return }
        queue.async { [self] in
            if !configured { configure() }
            if configured && !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    private func configure() {
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: cam) else { return }
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }
        let out = AVCaptureVideoDataOutput()
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastRead > 0.1, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastRead = now
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored).perform([request])
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return }
        let b = face.boundingBox
        // Vision's origin is bottom-left. Map to -1...1 with +y down, the way the canvas thinks.
        let p = CGPoint(x: max(-1, min(1, (b.midX - 0.5) * 2.4)),
                        y: max(-1, min(1, (0.5 - b.midY) * 2.0)))
        DispatchQueue.main.async { self.onFace?(p) }
    }
}

/// Notices when the phone is lifted or knocked, which during work mode means
/// you picked it up.
final class MotionWatcher {
    private let manager = CMMotionManager()
    var onMove: (() -> Void)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20
        manager.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let m else { return }
            let a = m.userAcceleration, r = m.rotationRate
            let jolt = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            let spin = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
            if jolt > 0.28 || spin > 1.4 { self?.onMove?() }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

enum Haptics {
    static var enabled = true
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
