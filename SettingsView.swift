import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bluetooth Sharing")) {
                    if viewModel.printerSharing.role == .host {
                        HStack {
                            Text("Mode")
                            Spacer()
                            Text("Host (Printer Connected)")
                                .foregroundColor(viewModel.themeColor)
                                .bold()
                        }
                        
                        HStack {
                            Text("Peers Connected")
                            Spacer()
                            Text("\(viewModel.printerSharing.connectedPeers.count)")
                                .foregroundColor(viewModel.printerSharing.connectedPeers.isEmpty ? .gray : viewModel.themeColor)
                        }
                        
                        Text("Broadcasting availability to nearby devices.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                    } else {
                        HStack {
                            Text("Mode")
                            Spacer()
                            Text("Client (Scanning)")
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(viewModel.printerSharing.statusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Printer")) {
                    if viewModel.phomemoDriver.isRunning {
                        if let peripheral = viewModel.phomemoDriver.connectedPeripheral {
                            HStack {
                                Text("Connected to")
                                Spacer()
                                Text(peripheral.name ?? "Unknown")
                                    .foregroundColor(viewModel.themeColor)
                            }
                            Text(viewModel.phomemoDriver.statusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            HStack {
                                Text("Status")
                                Spacer()
                                Text("Scanning...")
                                    .foregroundColor(.orange)
                            }
                            Button("Stop Scanning") {
                                viewModel.phomemoDriver.stopScanning()
                            }
                        }
                    } else {
                        Button("Start Scanning") {
                            viewModel.phomemoDriver.startScanning()
                        }
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Toggle("Pink Mode", isOn: $viewModel.isPinkTheme)
                        .toggleStyle(SwitchToggleStyle(tint: viewModel.themeColor))
                }

                Section {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
