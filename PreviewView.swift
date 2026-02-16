import SwiftUI

struct PreviewView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var startIntensity: Float = 0.5
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = viewModel.capturedImage {
                    ZStack {
                        Color.black
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: viewModel.imageSource == .camera ? .fill : .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            
                        // FEEDBACK OVERLAYS REMOVED AS REQUESTED
                        // (Gestures still active for real-time preview)
                    }
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) 
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                // Detect direction if not already adjusting
                                if !viewModel.isAdjustingIntensity {
                                    if abs(value.translation.height) > abs(value.translation.width) {
                                        viewModel.isAdjustingIntensity = true
                                        startIntensity = viewModel.cameraService.intensity
                                    }
                                }
                                
                                if viewModel.isAdjustingIntensity {
                                    // Drag Up (-Y) -> Increase
                                    let delta = Float(-value.translation.height / 300.0)
                                    let newIntensity = min(max(startIntensity + delta, 0.0), 1.0)
                                    viewModel.intensityBinding.wrappedValue = newIntensity
                                }
                            }
                            .onEnded { value in
                                if viewModel.isAdjustingIntensity {
                                    viewModel.isAdjustingIntensity = false
                                } else {
                                    // Horizontal Swipe
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
                }
                
                VStack {
                    Spacer()
                    
                    // Bottom Controls (Mirrors CameraView)
                    // Hiding status message as requested ("Retire a atual barra, bem como o status")
                    
                    HStack(alignment: .center, spacing: 60) {
                        // Return to Camera (Left)
                        UIComponents.IconButton(icon: "arrow.uturn.backward", action: {
                            viewModel.retake()
                        })
                        
                        // Print Button (Center)
                        Button(action: {
                            viewModel.printImage()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(viewModel.themeColor, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .fill(viewModel.themeColor)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "printer.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24, weight: .bold))
                            }
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    // Swipe Up (-Y) -> Show Settings
                                    if value.translation.height < -50 {
                                        viewModel.showSettings = true
                                    }
                                }
                        )
                        
                        // Save to Gallery (Right)
                        UIComponents.IconButton(icon: "square.and.arrow.down", action: {
                            viewModel.saveToGallery()
                        })
                    }
                    .padding(.bottom, 30)
                    .padding(.top, 20)
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}
