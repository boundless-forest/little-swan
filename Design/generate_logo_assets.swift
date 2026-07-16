#!/usr/bin/env swift

import AppKit
import Foundation

enum LogoAssetError: LocalizedError {
    case cannotLoadSVG(URL)
    case cannotCreateBitmap(Int)
    case cannotEncodePNG(URL)
    case cannotEncodeICNS(URL)

    var errorDescription: String? {
        switch self {
        case let .cannotLoadSVG(url):
            "Unable to load SVG source: \(url.path)"
        case let .cannotCreateBitmap(size):
            "Unable to create \(size)x\(size) bitmap"
        case let .cannotEncodePNG(url):
            "Unable to encode PNG: \(url.path)"
        case let .cannotEncodeICNS(url):
            "Unable to encode ICNS: \(url.path)"
        }
    }
}

let fileManager = FileManager.default
let designDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let appIconSource = designDirectory.appendingPathComponent("little-swan-icon.svg")
let menuBarSource = designDirectory.appendingPathComponent("little-swan-menubar-template.svg")
let appIconPNG = designDirectory.appendingPathComponent("little-swan-icon.png")
let menuBarPNG = designDirectory.appendingPathComponent("little-swan-menubar-template.png")
let appIconICNS = designDirectory.appendingPathComponent("LittleSwan.icns")

func renderSVG(at sourceURL: URL, pixelSize: Int) throws -> NSBitmapImageRep {
    guard let sourceImage = NSImage(contentsOf: sourceURL) else {
        throw LogoAssetError.cannotLoadSVG(sourceURL)
    }
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [.alphaFirst],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw LogoAssetError.cannotCreateBitmap(pixelSize)
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw LogoAssetError.cannotCreateBitmap(pixelSize)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func pngData(from sourceURL: URL, pixelSize: Int, destinationURL: URL) throws -> Data {
    let bitmap = try renderSVG(at: sourceURL, pixelSize: pixelSize)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw LogoAssetError.cannotEncodePNG(destinationURL)
    }
    return data
}

func writePNG(from sourceURL: URL, pixelSize: Int, to destinationURL: URL) throws {
    let data = try pngData(from: sourceURL, pixelSize: pixelSize, destinationURL: destinationURL)
    try data.write(to: destinationURL, options: .atomic)
}

func writeICNS(from sourceURL: URL, to destinationURL: URL) throws {
    // Modern ICNS files can store PNG payloads directly. Writing the chunk table
    // ourselves preserves every optical size, including 64 px and 1024 px reps
    // that CGImageDestination silently drops on newer macOS versions.
    let representations: [(type: String, pixels: Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("icp6", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic09", 512),
        ("ic10", 1024),
    ]

    var elements = Data()
    for representation in representations {
        guard let typeData = representation.type.data(using: .ascii), typeData.count == 4 else {
            throw LogoAssetError.cannotEncodeICNS(destinationURL)
        }
        let imageData = try pngData(
            from: sourceURL,
            pixelSize: representation.pixels,
            destinationURL: destinationURL
        )
        elements.append(typeData)
        appendBigEndian(UInt32(imageData.count + 8), to: &elements)
        elements.append(imageData)
    }

    var icns = Data("icns".utf8)
    appendBigEndian(UInt32(elements.count + 8), to: &icns)
    icns.append(elements)
    try icns.write(to: destinationURL, options: .atomic)
}

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

do {
    try writePNG(from: appIconSource, pixelSize: 1024, to: appIconPNG)
    try writePNG(from: menuBarSource, pixelSize: 1024, to: menuBarPNG)
    try writeICNS(from: appIconSource, to: appIconICNS)

    for output in [appIconPNG, menuBarPNG, appIconICNS] {
        let attributes = try fileManager.attributesOfItem(atPath: output.path)
        let byteCount = attributes[.size] as? NSNumber
        print("wrote \(output.path) (\(byteCount?.intValue ?? 0) bytes)")
    }
} catch {
    fputs("logo asset generation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
