// ios/Classes/ThumbnailExtractor.swift
import Foundation
import UIKit
import AVFoundation
import CoreGraphics

@objc public class ThumbnailExtractor: NSObject {
    private static let defaultThumbnailWidth: CGFloat = 160
    private static let defaultThumbnailHeight: CGFloat = 90
    
    private var thumbnailCache: [String: Data] = [:]
    private let cacheQueue = DispatchQueue(label: "thumbnail.cache.queue", attributes: .concurrent)
    private let extractionQueue = DispatchQueue(label: "thumbnail.extraction.queue", qos: .userInitiated)
    
    // MARK: - Public Methods
    
    @objc public func extractThumbnails(
        from videoURL: String,
        thumbnailCount: Int,
        quality: Float,
        width: CGFloat = defaultThumbnailWidth,
        height: CGFloat = defaultThumbnailHeight,
        completion: @escaping ([ThumbnailData]?, Error?) -> Void
    ) {
        extractionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let thumbnails: [ThumbnailData]
                
                if videoURL.contains(".m3u8") {
                    thumbnails = try self.extractHLSThumbnails(
                        from: videoURL,
                        thumbnailCount: thumbnailCount,
                        quality: quality,
                        width: width,
                        height: height
                    )
                } else {
                    thumbnails = try self.extractMP4Thumbnails(
                        from: videoURL,
                        thumbnailCount: thumbnailCount,
                        quality: quality,
                        width: width,
                        height: height
                    )
                }
                
                DispatchQueue.main.async {
                    completion(thumbnails, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    @objc public func getCachedThumbnail(for videoURL: String, at timeMs: Int64) -> Data? {
        return cacheQueue.sync {
            let cacheKey = "\(videoURL)_\(timeMs)"
            return thumbnailCache[cacheKey]
        }
    }
    
    @objc public func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.thumbnailCache.removeAll()
        }
    }
    
    // MARK: - Private Methods - MP4 Extraction
    
    private func extractMP4Thumbnails(
        from videoURL: String,
        thumbnailCount: Int,
        quality: Float,
        width: CGFloat,
        height: CGFloat
    ) throws -> [ThumbnailData] {
        
        guard let url = URL(string: videoURL) else {
            throw ThumbnailError.invalidURL
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // Configure image generator
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: width, height: height)
        imageGenerator.requestedTimeToleranceAfter = CMTime.zero
        imageGenerator.requestedTimeToleranceBefore = CMTime.zero
        
        // Get video duration
        let duration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CMTime, Error>) in
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                
                if status == .loaded {
                    continuation.resume(returning: asset.duration)
                } else {
                    continuation.resume(throwing: error ?? ThumbnailError.failedToLoadAsset)
                }
            }
        }
        
        guard duration.isValid && duration.value > 0 else {
            throw ThumbnailError.invalidDuration
        }
        
        let durationSeconds = CMTimeGetSeconds(duration)
        let intervalSeconds = durationSeconds / Double(thumbnailCount)
        
        var thumbnails: [ThumbnailData] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        // Generate time values for thumbnails
        var timeValues: [NSValue] = []
        for i in 0..<thumbnailCount {
            let timeSeconds = Double(i) * intervalSeconds
            let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)
            timeValues.append(NSValue(time: time))
        }
        
        var completedCount = 0
        let totalCount = timeValues.count
        
        // Generate thumbnails
        imageGenerator.generateCGImagesAsynchronously(forTimes: timeValues) { [weak self] (requestedTime, cgImage, actualTime, result, error) in
            defer {
                completedCount += 1
                if completedCount == totalCount {
                    semaphore.signal()
                }
            }
            
            guard let self = self,
                  let cgImage = cgImage,
                  result == .succeeded else {
                print("Failed to generate thumbnail at time \(CMTimeGetSeconds(requestedTime)): \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let uiImage = UIImage(cgImage: cgImage)
                let resizedImage = self.resizeImage(uiImage, to: CGSize(width: width, height: height))
                
                guard let imageData = resizedImage.jpegData(compressionQuality: CGFloat(quality / 100.0)) else {
                    print("Failed to convert image to JPEG data")
                    return
                }
                
                let timeMs = Int64(CMTimeGetSeconds(requestedTime) * 1000)
                let thumbnailData = ThumbnailData(
                    timePositionMs: timeMs,
                    imageData: imageData,
                    width: Int(resizedImage.size.width),
                    height: Int(resizedImage.size.height)
                )
                
                thumbnails.append(thumbnailData)
                
                // Cache thumbnail
                let cacheKey = "\(videoURL)_\(timeMs)"
                self.cacheQueue.async(flags: .barrier) {
                    self.thumbnailCache[cacheKey] = imageData
                }
                
            } catch {
                print("Error processing thumbnail: \(error)")
            }
        }
        
        semaphore.wait()
        
        // Sort thumbnails by time position
        thumbnails.sort { $0.timePositionMs < $1.timePositionMs }
        
        print("Extracted \(thumbnails.count) thumbnails from MP4")
        return thumbnails
    }
    
    // MARK: - Private Methods - HLS Extraction
    
    private func extractHLSThumbnails(
        from hlsURL: String,
        thumbnailCount: Int,
        quality: Float,
        width: CGFloat,
        height: CGFloat
    ) throws -> [ThumbnailData] {
        
        guard let url = URL(string: hlsURL) else {
            throw ThumbnailError.invalidURL
        }
        
        // For HLS, we need to parse the playlist and extract thumbnails from segments
        let playlistContent = try String(contentsOf: url)
        let segments = try parseHLSPlaylist(playlistContent, baseURL: url)
        
        guard !segments.isEmpty else {
            throw ThumbnailError.noSegmentsFound
        }
        
        var thumbnails: [ThumbnailData] = []
        
        // Calculate which segments to extract thumbnails from
        let totalDuration = segments.reduce(0) { $0 + $1.duration }
        let intervalDuration = totalDuration / Double(thumbnailCount)
        
        var currentTime = 0.0
        var thumbnailIndex = 0
        
        for segment in segments {
            // Check if we should extract thumbnail from this segment
            let segmentEndTime = currentTime + segment.duration
            let targetTime = Double(thumbnailIndex) * intervalDuration
            
            if targetTime >= currentTime && targetTime < segmentEndTime && thumbnailIndex < thumbnailCount {
                // Extract thumbnail from this segment
                let timeInSegment = targetTime - currentTime
                
                do {
                    if let thumbnailData = try extractThumbnailFromSegment(
                        segment: segment,
                        timeInSegment: timeInSegment,
                        quality: quality,
                        width: width,
                        height: height
                    ) {
                        let adjustedThumbnailData = ThumbnailData(
                            timePositionMs: Int64(targetTime * 1000),
                            imageData: thumbnailData.imageData,
                            width: thumbnailData.width,
                            height: thumbnailData.height
                        )
                        
                        thumbnails.append(adjustedThumbnailData)
                        
                        // Cache thumbnail
                        let cacheKey = "\(hlsURL)_\(Int64(targetTime * 1000))"
                        cacheQueue.async(flags: .barrier) { [weak self] in
                            self?.thumbnailCache[cacheKey] = thumbnailData.imageData
                        }
                    }
                    
                    thumbnailIndex += 1
                } catch {
                    print("Failed to extract thumbnail from segment \(segment.url): \(error)")
                }
            }
            
            currentTime = segmentEndTime
        }
        
        print("Extracted \(thumbnails.count) thumbnails from HLS")
        return thumbnails
    }
    
    private func parseHLSPlaylist(_ content: String, baseURL: URL) throws -> [HLSSegment] {
        let lines = content.components(separatedBy: .newlines)
        var segments: [HLSSegment] = []
        var currentDuration: Double = 0
        
        let baseURLString = baseURL.deletingLastPathComponent().absoluteString
        
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line.hasPrefix("#EXTINF:") {
                // Parse segment duration
                let durationString = String(line.dropFirst(8)).components(separatedBy: ",")[0]
                currentDuration = Double(durationString) ?? 0.0
            } else if !line.hasPrefix("#") && !line.isEmpty && currentDuration > 0 {
                // This is a segment URL
                let segmentURL: String
                if line.hasPrefix("http") {
                    segmentURL = line
                } else {
                    segmentURL = baseURLString + "/" + line
                }
                
                let segment = HLSSegment(url: segmentURL, duration: currentDuration)
                segments.append(segment)
                currentDuration = 0
            }
        }
        
        return segments
    }
    
    private func extractThumbnailFromSegment(
        segment: HLSSegment,
        timeInSegment: Double,
        quality: Float,
        width: CGFloat,
        height: CGFloat
    ) throws -> ThumbnailData? {
        
        guard let segmentURL = URL(string: segment.url) else {
            throw ThumbnailError.invalidURL
        }
        
        let asset = AVAsset(url: segmentURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: width, height: height)
        imageGenerator.requestedTimeToleranceAfter = CMTime.zero
        imageGenerator.requestedTimeToleranceBefore = CMTime.zero
        
        let time = CMTime(seconds: timeInSegment, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            let resizedImage = resizeImage(uiImage, to: CGSize(width: width, height: height))
            
            guard let imageData = resizedImage.jpegData(compressionQuality: CGFloat(quality / 100.0)) else {
                return nil
            }
            
            return ThumbnailData(
                timePositionMs: 0, // This will be adjusted by the caller
                imageData: imageData,
                width: Int(resizedImage.size.width),
                height: Int(resizedImage.size.height)
            )
        } catch {
            print("Failed to extract thumbnail from segment: \(error)")
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Supporting Data Structures

@objc public class ThumbnailData: NSObject {
    @objc public let timePositionMs: Int64
    @objc public let imageData: Data
    @objc public let width: Int
    @objc public let height: Int
    
    @objc public init(timePositionMs: Int64, imageData: Data, width: Int, height: Int) {
        self.timePositionMs = timePositionMs
        self.imageData = imageData
        self.width = width
        self.height = height
        super.init()
    }
}

private struct HLSSegment {
    let url: String
    let duration: Double
}

// MARK: - Error Types

enum ThumbnailError: Error, LocalizedError {
    case invalidURL
    case failedToLoadAsset
    case invalidDuration
    case noSegmentsFound
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid video URL"
        case .failedToLoadAsset:
            return "Failed to load video asset"
        case .invalidDuration:
            return "Invalid video duration"
        case .noSegmentsFound:
            return "No HLS segments found"
        case .extractionFailed:
            return "Thumbnail extraction failed"
        }
    }
}

