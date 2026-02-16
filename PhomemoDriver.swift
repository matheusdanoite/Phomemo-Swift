import Foundation
import CoreBluetooth
import UIKit
import Combine

class PhomemoDriver: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = "Idle"
    
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 30.0
    
    private let writeUUID = CBUUID(string: PhomemoCommands.WRITE_CHARACTERISTIC_UUID)
    private let notifyUUID = CBUUID(string: PhomemoCommands.NOTIFY_CHARACTERISTIC_UUID)
    
    private var statusCompletion: ((Bool, String) -> Void)?
    
    private let lastDeviceKey = "PhomemoLastDeviceID"
    
    override init() {
        super.init()
        print("[PhomemoDriver] Initializing Central Manager...")
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        print("[PhomemoDriver] Requesting scan...")
        guard centralManager.state == .poweredOn else {
            print("[PhomemoDriver] Scan failed: Bluetooth is \(centralManager.state.rawValue)")
            statusMessage = "Bluetooth is off"
            return
        }
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("[PhomemoDriver] Scan started.")
        statusMessage = "Scanning..."
        isRunning = true
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isRunning = false
        statusMessage = "Scan stopped"
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("[PhomemoDriver] Connecting to \(peripheral.name ?? "Unknown") [\(peripheral.identifier)]...")
        // We don't necessarily need to stop scan here if we want to be aggressive, 
        // but it's good practice. We will restart it on failure/disconnect.
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
        statusMessage = "Connecting to \(peripheral.name ?? "Unknown")..."
    }
    
    func printImage(_ image: UIImage, algorithm: DitheringAlgorithm = .floydSteinberg, intensity: Float = 0.5, mirror: Bool = false, rotate: Bool = false) {
        guard connectedPeripheral != nil, writeCharacteristic != nil else {
            statusMessage = "Printer not connected"
            return
        }
        
        statusMessage = "Processing image..."
        
        // Prepare image data
        print("[PhomemoDriver] Starting print job for image size: \(image.size) with algorithm: \(algorithm.rawValue) (intensity: \(intensity)) (mirror: \(mirror)) (rotate: \(rotate))")
        let chunks = preparePrintChunks(from: image, algorithm: algorithm, intensity: intensity, mirror: mirror, rotate: rotate)
        print("[PhomemoDriver] Image split into \(chunks.count) chunks.")
        
        Task {
            print("[PhomemoDriver] Sending print sequence...")
            statusMessage = "Printing..."
            
            // 1. Init
            print("[PhomemoDriver] Sending INIT command.")
            send(PhomemoCommands.INIT_PRINTER)
            
            // 2. Chunks
            for (index, chunk) in chunks.enumerated() {
                send(chunk)
                // Small delay to avoid buffer overflow, similar to Python's sleep(0.04)
                try? await Task.sleep(nanoseconds: 40_000_000)
                
                if index % 5 == 0 {
                    let progress = Int((Double(index) / Double(chunks.count)) * 100)
                    DispatchQueue.main.async {
                        self.statusMessage = "Printing: \(progress)%"
                    }
                }
            }
            
            // 3. Footer (feed 3 lines)
            print("[PhomemoDriver] Printing complete. Sending feed command.")
            send(PhomemoCommands.feedLines(3))
            
            DispatchQueue.main.async {
                self.statusMessage = "Success!"
            }
        }
    }
    
    func send(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral, let char = writeCharacteristic else { 
            print("[PhomemoDriver] Error: Cannot send data, peripheral or characteristic missing.")
            return 
        }
        let data = Data(bytes)
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }
    
    func printProcessedImage(_ image: UIImage) {
        guard connectedPeripheral != nil, writeCharacteristic != nil else {
            statusMessage = "Printer not connected"
            return
        }
        
        statusMessage = "Preparing data..."
        
        // Use the simple direct path (no processing, no mirroring, no dithering)
        let chunks = PhomemoImageProcessor.convertToRasterChunksSimple(image: image)
        
        Task {
            print("[PhomemoDriver] Sending direct print sequence (\(chunks.count) chunks)...")
            statusMessage = "Printing..."
            
            send(PhomemoCommands.INIT_PRINTER)
            
            for (index, chunk) in chunks.enumerated() {
                send(chunk)
                try? await Task.sleep(nanoseconds: 40_000_000)
                
                if index % 5 == 0 {
                    let progress = Int((Double(index) / Double(chunks.count)) * 100)
                    DispatchQueue.main.async { self.statusMessage = "Printing: \(progress)%" }
                }
            }
            
            send(PhomemoCommands.feedLines(3))
            
            DispatchQueue.main.async { self.statusMessage = "Success!" }
        }
    }
    
    private func preparePrintChunks(from image: UIImage, algorithm: DitheringAlgorithm, intensity: Float, mirror: Bool, rotate: Bool) -> [[UInt8]] {
        return PhomemoImageProcessor.convertToRasterChunks(image: image, algorithm: algorithm, intensity: intensity, mirror: mirror, rotate: rotate)
    }
}

