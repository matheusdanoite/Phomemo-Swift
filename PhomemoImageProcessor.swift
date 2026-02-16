import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Accelerate

enum DitheringAlgorithm: String, CaseIterable, Identifiable {
    case threshold = "Limiarização"
    case floydSteinberg = "Floyd-Steinberg"
    case halftone = "Halftone"
    
    var id: String { self.rawValue }
}

class PhomemoImageProcessor {
    nonisolated static let printerWidth = 384
    nonisolated static let bytesPerRow = printerWidth / 8
    
    nonisolated private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])
    
    /// Converts a UIImage to a list of ESC/POS raster chunks
    nonisolated static func convertToRasterChunks(image: UIImage, algorithm: DitheringAlgorithm = .floydSteinberg, intensity: Float = 0.5, mirror: Bool = false, rotate: Bool = false, chunkHeight: Int = 100) -> [[UInt8]] {
        // 1. Resize and apply contrast/brightness/rotation adjustment
        guard let prepared = prepareImage(image, intensity: intensity, mirror: mirror, rotate: rotate) else { return [] }
        
        // 2. Process to 1-bit bits
        guard let pixelData = convertTo1Bit(prepared, algorithm: algorithm, intensity: intensity) else { return [] }
        
        return chunkBits(pixelData, height: Int(prepared.size.height), chunkHeight: chunkHeight)
    }
    
    /// Bypasses all filtering and dithering. Uses the image exactly as provided.
    /// Expects image to be already dithered (0/255) and 384px wide.
    nonisolated static func convertToRasterChunksSimple(image: UIImage, chunkHeight: Int = 100) -> [[UInt8]] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Extract bits directly without any CI filtering
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        
        var sourceBuffer = vImage_Buffer()
        defer { free(sourceBuffer.data) }
        vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        
        // Invert (Black=255 -> 1)
        let map = (0...255).map { UInt8(255 - $0) }
        vImageTableLookUp_Planar8(&sourceBuffer, &sourceBuffer, map, vImage_Flags(kvImageNoFlags))
        
        let width = Int(sourceBuffer.width)
        let height = Int(sourceBuffer.height)
        let destinationBytesPerRow = (width + 7) / 8
        var destinationData = [UInt8](repeating: 0, count: destinationBytesPerRow * height)
        
        // Use withUnsafeMutableBufferPointer to safely initialize destinationBuffer
        destinationData.withUnsafeMutableBufferPointer { buffer in
            var destinationBuffer = vImage_Buffer(
                data: buffer.baseAddress,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: destinationBytesPerRow
            )
            // Just convert to 1-bit with simple threshold (since it's already dithered to 0/255)
            vImageConvert_Planar8toPlanar1(&sourceBuffer, &destinationBuffer, nil, Int32(kvImageConvert_DitherNone), vImage_Flags(kvImageNoFlags))
        }
        
        return chunkBits(destinationData, height: height, chunkHeight: chunkHeight)
    }
    
    nonisolated private static func chunkBits(_ pixelData: [UInt8], height: Int, chunkHeight: Int) -> [[UInt8]] {
        var chunks: [[UInt8]] = []
        for y in stride(from: 0, to: height, by: chunkHeight) {
            let h = min(chunkHeight, height - y)
            let startByte = y * bytesPerRow
            let endByte = (y + h) * bytesPerRow
            let chunkData = Array(pixelData[startByte..<endByte])
            
            let header = PhomemoCommands.rasterImageHeader(widthBytes: bytesPerRow, height: h)
            chunks.append(header + chunkData)
        }
        return chunks
    }
    
    /// Generates a preview UIImage showing the dithering result
    nonisolated static func processForPreview(image: UIImage, algorithm: DitheringAlgorithm, intensity: Float, mirror: Bool = false) -> UIImage? {
        // Preview never rotates for printing layout, it shows the image 'as is' (maybe scaled to width)
        // User said: "Imagens em formato paisagem devem ser exibidas neste mesmo formato no preview"
        // So we strictly pass rotate: false here.
        guard let prepared = prepareImage(image, intensity: intensity, mirror: mirror, rotate: false) else { return nil }
        
        // 2. Convert to definitive 1-bit bits
        guard let bits = convertTo1Bit(prepared, algorithm: algorithm, intensity: intensity) else { return nil }
        
        // 3. Reconstruct image from the EXACT same bits that would be printed
        return imageFrom1Bit(bits, size: prepared.size)
    }

    nonisolated private static func applyCIHalftone(image: CIImage, intensity: Float) -> UIImage? {
        let filter = CIFilter.dotScreen()
        filter.inputImage = image
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        filter.angle = 1.1
        filter.width = 2.0 + (1.0 - intensity) * 4.0
        filter.sharpness = 0.7
        
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: image.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }

    nonisolated private static func convertTo1Bit(_ image: UIImage, algorithm: DitheringAlgorithm, intensity: Float) -> [UInt8]? {
        var inputImage = image
        
        if algorithm == .halftone {
            if let ciInput = CIImage(image: image),
               let halftone = applyCIHalftone(image: ciInput, intensity: intensity) {
                inputImage = halftone
            }
        }
        
        guard let cgImage = inputImage.cgImage else { return nil }
        
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8, bitsPerPixel: 8,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            version: 0, decode: nil, renderingIntent: .defaultIntent
        )
        
        var sourceBuffer = vImage_Buffer()
        defer { free(sourceBuffer.data) }
        vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        
        let map = (0...255).map { UInt8(255 - $0) }
        vImageTableLookUp_Planar8(&sourceBuffer, &sourceBuffer, map, vImage_Flags(kvImageNoFlags))
        
        let width = Int(sourceBuffer.width)
        let height = Int(sourceBuffer.height)
        let destinationBytesPerRow = (width + 7) / 8
        var destinationData = [UInt8](repeating: 0, count: destinationBytesPerRow * height)
        
        destinationData.withUnsafeMutableBufferPointer { buffer in
            var destinationBuffer = vImage_Buffer(
                data: buffer.baseAddress,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: destinationBytesPerRow
            )
            
            switch algorithm {
            case .threshold:
                let thresholdValue = UInt8((1.0 - intensity) * 255.0)
                let thresholdMap = (0...255).map { UInt8($0 >= thresholdValue ? 255 : 0) }
                vImageTableLookUp_Planar8(&sourceBuffer, &sourceBuffer, thresholdMap, vImage_Flags(kvImageNoFlags))
                vImageConvert_Planar8toPlanar1(&sourceBuffer, &destinationBuffer, nil, Int32(kvImageConvert_DitherNone), vImage_Flags(kvImageNoFlags))
            case .floydSteinberg:
                vImageConvert_Planar8toPlanar1(&sourceBuffer, &destinationBuffer, nil, Int32(kvImageConvert_DitherFloydSteinberg), vImage_Flags(kvImageNoFlags))
            case .halftone:
                vImageConvert_Planar8toPlanar1(&sourceBuffer, &destinationBuffer, nil, Int32(kvImageConvert_DitherNone), vImage_Flags(kvImageNoFlags))
            }
        }
        
        return destinationData
    }

    nonisolated static func prepareImage(_ image: UIImage, intensity: Float = 0.5, mirror: Bool = false, rotate: Bool = false) -> UIImage? {
        // Ensure image is upright (fixes orientation issues where portrait photos appear rotated)
        var inputImage = image
        if inputImage.imageOrientation != .up {
            UIGraphicsBeginImageContextWithOptions(inputImage.size, false, inputImage.scale)
            inputImage.draw(in: CGRect(origin: .zero, size: inputImage.size))
            let normalized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let normalized = normalized {
                inputImage = normalized
            }
        }
        
        guard var ciImage = CIImage(image: inputImage) else { return nil }
        
        // Apply rotation first if needed
        if rotate {
            // Rotate 90 degrees (landscape to portrait).
            // .right means 90 degrees clockwise.
            // .left means 90 degrees counter-clockwise.
            // We want to turn a landscape image onto the paper strip.
            // Paper strip flows vertically.
            // So width of image becomes height of print.
            ciImage = ciImage.oriented(.right)
        }
        
        if mirror {
            ciImage = ciImage.oriented(.upMirrored)
        }
        
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 0.5 + intensity
        filter.brightness = (0.5 - intensity) * 0.4
        filter.saturation = 0.0
        
        guard let grayscale = filter.outputImage else { return nil }
        
        let currentWidth = grayscale.extent.width
        if abs(currentWidth - CGFloat(printerWidth)) > 0.01 {
            let scale = CGFloat(printerWidth) / currentWidth
            let scaledImage = grayscale.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
            return UIImage(cgImage: cgImage)
        } else {
            guard let cgImage = context.createCGImage(grayscale, from: grayscale.extent) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
    
    nonisolated private static func imageFrom1Bit(_ data: [UInt8], size: CGSize) -> UIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        var grayData = Data(count: width * height)
        grayData.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let grayBase = ptr.bindMemory(to: UInt8.self).baseAddress!
            let bytesPerRow = (width + 7) / 8
            for y in 0..<height {
                for x in 0..<width {
                    let byteIdx = y * bytesPerRow + (x / 8)
                    let bitIdx = 7 - (x % 8)
                    let isBlack = (data[byteIdx] & (1 << bitIdx)) != 0
                    grayBase[y * width + x] = isBlack ? 0 : 255
                }
            }
        }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let dataProvider = CGDataProvider(data: grayData as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
