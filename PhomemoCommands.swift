import Foundation

struct PhomemoCommands {
    /// Initialize printer
    static let INIT_PRINTER: [UInt8] = [0x1B, 0x40]
    
    /// Check printer status (lid, paper)
    static let CHECK_STATUS: [UInt8] = [0x1D, 0x67, 0x6E]
    
    /// Feed lines (n lines)
    static func feedLines(_ n: UInt8) -> [UInt8] {
        return [0x1B, 0x64, n]
    }
    
    /// Header for GS v 0 raster image format
    /// - Parameters:
    ///   - widthBytes: Width in bytes (dots / 8)
    ///   - height: Height in dots
    nonisolated static func rasterImageHeader(widthBytes: Int, height: Int) -> [UInt8] {
        let xL = UInt8(widthBytes & 0xFF)
        let xH = UInt8((widthBytes >> 8) & 0xFF)
        let yL = UInt8(height & 0xFF)
        let yH = UInt8((height >> 8) & 0xFF)
        
        // GS v 0 0 xL xH yL yH
        return [0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]
    }
    
    // UUIDs for Phomemo T02
    static let SERVICE_UUID = "FF00" // Common base for these devices
    static let WRITE_CHARACTERISTIC_UUID = "0000ff02-0000-1000-8000-00805f9b34fb"
    static let NOTIFY_CHARACTERISTIC_UUID = "0000ff03-0000-1000-8000-00805f9b34fb"
    
    static let PRINTER_WIDTH_DOTS = 384
}