extension PhomemoDriver: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[PhomemoDriver] Central state changed: \(central.state.rawValue)")
        if central.state != .poweredOn {
            isRunning = false
            statusMessage = "Bluetooth Unavailable (\(central.state.rawValue))"
        } else {
            print("[PhomemoDriver] Bluetooth is ON and ready. Starting scan...")
            startScanning() // Added this to trigger scan once radio is ready
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let isPhomemo = name.contains("T02") || name.contains("Phomemo")
        
        print("[PhomemoDriver] Found peripheral: \(name) [\(peripheral.identifier)] RSSI: \(RSSI) | IsPhomemo: \(isPhomemo)")
        
        if isPhomemo {
            if !discoveredPeripherals.contains(peripheral) {
                discoveredPeripherals.append(peripheral)
            }
            
            if connectedPeripheral == nil {
                print("[PhomemoDriver] Triggering auto-connect for \(name)...")
                statusMessage = "Auto-connecting to \(name)..."
                connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[PhomemoDriver] Connected to \(peripheral.name ?? "Unknown"). Starting service discovery...")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        statusMessage = "Connected. Discovering services..."
        
        startHeartbeat()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[PhomemoDriver] Failed to connect: \(error?.localizedDescription ?? "No error info")")
        statusMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[PhomemoDriver] Disconnected from \(peripheral.name ?? "Unknown"). Error: \(error?.localizedDescription ?? "None")")
        stopHeartbeat()
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        statusMessage = "Disconnected. Retrying..."
        
        // Auto-restart scan on disconnect to keep searching
        print("[PhomemoDriver] Restarting scan after disconnect.")
        startScanning()
    }
}

extension PhomemoDriver: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[PhomemoDriver] Error discovering services: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        print("[PhomemoDriver] Discovered \(services.count) services. Looking for characteristics...")
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[PhomemoDriver] Error discovering characteristics for \(service.uuid): \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            print("[PhomemoDriver] Found characteristic: \(char.uuid)")
            if char.uuid == writeUUID {
                print("[PhomemoDriver] WRITE characteristic ready.")
                writeCharacteristic = char
                statusMessage = "Printer Ready"
            } else if char.uuid == notifyUUID {
                print("[PhomemoDriver] NOTIFY characteristic ready. Enabling notifications.")
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyUUID, let data = characteristic.value else { 
            if let error = error { print("[PhomemoDriver] Notify update error: \(error.localizedDescription)") }
            return 
        }
        
        let bytes = [UInt8](data)
        print("[PhomemoDriver] Received notification: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Handle status notifications (lid open, etc.)
        if bytes.count >= 3 && bytes[0] == 0x1A {
            let lidOpen = (bytes[2] & 0x01) != 0
            let paperPresent = (bytes[2] & 0x10) != 0
            
            if lidOpen {
                print("[PhomemoDriver] Status Warning: Lid open!")
                statusMessage = "Warning: Lid open!"
            } else if !paperPresent {
                print("[PhomemoDriver] Status Warning: No paper!")
                statusMessage = "Warning: No paper!"
            } else {
                print("[PhomemoDriver] Status OK: Paper and Lid normal.")
            }
        }
    }
    
    // MARK: - Heartbeat Logic
    
    private func startHeartbeat() {
        print("[PhomemoDriver] Starting heartbeat timer (\(heartbeatInterval)s)...")
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.connectedPeripheral != nil else { return }
            print("[PhomemoDriver] Sending heartbeat status check...")
            self.send(PhomemoCommands.CHECK_STATUS)
        }
    }
    
    private func stopHeartbeat() {
        print("[PhomemoDriver] Stopping heartbeat timer.")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}
