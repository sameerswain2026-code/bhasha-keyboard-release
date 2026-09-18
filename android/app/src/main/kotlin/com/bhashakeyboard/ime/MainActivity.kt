package com.bhashakeyboard.ime

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Launcher / setup activity. Hosts the demo editor and exposes the
 * system bridge so the Flutter UI can guide the user through:
 *  1. Enabling Bhasha Keyboard in system settings
 *  2. Selecting it as the active keyboard
 *  3. Granting the microphone permission for voice typing
 */
class MainActivity : FlutterActivity() {

    private var micStream: MicStreamHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "bhasha/system"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openImeSettings" -> {
                    startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(true)
                }
                "showImePicker" -> {
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showInputMethodPicker()
                    result.success(true)
                }
                "isImeEnabled" -> {
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    val enabled = imm.enabledInputMethodList.any {
                        it.packageName == packageName
                    }
                    result.success(enabled)
                }
                "isImeSelected" -> {
                    val current = Settings.Secure.getString(
                        contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD
                    ) ?: ""
                    result.success(current.startsWith(packageName))
                }
                "hasMicPermission" -> {
                    result.success(hasMic())
                }
                "requestMicPermission" -> {
                    if (!hasMic()) {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.RECORD_AUDIO), 7001
                        )
                    }
                    result.success(hasMic())
                }
                "startMic" -> {
                    if (hasMic()) {
                        micStream?.startRecording()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopMic" -> {
                    micStream?.stopRecording()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        micStream = MicStreamHandler()
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, "bhasha/mic"
        ).setStreamHandler(micStream)
    }

    private fun hasMic(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    override fun onDestroy() {
        micStream?.stopRecording()
        super.onDestroy()
    }
}
