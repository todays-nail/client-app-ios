#if DEBUG
import Foundation
import UIKit

enum PreviewFixtures {
    static func imageData(hue: CGFloat, size: CGSize = .init(width: 320, height: 320)) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let baseColor = UIColor(
                hue: hue.truncatingRemainder(dividingBy: 1),
                saturation: 0.36,
                brightness: 0.96,
                alpha: 1
            )
            let accentColor = UIColor(
                hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                saturation: 0.46,
                brightness: 0.82,
                alpha: 1
            )

            baseColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            accentColor.withAlphaComponent(0.32).setFill()
            let circleRect = CGRect(
                x: size.width * 0.14,
                y: size.height * 0.16,
                width: size.width * 0.72,
                height: size.height * 0.72
            )
            context.cgContext.fillEllipse(in: circleRect)

            UIColor.white.withAlphaComponent(0.72).setFill()
            let highlightRect = CGRect(
                x: size.width * 0.24,
                y: size.height * 0.18,
                width: size.width * 0.18,
                height: size.height * 0.42
            )
            context.cgContext.fillEllipse(in: highlightRect)
        }

        return image.jpegData(compressionQuality: 0.92)
    }

    static func imageURL(name: String, hue: CGFloat) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nailclient-preview-\(name)")
            .appendingPathExtension("jpg")

        guard let data = imageData(hue: hue) else { return nil }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? data.write(to: fileURL, options: .atomic)
        }
        return fileURL
    }
}
#endif
