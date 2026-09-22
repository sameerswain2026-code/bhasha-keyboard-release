package com.bhasha.keyboard

import android.Manifest
import android.content.ClipboardManager
import android.content.ClipDescription
import android.content.Context
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputContentInfo
import android.view.inputmethod.InputConnection
import android.widget.FrameLayout
import android.speech.tts.TextToSpeech
import java.util.Locale
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import android.inputmethodservice.InputMethodService
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bhasha Keyboard system-wide IME.
 *
 * Hosts a dedicated FlutterEngine running the `imeMain` entrypoint and
 * renders the Flutter KeyboardView as the system input view, so the full
 * keyboard (22 languages, transliteration, voice, emoji, panels) works
 * inside WhatsApp, Telegram and every other Android app.
 *
 * Text flows through InputConnection:
 *  - Flutter sends text diffs -> commitText / deleteSurroundingText
 *  - Editor action (send/search/done/next) -> performEditorAction
 */
class BhashaImeService : InputMethodService() {

    companion object {
        // Toolbar 42 + suggestion strip 38 + key area 210 (logical px = dp)
        private const val KEYBOARD_HEIGHT_DP = 292f
    }

    private var flutterEngine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var imeChannel: MethodChannel? = null
    private var micStream: MicStreamHandler? = null
    private var speechStream: SpeechStreamHandler? = null
    private var clipboardManager: ClipboardManager? = null
    private var clipListener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var selfChangeReset: Runnable? = null
    private var textToSpeech: TextToSpeech? = null