// MARK: - Flutter Plugin Integration

@objc public class EnhancedBetterPlayerPlugin: NSObject, FlutterPlugin {
    private let thumbnailExtractor = ThumbnailExtractor()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "enhanced_better_player", binaryMessenger: registrar.messenger())
        let instance = EnhancedBetterPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "extractThumbnails":
            handleExtractThumbnails(call, result: result)
        case "getCachedThumbnail":
            handleGetCachedThumbnail(call, result: result)
        case "clearThumbnailCache":
            handleClearThumbnailCache(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleExtractThumbnails(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoURL = args["videoUrl"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let thumbnailCount = args["thumbnailCount"] as? Int ?? 50
        let quality = args["quality"] as? Float ?? 80.0
        let width = args["width"] as? CGFloat ?? ThumbnailExtractor.defaultThumbnailWidth
        let height = args["height"] as? CGFloat ?? ThumbnailExtractor.defaultThumbnailHeight
        
        thumbnailExtractor.extractThumbnails(
            from: videoURL,
            thumbnailCount: thumbnailCount,
            quality: quality,
            width: width,
            height: height
        ) { thumbnails, error in
            if let error = error {
                result(FlutterError(code: "EXTRACTION_ERROR", message: error.localizedDescription, details: nil))
            } else if let thumbnails = thumbnails {
                let thumbnailMaps = thumbnails.map { thumbnail in
                    return [
                        "timePositionMs": thumbnail.timePositionMs,
                        "imageData": FlutterStandardTypedData(bytes: thumbnail.imageData),
                        "width": thumbnail.width,
                        "height": thumbnail.height
                    ]
                }
                result(thumbnailMaps)
            } else {
                result([])
            }
        }
    }
    
    private func handleGetCachedThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoURL = args["videoUrl"] as? String,
              let timeMs = args["timeMs"] as? Int64 else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let cachedData = thumbnailExtractor.getCachedThumbnail(for: videoURL, at: timeMs)
        if let data = cachedData {
            result(FlutterStandardTypedData(bytes: data))
        } else {
            result(nil)
        }
    }
    
    private func handleClearThumbnailCache(result: @escaping FlutterResult) {
        thumbnailExtractor.clearCache()
        result(true)
    }
}