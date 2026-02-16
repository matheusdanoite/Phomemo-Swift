import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var initialIntensity: Float = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Camera Feed Layer (Full Screen Aspect Ratio)
                Color.black.ignoresSafeArea()
                
                if let image = viewModel.liveFrame {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    VStack {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("Starting Camera...").foregroundColor(.white).padding(.top)
                    }
                }
                
                // 2. Combined Gesture Handler (Intensity & Algorithms)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                // Detect direction if not already adjusting
                                if !viewModel.isAdjustingIntensity {
                                    // If vertical movement dominates, start intensity adjustment
                                    if abs(value.translation.height) > abs(value.translation.width) {
                                        viewModel.isAdjustingIntensity = true
                                        initialIntensity = viewModel.cameraService.intensity
                                    }
                                }
                                
                                if viewModel.isAdjustingIntensity {
                                    // Vertical Drag -> Intensity
                                    // Drag Up (-Y) -> Increase Intensity
                                    // Drag Down (+Y) -> Decrease Intensity
                                    // Scale: 300px = full range
                                    let delta = Float(-value.translation.height / 300.0)
                                    let newIntensity = min(max(initialIntensity + delta, 0.0), 1.0)
                                    viewModel.intensityBinding.wrappedValue = newIntensity
                                }
                            }
                            .onEnded { value in
                                if viewModel.isAdjustingIntensity {
                                    viewModel.isAdjustingIntensity = false
                                } else {
                                    // Horizontal Swipe for Algorithms
                                    if abs(value.translation.width) > 50 {
                                        if value.translation.width < 0 {
                                            viewModel.nextAlgorithm()
                                        } else {
                                            viewModel.prevAlgorithm()
                                        }
                                    }
                                }
                            }
                    )
                
                // 4. User Interface Layer (Foreground)
                VStack {
                    // Top: Algorithm & Settings
                    // Top Bar (Aligned with Bottom Controls)
                    // Top Bar
                    Spacer()
                    

                    
                    if !viewModel.isPreviewing {
                        // Bottom Controls
                        HStack(alignment: .center, spacing: 60) {
                            // Camera Toggle (Relocated)
                            UIComponents.IconButton(icon: "arrow.triangle.2.circlepath.camera", action: {
                                viewModel.toggleCamera()
                            }, backgroundColor: viewModel.themeColor.opacity(0.8))
                            
                            // Capture Button
                            UIComponents.CaptureButton(action: {
                                viewModel.capture()
                            }, themeColor: viewModel.themeColor)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        // Swipe Up (-Y) -> Show Settings
                                        if value.translation.height < -50 {
                                            viewModel.showSettings = true
                                        }
                                    }
                            )
                            
                            // Gallery
                            UIComponents.IconButton(icon: "photo.on.rectangle", action: {
                                viewModel.showPhotoPicker = true
                            }, backgroundColor: viewModel.themeColor.opacity(0.8))
                        }
                        .padding(.bottom, 30)
                        .padding(.top, 20)
                    }
                }
                .allowsHitTesting(true) // Ensure this layer receives touches
                
                if viewModel.isPreviewing {
                    PreviewView(viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                        .zIndex(20)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.cameraService.checkPermissions()
            viewModel.cameraService.start()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPicker(selectedImage: Binding(
                get: { nil }, // Always show empty state initially or doesn't matter for picker
                set: { image in
                    if let image = image {
                        viewModel.handlePhotoSelection(image)
                    }
                }
            ))
        }
    }
}


