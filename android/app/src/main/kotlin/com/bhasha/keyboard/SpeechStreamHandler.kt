package com.bhasha.keyboard

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.EventChannel
import java.util.Locale

/** Bridges Android's installed speech service to Flutter as partial/final text. */
class SpeechStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var listening = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        stopSpeech()
        sink = null
    }

    fun startSpeech(localeTag: String): Boolean {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            sink?.success(mapOf("error" to "Speech recognition is not available on this device"))
            return false
        }
        stopSpeech()
        val r = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            // Keep the session armed. Android calls onEndOfSpeech before
            // onResults; clearing this flag here prevented continuous voice
            // typing from restarting after the first utterance.
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                if (!listening) return
                if (isRecoverable(error)) {
                    // ERROR_NO_MATCH / SPEECH_TIMEOUT is normal silence, not
                    // a user-visible failure. Re-arm listening quietly.
                    mainHandler.postDelayed({
                        if (listening) startListening(localeTag)
                    }, 220L)
                } else {
                    listening = false
                    sink?.success(mapOf("error" to readableError(error)))
                }
            }
            override fun onResults(results: Bundle?) {
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty()
                if (text.isNotBlank()) sink?.success(mapOf("text" to text, "isFinal" to true))
                if (listening) startListening(localeTag)
            }
            override fun onPartialResults(results: Bundle?) {
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty()
                if (text.isNotBlank()) sink?.success(mapOf("text" to text, "isFinal" to false))
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        listening = true
        startListening(localeTag)
        return true
    }

    private fun startListening(localeTag: String) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        try {
            recognizer?.startListening(intent)
        } catch (e: Exception) {
            listening = false
            sink?.success(mapOf("error" to "Speech recognition could not start"))
        }
    }

    fun stopSpeech() {
        listening = false
        mainHandler.removeCallbacksAndMessages(null)
        try { recognizer?.stopListening() } catch (_: Exception) {}
        try { recognizer?.cancel() } catch (_: Exception) {}
        recognizer?.destroy()
        recognizer = null
    }

    private fun readableError(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is required"
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech network unavailable"
        SpeechRecognizer.ERROR_NO_MATCH -> "No speech heard"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer is busy"
        else -> "Speech recognition unavailable"
    }

    private fun isRecoverable(code: Int): Boolean = when (code) {
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> true
        else -> false
    }
}
