// android/src/main/kotlin/com/enhanced/better_player/ThumbnailExtractor.kt
package com.enhanced.better_player

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.util.Log
import androidx.annotation.NonNull
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.source.hls.HlsMediaSource
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min

class ThumbnailExtractor(private val context: Context) {
    companion object {
        private const val TAG = "ThumbnailExtractor"
        private const val DEFAULT_THUMBNAIL_WIDTH = 160
        private const val DEFAULT_THUMBNAIL_HEIGHT = 90
    }

    private val thumbnailCache = ConcurrentHashMap<String, ByteArray>()
    private val extractorScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /**
     * Extract thumbnails from video source (MP4 or HLS)
     */
    suspend fun extractThumbnails(
        videoUrl: String,
        thumbnailCount: Int,
        quality: Int,
        width: Int = DEFAULT_THUMBNAIL_WIDTH,
        height: Int = DEFAULT_THUMBNAIL_HEIGHT
    ): List<ThumbnailData> = withContext(Dispatchers.IO) {
        
        return@withContext try {
            when {
                videoUrl.contains(".m3u8") -> extractHlsThumbnails(
                    videoUrl, thumbnailCount, quality, width, height
                )
                else -> extractMp4Thumbnails(
                    videoUrl, thumbnailCount, quality, width, height
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting thumbnails: ${e.message}", e)
            emptyList()
        }
    }

    /**
     * Extract thumbnails from MP4 video
     */
    private suspend fun extractMp4Thumbnails(
        videoUrl: String,
        thumbnailCount: Int,
        quality: Int,
        width: Int,
        height: Int
    ): List<ThumbnailData> = withContext(Dispatchers.IO) {
        
        val thumbnails = mutableListOf<ThumbnailData>()
        val retriever = MediaMetadataRetriever()
        
        try {
            // Setup retriever for network or local file
            if (videoUrl.startsWith("http")) {
                retriever.setDataSource(videoUrl, HashMap())
            } else {
                retriever.setDataSource(videoUrl)
            }
            
            // Get video duration
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val duration = durationStr?.toLongOrNull() ?: 0L
            
            if (duration <= 0) {
                Log.w(TAG, "Invalid video duration: $duration")
                return@withContext emptyList()
            }
            
            // Calculate time intervals
            val intervalMs = duration / thumbnailCount.toLong()
            
            // Extract thumbnails at intervals
            for (i in 0 until thumbnailCount) {
                try {
                    val timeUs = (i * intervalMs) * 1000 // Convert to microseconds
                    val bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    
                    bitmap?.let { originalBitmap ->
                        // Resize bitmap
                        val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, width, height, true)
                        
                        // Convert to byte array
                        val byteArrayOutputStream = ByteArrayOutputStream()
                        val compressFormat = Bitmap.CompressFormat.JPEG
                        scaledBitmap.compress(compressFormat, quality, byteArrayOutputStream)
                        val imageData = byteArrayOutputStream.toByteArray()
                        
                        // Create thumbnail data
                        val thumbnailData = ThumbnailData(
                            timePositionMs = i * intervalMs,
                            imageData = imageData,
                            width = scaledBitmap.width,
                            height = scaledBitmap.height
                        )
                        
                        thumbnails.add(thumbnailData)
                        
                        // Cache thumbnail
                        val cacheKey = "${videoUrl}_${i * intervalMs}"
                        thumbnailCache[cacheKey] = imageData
                        
                        // Clean up bitmaps
                        if (scaledBitmap != originalBitmap) {
                            scaledBitmap.recycle()
                        }
                        originalBitmap.recycle()
                        byteArrayOutputStream.close()
                    }
                    
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to extract thumbnail at position $i: ${e.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up MediaMetadataRetriever: ${e.message}", e)
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing MediaMetadataRetriever: ${e.message}")
            }
        }
        
        Log.i(TAG, "Extracted ${thumbnails.size} thumbnails from MP4")
        return@withContext thumbnails
    }

    /**
     * Extract thumbnails from HLS stream
     */
    private suspend fun extractHlsThumbnails(
        hlsUrl: String,
        thumbnailCount: Int,
        quality: Int,
        width: Int,
        height: Int
    ): List<ThumbnailData> = withContext(Dispatchers.IO) {
        
        val thumbnails = mutableListOf<ThumbnailData>()
        var exoPlayer: ExoPlayer? = null
        
        try {
            // Create ExoPlayer instance
            exoPlayer = ExoPlayer.Builder(context).build()
            
            // Setup HLS media source
            val dataSourceFactory = DefaultHttpDataSource.Factory()
            val hlsMediaSource = HlsMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(hlsUrl))
            
            // Set media source and prepare
            exoPlayer.setMediaSource(hlsMediaSource)
            exoPlayer.prepare()
            
            // Wait for player to be ready
            var isReady = false
            var attempts = 0
            val maxAttempts = 100 // 10 seconds timeout
            
            while (!isReady && attempts < maxAttempts) {
                delay(100)
                isReady = exoPlayer.playbackState != ExoPlayer.STATE_BUFFERING
                attempts++
            }
            
            if (!isReady) {
                Log.w(TAG, "ExoPlayer failed to prepare HLS stream")
                return@withContext emptyList()
            }
            
            // Get duration
            val duration = exoPlayer.duration
            if (duration <= 0) {
                Log.w(TAG, "Invalid HLS duration: $duration")
                return@withContext emptyList()
            }
            
            // Calculate intervals and extract thumbnails
            val intervalMs = duration / thumbnailCount.toLong()
            
            for (i in 0 until thumbnailCount) {
                try {
                    val positionMs = i * intervalMs
                    
                    // Seek to position
                    exoPlayer.seekTo(positionMs)
                    
                    // Wait for seek to complete
                    delay(200) // Allow time for seek and frame extraction
                    
                    // For HLS, we need to use a different approach since ExoPlayer
                    // doesn't directly provide frame extraction. We'll use the 
                    // VideoProcessor or extract using MediaMetadataRetriever with segments
                    val segmentUrl = getHlsSegmentAtTime(hlsUrl, positionMs)
                    
                    if (segmentUrl != null) {
                        val bitmap = extractFrameFromSegment(segmentUrl, positionMs % 10000) // Position within segment
                        
                        bitmap?.let { originalBitmap ->
                            val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, width, height, true)
                            
                            val byteArrayOutputStream = ByteArrayOutputStream()
                            scaledBitmap.compress(Bitmap.CompressFormat.JPEG, quality, byteArrayOutputStream)
                            val imageData = byteArrayOutputStream.toByteArray()
                            
                            val thumbnailData = ThumbnailData(
                                timePositionMs = positionMs,
                                imageData = imageData,
                                width = scaledBitmap.width,
                                height = scaledBitmap.height
                            )
                            
                            thumbnails.add(thumbnailData)
                            
                            // Cache thumbnail
                            val cacheKey = "${hlsUrl}_$positionMs"
                            thumbnailCache[cacheKey] = imageData
                            
                            // Clean up
                            if (scaledBitmap != originalBitmap) {
                                scaledBitmap.recycle()
                            }
                            originalBitmap.recycle()
                            byteArrayOutputStream.close()
                        }
                    }
                    
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to extract HLS thumbnail at position $i: ${e.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting HLS thumbnails: ${e.message}", e)
        } finally {
            exoPlayer?.release()
        }
        
        Log.i(TAG, "Extracted ${thumbnails.size} thumbnails from HLS")
        return@withContext thumbnails
    }

    /**
     * Parse HLS playlist and get segment URL for specific time
     */
    private suspend fun getHlsSegmentAtTime(hlsUrl: String, timeMs: Long): String? = withContext(Dispatchers.IO) {
        try {
            val playlistContent = URL(hlsUrl).readText()
            val lines = playlistContent.split("\n")
            
            var currentTime = 0L
            var baseUrl = hlsUrl.substringBeforeLast("/") + "/"
            
            for (i in lines.indices) {
                val line = lines[i].trim()
                
                if (line.startsWith("#EXTINF:")) {
                    // Parse segment duration
                    val durationStr = line.substring(8).split(",")[0]
                    val segmentDuration = (durationStr.toDoubleOrNull() ?: 0.0) * 1000 // Convert to ms
                    
                    // Check if this segment contains our target time
                    if (timeMs >= currentTime && timeMs < currentTime + segmentDuration) {
                        // Next line should be the segment URL
                        if (i + 1 < lines.size) {
                            val segmentUrl = lines[i + 1].trim()
                            return@withContext if (segmentUrl.startsWith("http")) {
                                segmentUrl
                            } else {
                                baseUrl + segmentUrl
                            }
                        }
                    }
                    
                    currentTime += segmentDuration.toLong()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error parsing HLS playlist: ${e.message}")
        }
        
        return@withContext null
    }

    /**
     * Extract frame from HLS segment
     */
    private suspend fun extractFrameFromSegment(segmentUrl: String, positionMs: Long): Bitmap? = withContext(Dispatchers.IO) {
        val retriever = MediaMetadataRetriever()
        
        return@withContext try {
            retriever.setDataSource(segmentUrl, HashMap())
            val timeUs = positionMs * 1000 // Convert to microseconds
            retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } catch (e: Exception) {
            Log.w(TAG, "Error extracting frame from segment: ${e.message}")
            null
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing retriever: ${e.message}")
            }
        }
    }

    /**
     * Get cached thumbnail
     */
    fun getCachedThumbnail(videoUrl: String, timeMs: Long): ByteArray? {
        val cacheKey = "${videoUrl}_$timeMs"
        return thumbnailCache[cacheKey]
    }

    /**
     * Clear thumbnail cache
     */
    fun clearCache() {
        thumbnailCache.clear()
    }

    /**
     * Clean up resources
     */
    fun dispose() {
        clearCache()
        extractorScope.cancel()
    }
}

/**
 * Data class for thumbnail information
 */
data class ThumbnailData(
    val timePositionMs: Long,
    val imageData: ByteArray,
    val width: Int,
    val height: Int
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as ThumbnailData

        if (timePositionMs != other.timePositionMs) return false
        if (!imageData.contentEquals(other.imageData)) return false
        if (width != other.width) return false
        if (height != other.height) return false

        return true
    }

    override fun hashCode(): Int {
        var result = timePositionMs.hashCode()
        result = 31 * result + imageData.contentHashCode()
        result = 31 * result + width
        result = 31 * result + height
        return result
    }
}

// Enhanced Better Player Plugin with thumbnail support
class EnhancedBetterPlayerPlugin : MethodChannel.MethodCallHandler {
    private var thumbnailExtractor: ThumbnailExtractor? = null
    
    fun initializeWith(context: Context) {
        thumbnailExtractor = ThumbnailExtractor(context)
    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "extractThumbnails" -> {
                val videoUrl = call.argument<String>("videoUrl") ?: ""
                val thumbnailCount = call.argument<Int>("thumbnailCount") ?: 50
                val quality = call.argument<Int>("quality") ?: 80
                val width = call.argument<Int>("width") ?: 160
                val height = call.argument<Int>("height") ?: 90
                
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        val thumbnails = thumbnailExtractor?.extractThumbnails(
                            videoUrl, thumbnailCount, quality, width, height
                        ) ?: emptyList()
                        
                        val thumbnailMaps = thumbnails.map { thumbnail ->
                            mapOf(
                                "timePositionMs" to thumbnail.timePositionMs,
                                "imageData" to thumbnail.imageData,
                                "width" to thumbnail.width,
                                "height" to thumbnail.height
                            )
                        }
                        
                        result.success(thumbnailMaps)
                    } catch (e: Exception) {
                        result.error("EXTRACTION_ERROR", e.message, null)
                    }
                }
            }
            
            "getCachedThumbnail" -> {
                val videoUrl = call.argument<String>("videoUrl") ?: ""
                val timeMs = call.argument<Long>("timeMs") ?: 0L
                
                val cachedData = thumbnailExtractor?.getCachedThumbnail(videoUrl, timeMs)
                result.success(cachedData)
            }
            
            "clearThumbnailCache" -> {
                thumbnailExtractor?.clearCache()
                result.success(true)
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    fun dispose() {
        thumbnailExtractor?.dispose()
    }
}