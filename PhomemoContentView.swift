import SwiftUI
import CoreBluetooth

struct PhomemoContentView: View {
    @StateObject var driver = PhomemoDriver()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Header
                statusHeader
                
                if driver.connectedPeripheral == nil {
                    discoveryView
                } else {
                    printerControlView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Phomemo App Clip")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if driver.isRunning {
                        ProgressView()
                    }
                }
            }
        }
    }
    
    private var statusHeader: some View {
        HStack {
            Image(systemName: driver.connectedPeripheral != nil ? "printer.fill" : "printer.dot.fill.and.paper.fill")
                .foregroundColor(driver.connectedPeripheral != nil ? .green : .gray)
                .font(.largeTitle)
            
            VStack(alignment: .leading) {
                Text(driver.statusMessage)
                    .font(.headline)
                if let name = driver.connectedPeripheral?.name {
                    Text("Connected to \(name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var discoveryView: some View {
        VStack {
            Text("Procurando impressoras...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            List(driver.discoveredPeripherals, id: \.identifier) { peripheral in
                Button(action: {
                    driver.connect(to: peripheral)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peripheral.name ?? "Unknown Device")
                                .font(.body)
                            Text(peripheral.identifier.uuidString.prefix(8))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(PlainListStyle())
            
            Button(action: {
                driver.startScanning()
            }) {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private var printerControlView: some View {
        VStack(spacing: 15) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("No image selected")
                        }
                        .foregroundColor(.gray)
                    )
            }
            
            HStack(spacing: 10) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    Label("Pick Image", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if let img = selectedImage {
                        driver.printImage(img)
                    }
                }) {
                    Label("Print", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedImage == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedImage == nil)
            }
            
            Button(action: {
                // Test Status
                driver.send(PhomemoCommands.CHECK_STATUS)
            }) {
                Text("Check Printer Status")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: &showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// Simple Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct PhomemoContentView_Previews: PreviewProvider {
    static var previews: some View {
        PhomemoContentView()
    }
}
