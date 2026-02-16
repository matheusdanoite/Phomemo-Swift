import SwiftUI

extension Color {
    static let phomemoTeal = Color(red: 116/255, green: 183/255, blue: 174/255)
    static let phomemoPink = Color(red: 250/255, green: 229/255, blue: 228/255)
}

struct UIComponents {
    
    struct IconButton: View {
        let icon: String
        let action: () -> Void
        var size: CGFloat = 24
        var color: Color = .white
        var backgroundColor: Color = .phomemoTeal.opacity(0.8) // Default to Teal, but settable
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundColor(color)
                    .padding(12)
                    .background(backgroundColor)
                    .clipShape(Circle())
            }
        }
    }
    
    struct CaptureButton: View {
        let action: () -> Void
        var themeColor: Color = .phomemoTeal // Default, but settable
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(themeColor, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(themeColor)
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
