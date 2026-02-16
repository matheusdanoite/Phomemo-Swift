import SwiftUI
import Combine
import UIKit

class ContentViewModel: ObservableObject {
    // Services
    @Published var cameraService = CameraService()
    @Published var phomemoDriver = PhomemoDriver()
    @Published var printerSharing = PrinterSharingService()
    
    enum ImageSource {
        case camera
        case gallery
    }

    @Published var imageSource: ImageSource = .camera
    
    @Published var originalImage: UIImage? // Store raw gallery image
    @Published var capturedImage: UIImage?
    @Published var liveFrame: UIImage?
    @Published var isPreviewing: Bool = false
    @Published var showSettings: Bool = false
    @Published var showPhotoPicker: Bool = false
    @Published var isAdjustingIntensity: Bool = false
    
    // Theme State
    @Published var isPinkTheme: Bool = false {
        didSet {
            themeColor = isPinkTheme ? .phomemoPink : .phomemoTeal
        }
    }
    @Published var themeColor: Color = .phomemoTeal
    
    private var cancellables = Set<AnyCancellable>()
    
    // Bindings for UI to CameraService
    var intensityBinding: Binding<Float> {
        Binding(
            get: { self.cameraService.intensity },
            set: { self.cameraService.intensity = $0 }
        )
    }
    
    var algorithmBinding: Binding<DitheringAlgorithm> {
        Binding(
            get: { self.cameraService.currentAlgorithm },
            set: { self.cameraService.currentAlgorithm = $0 }
        )
    }
    
    init() {
        // Subscribe to camera frames
        cameraService.framePublisher
            .receive(on: RunLoop.main)
            .assign(to: \.liveFrame, on: self)
            .store(in: &cancellables)
            
        // Forward changes from child services to ensure UI updates
        cameraService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        phomemoDriver.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        printerSharing.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        phomemoDriver.$connectedPeripheral
            .receive(on: RunLoop.main)
            .sink { [weak self] peripheral in
                if peripheral != nil {
                    // Connected to printer -> Become Host
                    if self?.printerSharing.role != .host {
                        self?.printerSharing.setRole(.host)
                    }
                } else {
                    // Disconnected -> Become Client (look for host)
                    if self?.printerSharing.role != .client {
                        self?.printerSharing.setRole(.client)
                    }
                }
            }
            .store(in: &cancellables)
            
        setupGalleryProcessing()
    }
    
    private func setupGalleryProcessing() {
        // Debounce intensity changes to avoid too much processing
        Publishers.CombineLatest(
            cameraService.$intensity,
            cameraService.$currentAlgorithm
        )
        .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
        .sink { [weak self] intensity, algorithm in
            self?.processGalleryImageIfNeeded(intensity: intensity, algorithm: algorithm)
        }
        .store(in: &cancellables)
    }
    
    private func processGalleryImageIfNeeded(intensity: Float, algorithm: DitheringAlgorithm) {
        guard imageSource == .gallery, let raw = originalImage else { return }
        
        // Run processing in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Check mirroring? Usually gallery images shouldn't be mirrored by default unless requested.
            // For now, we assume no mirror for gallery.
            let processed = PhomemoImageProcessor.processForPreview(
                image: raw,
                algorithm: algorithm,
                intensity: intensity,
                mirror: false
            )
            
            DispatchQueue.main.async {
                self.capturedImage = processed
            }
        }
    }
    
    // ...
    
    // MARK: - Actions
    
    func handlePhotoSelection(_ image: UIImage) {
        self.imageSource = .gallery
        self.originalImage = image
        self.capturedImage = image // Will be updated by pipeline shortly
        self.isPreviewing = true
        self.cameraService.stop()
        
        // Trigger initial processing
        processGalleryImageIfNeeded(intensity: cameraService.intensity, algorithm: cameraService.currentAlgorithm)
    }
    
    func capture() {
        // Capture the current live dithered frame
        if let frame = cameraService.liveFrame {
            self.imageSource = .camera
            self.capturedImage = frame
            self.isPreviewing = true
            // Stop camera to save resources/battery while reviewing
            self.cameraService.stop()
        }
    }
    
    func retake() {
        self.capturedImage = nil
        self.isPreviewing = false
        // Restart camera
        self.cameraService.start()
    }
    
    func printImage() {
        if imageSource == .gallery, let original = originalImage {
            // Check orientation
            let isLandscape = original.size.width > original.size.height
            
            // Print using the driver which will handle rotation and processing
            phomemoDriver.printImage(
                original,
                algorithm: cameraService.currentAlgorithm,
                intensity: cameraService.intensity,
                mirror: false, // Don't mirror gallery by default
                rotate: isLandscape // Rotate if landscape to fit paper better
            )
        } else {
            // Camera source or missing original
            guard let image = self.capturedImage else { return }
            
            // Since we captured the liveFrame (which is already dithered/processed for preview),
            // and camera frame is usually portrait-ish (or already processed to fit),
            // we use the 'printProcessedImage' method to bypass double-dithering.
            phomemoDriver.printProcessedImage(image)
        }
    }
    
    func saveToGallery() {
        guard let image = self.capturedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // Optional: Add feedback (toast/alert) that it was saved?
        // For now, implicit action as requested.
    }
    
    func toggleCamera() {
        cameraService.switchCamera()
    }
    
    func toggleMirror() {
        // Toggle between forced mirror, forced normal, or auto?
        // For now, simple toggle of the boolean in service via a helper if needed,
        // but Service has 'isMirrored' published.
        // Let's implement a simple toggle override
        let current = cameraService.isMirrored
        cameraService.setMirroringOverride(!current)
    }
    

    
    // MARK: - Gesture Helpers
    
    func nextAlgorithm() {
        let all = DitheringAlgorithm.allCases
        if let idx = all.firstIndex(of: cameraService.currentAlgorithm) {
            let nextIdx = (idx + 1) % all.count
            cameraService.currentAlgorithm = all[nextIdx]
        }
    }
    
    func prevAlgorithm() {
        let all = DitheringAlgorithm.allCases
        if let idx = all.firstIndex(of: cameraService.currentAlgorithm) {
            let prevIdx = (idx - 1 + all.count) % all.count
            cameraService.currentAlgorithm = all[prevIdx]
        }
    }
}
