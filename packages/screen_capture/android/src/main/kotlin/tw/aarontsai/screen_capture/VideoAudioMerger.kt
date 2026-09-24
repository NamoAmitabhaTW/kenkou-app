package tw.aarontsai.screen_capture

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal object VideoAudioMerger {

    private const val TIMEOUT_US = 10_000L

    fun merge(videoPath: String, audioPath: String, outputPath: String): String {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(videoPath)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            } ?: throw IllegalStateException("影片沒有可用的視訊軌")
            extractor.selectTrack(track)
            val videoFormat = extractor.getTrackFormat(track)

            val videoDurationUs = if (videoFormat.containsKey(MediaFormat.KEY_DURATION)) {
                videoFormat.getLong(MediaFormat.KEY_DURATION)
            } else {
                Long.MAX_VALUE
            }
            val audio = encodeAac(Wav.read(audioPath), videoDurationUs)

            File(outputPath).delete()
            writeMp4(outputPath, extractor, videoFormat, audio)
        } finally {
            extractor.release()
        }

        File(videoPath).delete()
        File(audioPath).delete()
        return outputPath
    }

    private fun writeMp4(path: String, video: MediaExtractor, videoFormat: MediaFormat, audio: EncodedAudio?) {
        val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            if (videoFormat.containsKey(MediaFormat.KEY_ROTATION)) {
                muxer.setOrientationHint(videoFormat.getInteger(MediaFormat.KEY_ROTATION))
            }
            val videoTrack = muxer.addTrack(videoFormat)
            val audioTrack = audio?.let { muxer.addTrack(it.format) }
            muxer.start()

            val audioSamples = audio?.samples.orEmpty()
            var nextAudio = 0
            fun writeAudioUntil(timeUs: Long) {
                while (audioTrack != null && nextAudio < audioSamples.size &&
                    audioSamples[nextAudio].info.presentationTimeUs <= timeUs
                ) {
                    val sample = audioSamples[nextAudio++]
                    muxer.writeSampleData(audioTrack, ByteBuffer.wrap(sample.data), sample.info)
                }
            }

            val capacity = maxOf(
                if (videoFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                } else {
                    0
                },
                videoFormat.getInteger(MediaFormat.KEY_WIDTH) * videoFormat.getInteger(MediaFormat.KEY_HEIGHT),
            )
            val buffer = ByteBuffer.allocateDirect(capacity)
            val info = MediaCodec.BufferInfo()
            var firstUs = -1L

            while (true) {
                val size = video.readSampleData(buffer, 0)
                if (size < 0) break
                if (firstUs < 0) firstUs = video.sampleTime
                val timeUs = video.sampleTime - firstUs
                val flags = if (video.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                    MediaCodec.BUFFER_FLAG_KEY_FRAME
                } else {
                    0
                }
                writeAudioUntil(timeUs)
                info.set(0, size, timeUs, flags)
                muxer.writeSampleData(videoTrack, buffer, info)
                video.advance()
            }
            writeAudioUntil(Long.MAX_VALUE)

            muxer.stop()
        } catch (e: Exception) {
            File(path).delete()
            throw e
        } finally {
            muxer.release()
        }
    }

    private class Sample(val data: ByteArray, val info: MediaCodec.BufferInfo)

    private class EncodedAudio(val format: MediaFormat, val samples: List<Sample>)

    private fun encodeAac(wav: Wav, maxDurationUs: Long): EncodedAudio? {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, wav.sampleRate, wav.channels)
        val name = MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(format)
            ?: throw IllegalStateException("這台裝置沒有支援 ${wav.sampleRate} Hz 的 AAC 編碼器")
        format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        format.setInteger(MediaFormat.KEY_BIT_RATE, if (wav.channels > 1) 128_000 else 64_000)

        val codec = MediaCodec.createByCodecName(name)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            return RandomAccessFile(wav.path, "r").use { pcm ->
                pcm.seek(Wav.HEADER_SIZE)
                encode(codec, pcm, wav, maxDurationUs)
            }
        } finally {
            codec.release()
        }
    }

    private fun encode(codec: MediaCodec, pcm: RandomAccessFile, wav: Wav, maxDurationUs: Long): EncodedAudio? {
        val bytesPerFrame = wav.channels * 2
        val limit = if (maxDurationUs == Long.MAX_VALUE) {
            wav.dataSize
        } else {
            minOf(wav.dataSize, maxDurationUs * wav.sampleRate / 1_000_000 * bytesPerFrame)
        }

        val samples = mutableListOf<Sample>()
        var outputFormat: MediaFormat? = null
        val info = MediaCodec.BufferInfo()
        var chunk = ByteArray(0)
        var fed = 0L
        var inputDone = false
        var outputDone = false

        while (!outputDone) {
            if (!inputDone) {
                val index = codec.dequeueInputBuffer(TIMEOUT_US)
                if (index >= 0) {
                    val buffer = codec.getInputBuffer(index)!!
                    val size = (minOf(buffer.remaining().toLong(), limit - fed) / bytesPerFrame * bytesPerFrame).toInt()
                    val timeUs = fed / bytesPerFrame * 1_000_000 / wav.sampleRate
                    if (size <= 0) {
                        codec.queueInputBuffer(index, 0, 0, timeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        if (chunk.size < size) chunk = ByteArray(size)
                        pcm.readFully(chunk, 0, size)
                        buffer.put(chunk, 0, size)
                        codec.queueInputBuffer(index, 0, size, timeUs, 0)
                        fed += size
                    }
                }
            }

            val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                outputFormat = codec.outputFormat
            } else if (index >= 0) {
                if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                    val buffer = codec.getOutputBuffer(index)!!
                    val data = ByteArray(info.size)
                    buffer.position(info.offset)
                    buffer.get(data)
                    val sampleInfo = MediaCodec.BufferInfo()
                    sampleInfo.set(0, info.size, info.presentationTimeUs, 0)
                    samples += Sample(data, sampleInfo)
                }
                codec.releaseOutputBuffer(index, false)
                outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
            }
        }

        if (samples.isEmpty()) return null
        val format = outputFormat ?: throw IllegalStateException("AAC 編碼器沒有給出格式")
        return EncodedAudio(format, samples)
    }

    private class Wav(val path: String, val sampleRate: Int, val channels: Int, val dataSize: Long) {
        companion object {
            const val HEADER_SIZE = 44L

            fun read(path: String): Wav {
                val header = ByteArray(HEADER_SIZE.toInt())
                RandomAccessFile(path, "r").use { it.readFully(header) }
                val fields = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                fun tag(offset: Int) = String(header, offset, 4, Charsets.US_ASCII)

                require(tag(0) == "RIFF" && tag(8) == "WAVE" && tag(12) == "fmt " && tag(36) == "data") {
                    "看不懂這個 wav 的檔頭"
                }
                require(fields.getShort(20).toInt() == 1 && fields.getShort(34).toInt() == 16) {
                    "只支援 16-bit PCM 的 wav"
                }
                val dataSize = minOf(
                    fields.getInt(40).toLong() and 0xFFFFFFFFL,
                    File(path).length() - HEADER_SIZE,
                )
                return Wav(path, sampleRate = fields.getInt(24), channels = fields.getShort(22).toInt(), dataSize = dataSize)
            }
        }
    }
}
