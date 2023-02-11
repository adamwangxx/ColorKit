//
//  DominantColors.swift
//  ColorKit
//
//  Created by Boris Emorine on 5/19/20.
//  Copyright © 2020 BorisEmorine. All rights reserved.
//

import UIKit
import CoreImage

extension UIImage {
    
    public enum DominantColorAlgorithm {
        /// Finds the dominant colors of an image by using median cut algorithm.
        case medianCut
        /// Finds the dominant colors of an image by using using a k-means clustering algorithm. Supported since iOS 14.0
        case kMeansClustering
    }
    
    /// Reoresents how precise the dominant color algorithm should be.
    /// The lower the quality, the faster the algorithm.
    /// `.best` should only be reserved for very small images.
    public enum DominantColorQuality {
        case low
        case fair
        case high
        case best
        
        var prefferedImageArea: CGFloat? {
            switch self {
            case .low:
                return 1_000
            case .fair:
                return 10_000
            case .high:
                return 100_000
            case .best:
                return nil
            }
        }
        
        var kMeansInputPasses: Int {
            switch self {
            case .low:
                return 1
            case .fair:
                return 10
            case .high:
                return 15
            case .best:
                return 20
            }
        }
        
        /// Returns a new size (with the same aspect ratio) that takes into account the quality to match.
        /// For example with a `.low` quality, the returned size will be much smaller.
        /// On the opposite, with a `.best` quality, the returned size will be identical to the original size.
        func targetSize(for originalSize: CGSize) -> CGSize {
            guard let prefferedImageArea = prefferedImageArea else {
                return originalSize
            }
            
            let originalArea = originalSize.area
            
            guard originalArea > prefferedImageArea else {
                return originalSize
            }
            
            return originalSize.transformToFit(in: prefferedImageArea)
        }
    }
    
    /// Attempts to computes the dominant colors of the image.
    /// This is not the absolute dominent colors, but instead colors that are similar are groupped together.
    /// This avoids having to deal with many shades of the same colors, which are frequent when dealing with compression artifacts (jpeg etc.).
    /// - Parameters:
    ///   - quality: The quality used to determine the dominant colors. A higher quality will yield more accurate results, but will be slower.
    ///   - algorithm: The algorithm used to determine the dominant colors. When using a k-means algorithm (`kMeansClustering`), a `CIKMeans` CIFilter isused. Unfortunately this filter doesn't work on the simulator.
    /// - Returns: The dominant colors as array of `UIColor` instances. When using the `.iterative` algorithm, this array is ordered where the first color is the most dominant one.
        //TODO: - [Adam] - 这里要将quality 统一，传入colorCount
    public func dominantColors(with quality: DominantColorQuality = .fair, algorithm: DominantColorAlgorithm = .medianCut) throws -> [UIColor] {
        switch algorithm {
        case .kMeansClustering:
            let dominantcolors = try kMeansClustering(with: quality)
            return dominantcolors
        case .medianCut:
            guard let colorPalette = ColorThief.getPalette(from: self, colorCount: 5, quality: ColorThief.defaultQuality, ignoreWhite: false) else {
                throw ImageColorError.medianCutFailure
            }
            var result = [UIColor]()
            for color in colorPalette {
                result.append(color.makeUIColor())
            }
            return result
        }
    }
    
    private func kMeansClustering(with quality: DominantColorQuality) throws -> [UIColor] {
        guard let ciImage = CIImage(image: self) else {
            throw ImageColorError.ciImageFailure
        }
        let kMeansFilter = CIFilter(name: "CIKMeans")!
        
        let clusterCount = 8

        kMeansFilter.setValue(ciImage, forKey: kCIInputImageKey)
        kMeansFilter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
        kMeansFilter.setValue(clusterCount, forKey: "inputCount")
        kMeansFilter.setValue(quality.kMeansInputPasses, forKey: "inputPasses")
        kMeansFilter.setValue(NSNumber(value: true), forKey: "inputPerceptual")

        guard var outputImage = kMeansFilter.outputImage else {
            throw ImageColorError.outputImageFailure
        }
        
        outputImage = outputImage.settingAlphaOne(in: outputImage.extent)
        
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4 * clusterCount)
        
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4 * clusterCount, bounds: outputImage.extent, format: CIFormat.RGBA8, colorSpace: ciImage.colorSpace!)
        
        var dominantColors = [UIColor]()

        for i in 0..<clusterCount {
            let color = UIColor(red: CGFloat(bitmap[i * 4 + 0]) / 255.0, green: CGFloat(bitmap[i * 4 + 1]) / 255.0, blue: CGFloat(bitmap[i * 4 + 2]) / 255.0, alpha: CGFloat(bitmap[i * 4 + 3]) / 255.0)
            dominantColors.append(color)
        }
        
        return dominantColors
    }
    
}
