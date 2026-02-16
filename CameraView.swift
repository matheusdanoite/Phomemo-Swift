import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        ZStack {
            // 1. Camera Feed Layer
            Color.black.ignoresSafeArea()
            
            if let image = viewModel.liveFrame {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                // Loading State
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Starting Camera...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            // 2. Controls Layer
            VStack {
                // Top Bar
                HStack {
                    UIComponents.IconButton(icon: "gear", action: {
                        viewModel.showSettings = true
                    })
                    
                    Spacer()
                    
                    UIComponents.IconButton(icon: "arrow.triangle.2.circlepath.camera", action: {
                        viewModel.toggleCamera()
                    })
                }
                .padding(.horizontal)
                .padding(.top, 40) // Adjust for safe area
                
                Spacer()
                
                if !viewModel.isPreviewing {
                    // Bottom Controls
                    VStack(spacing: 24) {
                        // Intensity Slider
                        VStack(spacing: 8) {
                            Text(viewModel.cameraService.currentAlgorithm.rawValue)
                                .foregroundColor(.white)
                                .font(.caption2)
                                .padding(4)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(4)
                            
                            UIComponents.IntensitySlider(value: viewModel.intensityBinding)
                                .frame(maxWidth: 280)
                        }
                        
                        // Main Action Bar
                        HStack(alignment: .center, spacing: 50) {
                            // Mirror Toggle
                            UIComponents.IconButton(
                                icon: viewModel.cameraService.isMirrored ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                action: { viewModel.toggleMirror() }
                            )
                            
                            // Capture Button
                            UIComponents.CaptureButton {
                                viewModel.capture()
                            }
                            
                            // Placeholder/Gallery (Empty for now)
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.black.opacity(0), .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    )
                }
            }
            
            // 3. Preview/Review Layer
            if viewModel.isPreviewing {
                PreviewView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .onAppear {
            viewModel.cameraService.checkPermissions()
            viewModel.cameraService.start()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}
