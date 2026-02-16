import SwiftUI

struct UIComponents {
    
    struct IconButton: View {
        let icon: String
        let action: () -> Void
        var size: CGFloat = 24
        var color: Color = .white
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundColor(color)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    struct CaptureButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }
        }
    }
    
    struct PrimaryButton: View {
        let title: String
        let icon: String?
        let action: () -> Void
        var color: Color = .blue
        
        var body: some View {
            Button(action: action) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    struct IntensitySlider: View {
        @Binding var value: Float
        
        var body: some View {
            HStack {
                Image(systemName: "sun.min")
                    .foregroundColor(.gray)
                
                Slider(value: $value, in: 0...1)
                    .accentColor(.white)
                
                Image(systemName: "sun.max")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
    }
}