    /// Set true immediately before WE mutate the host's text via
    /// applyDiff/deleteHostSelection, cleared the moment the resulting
    /// onUpdateSelection callback for that edit arrives. Any selection
    /// update that arrives while this is false was NOT caused by us -
    /// e.g. the user long-pressed the host app's own field and tapped
    /// "Paste"/"Cut" from Android's native text-selection menu, an
    /// autocorrect/autofill rewrite by the host app, or the field simply
    /// already contained text (a draft, a quoted reply) when the
    /// keyboard was summoned. Those are exactly the situations that
    /// silently desynced the Flutter-side shadow editor from the host's
    /// REAL text in the original bug report ("copy-paste karke yahan
    /// per paste karta hun to delete hi nahi hota"): the shadow mirror
    /// kept believing the field was empty (or had different length/
    /// content) than the host's real text, so backspace's `if
    /// (full.isEmpty) return;`/diff-against-stale-mirror logic quietly
    /// no-op'd instead of deleting the pasted text.
    private var selfInitiatedChange = false

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "imeMain"
            )
        )

        imeChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, "bhasha/ime"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val ic = currentInputConnection
                when (call.method) {
                    "replaceRange" -> {
                        val start = call.argument<Int>("start") ?: 0
                        val end = call.argument<Int>("end") ?: start
                        val text = call.argument<String>("text") ?: ""
                        if (ic != null) {
                            markSelfInitiatedChange()
                            ic.beginBatchEdit()
                            // Select exactly the stale range in the host field,
                            // then replace it atomically. This is safe for
                            // insertion, deletion, and replacement in the
                            // middle of existing text; unlike deleting from
                            // the current caret, it cannot consume the wrong
                            // side of the buffer.
                            ic.setSelection(start, end)
                            ic.commitText(text, 1)
                            ic.endBatchEdit()
                        }
                        result.success(true)
                    }
                    "applyDiff" -> {
                        val delete = call.argument<Int>("delete") ?: 0
                        val insert = call.argument<String>("insert") ?: ""
                        if (ic != null) {
                            markSelfInitiatedChange()
                            ic.beginBatchEdit()
                            if (delete > 0) ic.deleteSurroundingText(delete, 0)
                            if (insert.isNotEmpty()) ic.commitText(insert, 1)
                            ic.endBatchEdit()
                        }
                        result.success(true)
                    }
                    "setSelection" -> {
                        val start = call.argument<Int>("start") ?: 0
                        val end = call.argument<Int>("end") ?: start
                        if (ic != null) {
                            markSelfInitiatedChange()
                            // Cursor-only navigation must reach the host field
                            // before the next applyDiff; otherwise the host
                            // continues editing at its previous cursor and can
                            // insert an apparently duplicated text block.
                            ic.setSelection(start, end)
                        }
                        result.success(true)
                    }
                    "performAction" -> {
                        val action = when (call.argument<String>("action")) {
                            "send" -> EditorInfo.IME_ACTION_SEND
                            "search" -> EditorInfo.IME_ACTION_SEARCH
                            "done" -> EditorInfo.IME_ACTION_DONE
                            "next" -> EditorInfo.IME_ACTION_NEXT
                            "go" -> EditorInfo.IME_ACTION_GO
                            else -> EditorInfo.IME_ACTION_UNSPECIFIED
                        }
                        ic?.performEditorAction(action)
                        result.success(true)
                    }
                    "hideKeyboard" -> {
                        requestHideSelf(0)
                        result.success(true)
                    }
                    "openManagementApp" -> {
                        startActivity(Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(true)
                    }
                    "deleteHostSelection" -> {
                        result.success(deleteHostSelection())
                    }
                    "getSurroundingText" -> {
                        result.success(getSurroundingText())
                    }
                    "getSelectedText" -> {
                        result.success(ic?.getSelectedText(0)?.toString() ?: "")
                    }
                    "getClipboardText" -> {
                        result.success(clipboardManager?.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString() ?: "")
                    }
                    "replaceSelectedText" -> {
                        val replacement = call.argument<String>("text") ?: ""
                        if (ic != null) {
                            markSelfInitiatedChange()
                            ic.commitText(replacement, 1)
                        }
                        result.success(true)
                    }
                    "speakText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val localeTag = call.argument<String>("locale")
                        localeTag?.takeIf { it.isNotBlank() }?.let {
                            textToSpeech?.language = Locale.forLanguageTag(it)
                        }
                        if (text.isBlank()) {
                            result.success(false)
                        } else {
                            textToSpeech?.speak(
                                text,
                                TextToSpeech.QUEUE_FLUSH,
                                null,
                                "bhasha-selection"
                            )
                            result.success(true)
                        }
                    }
                    "stopSpeaking" -> {
                        textToSpeech?.stop()
                        result.success(true)
                    }
                    "shareMedia" -> {
                        val source = call.argument<String>("source") ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: "image/*"
                        val title = call.argument<String>("title") ?: "Bhasha media"
                        shareMedia(source, mimeType, title)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // System bridge subset available inside the IME (mic for voice).
        MethodChannel(
            engine.dartExecutor.binaryMessenger, "bhasha/system"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasMicPermission" -> result.success(hasMic())
                "requestMicPermission" -> result.success(hasMic())
                "startMic" -> {
                    if (hasMic()) {
                        result.success(micStream?.startRecording() == true)
                    } else {
                        result.success(false)
                    }
                }
                "stopMic" -> {
                    micStream?.stopRecording()
                    result.success(true)
                }
                "isImeEnabled", "isImeSelected" -> result.success(true)
                else -> result.notImplemented()
            }
        }

        textToSpeech = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale.getDefault()
            }
        }

        micStream = MicStreamHandler()
        EventChannel(
            engine.dartExecutor.binaryMessenger, "bhasha/mic"
        ).setStreamHandler(micStream)

        speechStream = SpeechStreamHandler(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger, "bhasha/speech"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasMicPermission" -> result.success(hasMic())
                "startSpeech" -> result.success(
                    if (hasMic()) speechStream?.startSpeech(
                        call.argument<String>("locale") ?: "en-IN"
                    ) == true else false
                )
                "stopSpeech" -> {
                    speechStream?.stopSpeech()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            engine.dartExecutor.binaryMessenger, "bhasha/speech_results"
        ).setStreamHandler(speechStream)

        flutterEngine = engine

        // Watch the SYSTEM clipboard (not just our own copy button) so
        // that copying text in ANY app (long-press -> Copy in WhatsApp,
        // Chrome, Gallery, etc.) shows the same "just copied" highlight
        // Gboard shows in its own clipboard/toolbar UI, even though that
        // copy action never passed through this IME at all.
        clipboardManager =
            getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        clipListener = ClipboardManager.OnPrimaryClipChangedListener {
            val clip = clipboardManager?.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val text = clip.getItemAt(0).coerceToText(this)?.toString()
                if (!text.isNullOrEmpty()) {
                    imeChannel?.invokeMethod("externalClipboardChanged", text)
                }
            }
        }
        clipboardManager?.addPrimaryClipChangedListener(clipListener)
    }

    override fun onCreateInputView(): View {
        val engine = flutterEngine ?: return FrameLayout(this)
        flutterView?.detachFromFlutterEngine()
        val view = FlutterView(this, FlutterTextureView(this))
        view.attachToFlutterEngine(engine)
        flutterView = view

        val heightPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, KEYBOARD_HEIGHT_DP, resources.displayMetrics
        ).toInt()

        // Root container sized to wrap content so it can grow to make
        // room for the system navigation bar (3-button nav bar or
        // gesture-nav handle strip), which otherwise overlaps/hides the
        // bottom row (space bar, language switch) on many devices.
        val root = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
            // The inset belongs below Flutter's keyboard surface. Do not let
            // FrameLayout clip the last key row when Android uses gesture or
            // 3-button navigation.
            clipToPadding = false
            clipChildren = false
            addView(
                view,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, heightPx
                )
            )
        }

        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val navBarBottom = insets
                .getInsets(WindowInsetsCompat.Type.navigationBars())
                .bottom
            // Keep the Flutter surface at the same logical height on every
            // device, but reserve the navigation-bar strip outside it. This
            // keeps the bottom key row reachable on Telegram, WhatsApp,
            // chat/editor fields, and every panel page.
            val flutterParams = view.layoutParams as FrameLayout.LayoutParams
            flutterParams.height = heightPx
            view.layoutParams = flutterParams
            // Make the IME window itself taller than the Flutter surface;
            // padding alone can be ignored by some OEM IME containers.
            v.layoutParams = (v.layoutParams as FrameLayout.LayoutParams).apply {
                height = heightPx + navBarBottom
            }
            v.setPadding(0, 0, 0, navBarBottom)
            v.minimumHeight = heightPx + navBarBottom
            v.requestLayout()
            // The IME root has explicitly consumed the navigation-bar inset
            // above. Returning the original insets lets some Android/OEM
            // windows apply the same bottom inset a second time, which can
            // push the last key row below the navigation bar after a system
            // dark/light-mode change.
            WindowInsetsCompat.CONSUMED
        }

        return root
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        flutterEngine?.lifecycleChannel?.appIsResumed()

        // Android may reuse the same IME FlutterEngine when the keyboard is
        // minimized and shown again without creating a new input session.
        // Reset the visible page at the view boundary as well as on
        // startInput, so Settings/emoji/symbol panels cannot survive a
        // minimize -> reopen cycle.
        imeChannel?.invokeMethod("resetTransientState", null)

        val actionName = when ((info?.imeOptions ?: 0) and EditorInfo.IME_MASK_ACTION) {
            EditorInfo.IME_ACTION_SEND -> "send"
            EditorInfo.IME_ACTION_SEARCH -> "search"
            EditorInfo.IME_ACTION_DONE -> "done"
            EditorInfo.IME_ACTION_NEXT -> "next"
            EditorInfo.IME_ACTION_GO -> "send"
            else -> "newline"
        }
        imeChannel?.invokeMethod(
            "startInput",
            mapOf("action" to actionName, "restarting" to restarting)
        )
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        imeChannel?.invokeMethod("finishInput", null)
        micStream?.stopRecording()
        speechStream?.stopSpeech()
        flutterEngine?.lifecycleChannel?.appIsInactive()
        super.onFinishInputView(finishingInput)
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    /// Fires on EVERY cursor/selection/text change in the host field,
    /// whether caused by us (typing/backspace/applyDiff) or by anything
    /// else: the user pasting via Android's native "Paste" bubble/menu,
    /// cutting a native selection, the host app's own autocorrect, or
    /// simply the field already holding text when this IME attached.
    ///
    /// If [selfInitiatedChange] is true, this update is just the
    /// expected echo of our own edit - consume the flag and do nothing
    /// (the Flutter-side shadow editor already applied that same change
    /// optimistically and stays in sync on its own).
    ///
    /// Otherwise, an outside actor changed the host's real text/cursor
    /// behind our back. Telling Flutter to silently re-fetch the host's
    /// actual surrounding text and resync its shadow mirror is exactly
    /// what fixes the reported bug: paste text from another app into
    /// the field, then press backspace - previously the shadow mirror
    /// still thought the field was empty/unchanged, so deleteBackward()
    /// operated on stale state and appeared to do nothing no matter how
    /// many times Delete was pressed.
    override fun onUpdateSelection(
        oldSelStart: Int,
        oldSelEnd: Int,
        newSelStart: Int,
        newSelEnd: Int,
        candidatesStart: Int,
        candidatesEnd: Int
    ) {
        super.onUpdateSelection(
            oldSelStart, oldSelEnd, newSelStart, newSelEnd,
            candidatesStart, candidatesEnd
        )
        if (selfInitiatedChange) {
            // A single commit/delete can produce more than one selection
            // callback during beginBatchEdit/endBatchEdit. Keep the guard
            // alive for the whole callback burst; clearing it on the first
            // callback caused the next echo to be misclassified as an
            // external paste/cut and reset Flutter's cursor unexpectedly.
            return
        }
        imeChannel?.invokeMethod("externalTextChanged", getSurroundingText())
    }

    /** Marks the next short burst of host selection callbacks as caused by
     * our own InputConnection edit. Android may emit multiple callbacks for
     * one batch, so a boolean cleared by the first callback is insufficient.
     */
    private fun markSelfInitiatedChange() {
        selfInitiatedChange = true
        selfChangeReset?.let { mainHandler.removeCallbacks(it) }
        val reset = Runnable { selfInitiatedChange = false }
        selfChangeReset = reset
        mainHandler.postDelayed(reset, 250L)
    }

    /// Deletes the host app's actual text selection (e.g. text selected
    /// with the native selection handles in WhatsApp/Telegram), which
    /// the Flutter-side shadow editor has no knowledge of. Returns true
    /// only if a non-empty selection existed and was removed; false
    /// means the caller should fall back to normal single-char delete
    /// on the shadow editor.
    private fun deleteHostSelection(): Boolean {
        val ic = currentInputConnection ?: return false
        val selected = ic.getSelectedText(0)
        if (selected.isNullOrEmpty()) return false
        markSelfInitiatedChange()
        ic.beginBatchEdit()
        // commitText() replaces the current selection (or composing
        // region) with the given text - "" effectively deletes it.
        ic.commitText("", 1)
        ic.endBatchEdit()
        return true
    }

    /// Reads up to 1000 chars before and after the cursor from the host
    /// app's ACTUAL text (bypassing the Flutter-side shadow mirror
    /// entirely). Used after a host-side selection delete so the shadow
    /// editor can be re-synced to the host's real remaining text instead
    /// of being blindly cleared - otherwise a second backspace on the
    /// one character left behind would incorrectly no-op because the
    /// shadow mirror falsely believes the field is already empty.
    private fun getSurroundingText(): Map<String, String> {
        val ic = currentInputConnection
            ?: return mapOf("before" to "", "after" to "")
        val before = ic.getTextBeforeCursor(1000, 0)?.toString() ?: ""
        val after = ic.getTextAfterCursor(1000, 0)?.toString() ?: ""
        return mapOf("before" to before, "after" to after)
    }

    private fun hasMic(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun shareMedia(source: String, mimeType: String, title: String) {
        Thread {
            try {
                val extension = if (mimeType == "image/gif") "gif" else "png"
                val file = File(cacheDir, "bhasha-share-${System.currentTimeMillis()}.$extension")
                if (source.startsWith("http://") || source.startsWith("https://")) {
                    URL(source).openStream().use { input ->
                        FileOutputStream(file).use { output -> input.copyTo(output) }
                    }
                } else {
                    val assetPath = if (source.startsWith("assets/")) {
                        "flutter_assets/$source"
                    } else {
                        "flutter_assets/assets/$source"
                    }
                    assets.open(assetPath).use { input ->
                        FileOutputStream(file).use { output -> input.copyTo(output) }
                    }
                }
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file
                )
                // InputConnection and activity launches must happen on the
                // service main thread. The download itself stays off-thread.
                mainHandler.post {
                    val inputConnection = currentInputConnection
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1 &&
                        inputConnection != null
                    ) {
                        val description = ClipDescription(title, arrayOf(mimeType))
                        val content = InputContentInfo(uri, description, null)
                        val committed = inputConnection.commitContent(
                            content,
                            InputConnection.INPUT_CONTENT_GRANT_READ_URI_PERMISSION,
                            null,
                        )
                        if (committed) return@post
                    }
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TITLE, title)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(Intent.createChooser(intent, "Share $title"))
                }
            } catch (_: Exception) {
                // The Flutter preview fallback remains available when a host
                // app or network cannot accept a rich media share.
            }
        }.start()
    }

    override fun onDestroy() {
        clipListener?.let { clipboardManager?.removePrimaryClipChangedListener(it) }
        micStream?.stopRecording()
        speechStream?.stopSpeech()
        selfChangeReset?.let { mainHandler.removeCallbacks(it) }
        selfChangeReset = null
        flutterView?.detachFromFlutterEngine()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        flutterEngine?.destroy()
        flutterEngine = null
        super.onDestroy()
    }
}
