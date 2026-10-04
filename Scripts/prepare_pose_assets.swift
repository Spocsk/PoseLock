#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct PoseSource {
    let id: String
    let relativeStem: String
}

private enum Variant: String, CaseIterable {
    case plain
    case guided

    var sourceSuffix: String {
        switch self {
        case .plain: return "sans"
        case .guided: return "avec"
        }
    }
}

private let poses: [PoseSource] = [
    PoseSource(id: "quarterTurnFace", relativeStem: "Scene/01_Quarter_turn_face"),
    PoseSource(id: "quarterTurnProfile", relativeStem: "Scene/02_Quarter_turn_profil"),
    PoseSource(id: "quarterTurnBack", relativeStem: "Scene/03_Quarter_turn_dos"),
    PoseSource(id: "frontDoubleBiceps", relativeStem: "Scene/04_Front_double_biceps"),
    PoseSource(id: "frontLatSpread", relativeStem: "Scene/05_Front_lat_spread"),
    PoseSource(id: "sideChest", relativeStem: "Scene/06_Side_chest"),
    PoseSource(id: "backDoubleBiceps", relativeStem: "Scene/07_Back_double_biceps"),
    PoseSource(id: "backLatSpread", relativeStem: "Scene/08_Back_lat_spread"),
    PoseSource(id: "sideTriceps", relativeStem: "Scene/09_Side_triceps"),
    PoseSource(id: "absAndThigh", relativeStem: "Scene/10_Abs_and_thigh"),
    PoseSource(id: "mostMuscular", relativeStem: "Scene/11_Most_muscular"),
    PoseSource(id: "threeQuarterLat", relativeStem: "Contenu/01_3-4_lat"),
    PoseSource(id: "sideChestMirror", relativeStem: "Contenu/02_Side_chest_miroir"),
    PoseSource(id: "mostMuscularCrop", relativeStem: "Contenu/03_Most_muscular_crop"),
    PoseSource(id: "vacuum", relativeStem: "Contenu/04_Vacuum"),
    PoseSource(id: "backDoubleThreeQuarter", relativeStem: "Contenu/05_Back_double_3-4"),
    PoseSource(id: "handsOnHips", relativeStem: "Contenu/06_Hands_on_hips"),
    PoseSource(id: "frontPosture", relativeStem: "Physique/01_Posture_face"),
    PoseSource(id: "profilePosture", relativeStem: "Physique/02_Posture_profil"),
    PoseSource(id: "shoulderToWaist", relativeStem: "Physique/03_Shoulder_to_waist"),
    PoseSource(id: "clavicleOpen", relativeStem: "Physique/04_Ouverture_cage"),
    PoseSource(id: "shoulderSymmetry", relativeStem: "Physique/05_Symetrie_epaules"),
    PoseSource(id: "twistThreeQuarter", relativeStem: "Physique/06_Twist_3-4"),
    PoseSource(id: "zyzzClassic", relativeStem: "Zyzz/01_Pose_Zyzz"),
    PoseSource(id: "zyzzVacuum", relativeStem: "Zyzz/02_Vacuum_face"),
    PoseSource(id: "zyzzTwist", relativeStem: "Zyzz/03_Twist_esthetique")
]

private let outputWidth = 504
private let outputHeight = 896
private let bytesPerPixel = 4
private let lockGreen = (r: 140, g: 199, b: 148)

private enum PreparationError: Error, CustomStringConvertible {
    case usage
    case unreadableImage(URL)
    case cannotCreateContext
    case cannotCreateImage
    case cannotCreateDestination(URL)
    case cannotWriteImage(URL)

    var description: String {
        switch self {
        case .usage:
            return "Usage: swift Scripts/prepare_pose_assets.swift <PoseLock_Poses> <Assets.xcassets>"
        case .unreadableImage(let url):
            return "Image illisible : \(url.path)"
        case .cannotCreateContext:
            return "Impossible de créer le contexte Core Graphics"
        case .cannotCreateImage:
            return "Impossible de créer l’image PNG"
        case .cannotCreateDestination(let url):
            return "Impossible de créer la destination : \(url.path)"
        case .cannotWriteImage(let url):
            return "Impossible d’écrire : \(url.path)"
        }
    }
}

private func loadImage(at url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw PreparationError.unreadableImage(url)
    }
    return image
}

private func resizedPixels(from image: CGImage) throws -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: outputWidth * outputHeight * bytesPerPixel)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue

    let created = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: outputWidth * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        return true
    }

    guard created else { throw PreparationError.cannotCreateContext }
    return pixels
}

private func medianBackgroundColor(in pixels: [UInt8]) -> (r: Int, g: Int, b: Int) {
    let sampleDepth = 24
    var reds: [UInt8] = []
    var greens: [UInt8] = []
    var blues: [UInt8] = []

    func sample(_ x: Int, _ y: Int) {
        let offset = (y * outputWidth + x) * bytesPerPixel
        reds.append(pixels[offset])
        greens.append(pixels[offset + 1])
        blues.append(pixels[offset + 2])
    }

    for y in 0..<outputHeight {
        for x in 0..<sampleDepth {
            sample(x, y)
            sample(outputWidth - 1 - x, y)
        }
    }
    for x in sampleDepth..<(outputWidth - sampleDepth) {
        for y in 0..<sampleDepth {
            sample(x, y)
            sample(x, outputHeight - 1 - y)
        }
    }

    reds.sort()
    greens.sort()
    blues.sort()
    let middle = reds.count / 2
    return (Int(reds[middle]), Int(greens[middle]), Int(blues[middle]))
}

