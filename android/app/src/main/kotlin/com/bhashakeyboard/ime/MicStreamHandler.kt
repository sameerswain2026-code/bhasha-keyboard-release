package com.bhashakeyboard.ime

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Streams 16kHz mono PCM16 microphone audio to Flutter over an
 * EventChannel. Chunks are ~100ms (3200 bytes) so Sarvam receives a
 * steady low-latency stream for real-time transcription.
 */
class MicStreamHandler : EventChannel.StreamHandler {

    companion object {
        const val SAMPLE_RATE = 16000
        const val CHUNK_BYTES = 3200 // 100ms of 16kHz PCM16 mono
    }

    private var events: EventChannel.EventSink? = null
    private var recorder: AudioRecord? = null
    private var thread: Thread? = null
    private val recording = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        stopRecording()
        events = null
    }

    @SuppressLint("MissingPermission")
    fun startRecording() {
        if (recording.get()) return
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf, CHUNK_BYTES * 4)
        val rec = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            )
        } catch (e: Exception) {
            null
        } ?: return
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            return
        }
        recorder = rec
        recording.set(true)
        rec.startRecording()
        thread = Thread {
            val buffer = ByteArray(CHUNK_BYTES)
            while (recording.get()) {
                val read = rec.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    mainHandler.post { events?.success(chunk) }
                }
            }
        }.apply {
            name = "bhasha-mic"
            start()
        }
    }

    fun stopRecording() {
        if (!recording.getAndSet(false)) return
        thread?.join(300)
        thread = null
        recorder?.let {
            try {
                it.stop()
            } catch (_: Exception) {}
            it.release()
        }
        recorder = null
    }
}
