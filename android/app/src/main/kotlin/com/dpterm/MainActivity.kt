package com.dpterm

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dpterm/volume_keys"
    private var methodChannel: MethodChannel? = null
    private var volumeKeysEnabled = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setVolumeKeysEnabled" -> {
                    volumeKeysEnabled = call.argument<Boolean>("enabled") ?: true
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeKeysEnabled) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    methodChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "up",
                        "action" to "down"
                    ))
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    methodChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "down",
                        "action" to "down"
                    ))
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeKeysEnabled) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    methodChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "up",
                        "action" to "up"
                    ))
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    methodChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "down",
                        "action" to "up"
                    ))
                    return true
                }
            }
        }
        return super.onKeyUp(keyCode, event)
    }
}
