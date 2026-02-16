import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject {
    var session = AVCaptureSession()
    @Published var alert = false
    var videoOutput = AVCaptureVideoDataOutput()
    var liveFrame: UIImage?          // NOT @Published — won't trigger parent view re-renders
    var rawFrame: UIImage?           // Raw undithered frame for capture
    
    /// Custom publisher for frame updates — only CameraView subscribes to this
    let framePublisher = PassthroughSubject<UIImage?, Never>()
    
    @Published var currentAlgorithm: DitheringAlgorithm = .floydSteinberg
    @Published var intensity: Float = 0.5
    @Published var isMirrored: Bool = true // Tracks if current cam should be mirrored
    private var customMirroringOverride: Bool? = nil
    
    private let processingQueue = DispatchQueue(label: "com.phomemo.camera.processing", qos: .userInteractive)
    private var isProcessing = false
    private let context = CIContext(options: [.useSoftwareRenderer: false])
        
    private let sessionQueue = DispatchQueue(label: "com.phomemo.camera.session")

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    self?.setup()
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.alert = true
            }
        @unknown default:
            break
        }
    }
    
    func setup(position: AVCaptureDevice.Position = .front) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                self.session.beginConfiguration()
                
                // Remove existing inputs
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                
                // Camera (front or back)
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                    print("No camera found for position \(position)")
                    self.session.commitConfiguration()
                    return
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
                    self.session.addOutput(self.videoOutput)
                }
                
                DispatchQueue.main.async {
                    self.isMirrored = self.customMirroringOverride ?? (position == .front)
                    print("DEBUG: Camera setup position: \(position), isMirrored: \(self.isMirrored)")
                }
                
                self.session.commitConfiguration()
                
                // Apply connection settings after commit
                DispatchQueue.main.async {
                    self.updateConnectionSettings()
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateConnectionSettings() {
        if let connection = self.videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            var rotationStr = "N/A"
            var orientationStr = "N/A"
            
            if #available(iOS 17.0, *) {
                rotationStr = String(describing: connection.videoRotationAngle)
            } else {
                 orientationStr = String(describing: connection.videoOrientation)
            }
            
            print("DEBUG: Connection settings updated. Orientation: \(orientationStr), Mirrored: \(connection.isVideoMirrored), Rotation: \(rotationStr)")
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else {
                self.session.commitConfiguration()
                return
            }
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
            // We need to call setup-like logic but setup is async, so better refactor or just do it here
            // Re-using setup(position:) which is async would be nested async.
            // Let's just call setup, but we need to pass the position.
            // But wait, setup() calls sessionQueue.async. Better to not use setup() inside here if we are already on queue.
            // For simplicity, let's just dispatch to setup which handles the queue.
            // BUT we can't get currentInput if we are not on the queue... 
            // Actually session.inputs property access is skipping the queue in current code, which is risky if session is being mutated.
            // Let's stick to the plan: run everything on sessionQueue.
            
            // To avoid nested async, we can just call an internal synchronous setup if we had one.
            // For now, let's just implement the switch here safely.
            
            self.session.removeInput(currentInput)
             guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                self.session.commitConfiguration() // revert?
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                 DispatchQueue.main.async {
                    self.isMirrored = self.customMirroringOverride ?? (newPosition == .front)
                }
                self.session.commitConfiguration()
                 DispatchQueue.main.async {
                    self.updateConnectionSettings()
                }
            } catch {
                 print("Error switching camera: \(error)")
                 self.session.commitConfiguration()
            }
        }
    }
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.updateConnectionSettings()
                }
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func setMirroringOverride(_ mirrored: Bool?) {
        self.customMirroringOverride = mirrored
        // We need to check inputs to determine default, so we should do this on sessionQueue?
        // session.inputs is not thread safe? 
        // AVCaptureSession is generally thread safe for reading, but it's better to be consistent.
        // However, updates to connection must be done... where? Connection updates usually specific to transaction.
        // updateConnectionSettings() uses `videoOutput.connection`.
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let currentInput = self.session.inputs.first as? AVCaptureDeviceInput {
                 DispatchQueue.main.async {
                    self.isMirrored = mirrored ?? (currentInput.device.position == .front)
                    self.updateConnectionSettings()
                }
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 1. Extract the CVImageBuffer synchronously while it is valid.
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 2. We need to access MainActor properties (settings) safely.
        // Since we are on the processing queue (non-main), we use a synchronous task/dispatch to get values.
        // Note: dispatch_sync to main is safe provided we are not already on main (we are not).
        var settings: (Float, DitheringAlgorithm, Bool)?
        
        DispatchQueue.main.sync {
            // Need to capture from self which is main isolated?
            // "self" is isolated to MainActor? No, CameraService is a class, implicitly internal.
            // But it conforms to ObservableObject which implies MainActor isolation for @Published properties?
            // Actually, @Published properties are not strictly MainActor isolated unless the class is.
            // But usually UI related view models are MainActor.
            // Let's assume accessing them requires main actor.
            // Wait, "CameraService" is just a class. @Published properties lock inside Combine.
            // However, to be safe and avoid warnings:
            if self.session.isRunning && !self.isProcessing {
                self.isProcessing = true
                settings = (self.intensity, self.currentAlgorithm, self.isMirrored)
            }
        }
        
        guard let (intensity, algorithm, isMirrored) = settings else { return }
        
        // 3. Process in background
        // We use CIImage to wrap the CVPixelBuffer. This retains the buffer.
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        DispatchQueue.global(qos: .userInteractive).async {
             guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                 DispatchQueue.main.async { self.isProcessing = false }
                 return
             }
             
             let uiImage = UIImage(cgImage: cgImage)
             
             // Process
             let processed = PhomemoImageProcessor.processForPreview(
                 image: uiImage,
                 algorithm: algorithm,
                 intensity: intensity,
                 mirror: isMirrored
             )
             
             DispatchQueue.main.async {
                 self.rawFrame = uiImage
                 self.liveFrame = processed
                 self.framePublisher.send(processed)
                 self.isProcessing = false
             }
        }
    }
}