private func removeBorderConnectedBackground(from pixels: inout [UInt8]) {
    let background = medianBackgroundColor(in: pixels)
    let pixelCount = outputWidth * outputHeight
    var connected = [Bool](repeating: false, count: pixelCount)
    var queue = [Int](repeating: 0, count: pixelCount)
    var head = 0
    var tail = 0

    func isBackgroundCandidate(_ index: Int) -> Bool {
        let offset = index * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let distance = max(abs(red - background.r), abs(green - background.g), abs(blue - background.b))
        return distance <= 28 && max(red, green, blue) <= 36
    }

    func enqueue(_ index: Int) {
        guard !connected[index], isBackgroundCandidate(index) else { return }
        connected[index] = true
        queue[tail] = index
        tail += 1
    }

    for x in 0..<outputWidth {
        enqueue(x)
        enqueue((outputHeight - 1) * outputWidth + x)
    }
    for y in 0..<outputHeight {
        enqueue(y * outputWidth)
        enqueue(y * outputWidth + outputWidth - 1)
    }

    while head < tail {
        let index = queue[head]
        head += 1
        let x = index % outputWidth
        let y = index / outputWidth
        if x > 0 { enqueue(index - 1) }
        if x + 1 < outputWidth { enqueue(index + 1) }
        if y > 0 { enqueue(index - outputWidth) }
        if y + 1 < outputHeight { enqueue(index + outputWidth) }
    }

    for index in 0..<pixelCount where connected[index] {
        let offset = index * bytesPerPixel
        let distance = max(
            abs(Int(pixels[offset]) - background.r),
            abs(Int(pixels[offset + 1]) - background.g),
            abs(Int(pixels[offset + 2]) - background.b)
        )
        let alpha: Int
        if distance <= 6 {
            alpha = 0
        } else {
            alpha = min(255, (distance - 6) * 255 / 22)
        }
        pixels[offset] = UInt8(Int(pixels[offset]) * alpha / 255)
        pixels[offset + 1] = UInt8(Int(pixels[offset + 1]) * alpha / 255)
        pixels[offset + 2] = UInt8(Int(pixels[offset + 2]) * alpha / 255)
        pixels[offset + 3] = UInt8(alpha)
    }
}

private func harmonizeGuidedGreen(in pixels: inout [UInt8]) {
    for index in 0..<(outputWidth * outputHeight) {
        let offset = index * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let dominance = green - max(red, blue)
        guard green >= 60, dominance > 20 else { continue }

        let weight = min(1.0, Double(dominance - 20) / 70.0)
        func blend(_ original: Int, _ target: Int) -> UInt8 {
            UInt8((Double(original) * (1 - weight) + Double(target) * weight).rounded())
        }
        pixels[offset] = blend(red, lockGreen.r)
        pixels[offset + 1] = blend(green, lockGreen.g)
        pixels[offset + 2] = blend(blue, lockGreen.b)
    }
}

private func writePNG(pixels: [UInt8], to url: URL) throws {
    let data = Data(pixels)
    guard let provider = CGDataProvider(data: data as CFData),
          let image = CGImage(
              width: outputWidth,
              height: outputHeight,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: outputWidth * bytesPerPixel,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGBitmapInfo(
                  rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                      | CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              provider: provider,
              decode: nil,
              shouldInterpolate: true,
              intent: .defaultIntent
          ) else {
        throw PreparationError.cannotCreateImage
    }
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw PreparationError.cannotCreateDestination(url)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw PreparationError.cannotWriteImage(url)
    }
}

private func writeImageSet(
    pose: PoseSource,
    variant: Variant,
    sourceRoot: URL,
    assetCatalog: URL
) throws {
    let assetName = "pose_\(pose.id)_\(variant.rawValue)"
    let sourceURL = sourceRoot
        .appendingPathComponent("\(pose.relativeStem)_\(variant.sourceSuffix).jpg")
    let imageSetURL = assetCatalog.appendingPathComponent("\(assetName).imageset")
    let imageURL = imageSetURL.appendingPathComponent("\(assetName).png")
    let fileManager = FileManager.default

    try fileManager.createDirectory(at: imageSetURL, withIntermediateDirectories: true)
    var pixels = try resizedPixels(from: loadImage(at: sourceURL))
    removeBorderConnectedBackground(from: &pixels)
    if variant == .guided {
        harmonizeGuidedGreen(in: &pixels)
    }
    try writePNG(pixels: pixels, to: imageURL)

    let contents: [String: Any] = [
        "images": [[
            "filename": imageURL.lastPathComponent,
            "idiom": "universal"
        ]],
        "info": [
            "author": "xcode",
            "version": 1
        ]
    ]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: imageSetURL.appendingPathComponent("Contents.json"), options: .atomic)
    print("✓ \(assetName)")
}

do {
    guard CommandLine.arguments.count == 3 else { throw PreparationError.usage }
    let sourceRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let assetCatalog = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)

    for pose in poses {
        for variant in Variant.allCases {
            try writeImageSet(
                pose: pose,
                variant: variant,
                sourceRoot: sourceRoot,
                assetCatalog: assetCatalog
            )
        }
    }
    print("\n\(poses.count * Variant.allCases.count) assets préparés localement.")
} catch {
    fputs("Erreur : \(error)\n", stderr)
    exit(1)
}
