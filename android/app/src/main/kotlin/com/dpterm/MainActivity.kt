package com.dpterm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.view.KeyEvent
import android.system.Os
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val VOLUME_CHANNEL = "com.dpterm/volume_keys"
    private val STORAGE_CHANNEL = "com.dpterm/storage"

    private var volumeChannel: MethodChannel? = null
    private var storageChannel: MethodChannel? = null
    private var volumeKeysEnabled = true

    companion object {
        private const val REQUEST_STORAGE_PERMISSION = 1001
        private const val REQUEST_MANAGE_STORAGE = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 音量键通道
        volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
        volumeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setVolumeKeysEnabled" -> {
                    volumeKeysEnabled = call.argument<Boolean>("enabled") ?: true
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 存储通道
        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
        storageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkStoragePermission" -> {
                    result.success(checkStoragePermission())
                }
                "requestStoragePermission" -> {
                    requestStoragePermission()
                    result.success(null)
                }
                "setupStorageSymlinks" -> {
                    val homePath = call.argument<String>("homePath")
                    if (homePath != null) {
                        Thread {
                            val setupResult = setupStorageSymlinks(homePath)
                            runOnUiThread {
                                result.success(setupResult)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENT", "homePath is required", null)
                    }
                }
                "getExternalStoragePath" -> {
                    result.success(Environment.getExternalStorageDirectory().absolutePath)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 检查存储权限
     */
    private fun checkStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ 检查 MANAGE_EXTERNAL_STORAGE
            Environment.isExternalStorageManager()
        } else {
            // Android 10 及以下检查传统权限
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * 请求存储权限
     */
    private fun requestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ 需要请求 MANAGE_EXTERNAL_STORAGE
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    startActivityForResult(intent, REQUEST_MANAGE_STORAGE)
                } catch (e: Exception) {
                    // 备用方案：打开所有应用的文件访问设置
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivityForResult(intent, REQUEST_MANAGE_STORAGE)
                }
            }
        } else {
            // Android 10 及以下请求传统权限
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                REQUEST_STORAGE_PERMISSION
            )
        }
    }

    /**
     * 设置存储符号链接
     * 类似 Termux 的 termux-setup-storage 功能
     */
    private fun setupStorageSymlinks(homePath: String): Map<String, Any> {
        val errors = mutableListOf<String>()
        val created = mutableListOf<String>()

        try {
            // 创建 ~/storage 目录
            val storageDir = File(homePath, "storage")
            if (storageDir.exists()) {
                // 清理现有目录
                storageDir.deleteRecursively()
            }
            storageDir.mkdirs()

            // 获取外部存储根目录
            val externalStorage = Environment.getExternalStorageDirectory()

            // 创建 shared 符号链接 -> 外部存储根目录
            createSymlink(
                externalStorage.absolutePath,
                File(storageDir, "shared").absolutePath,
                errors, created
            )

            // 创建标准目录的符号链接
            val standardDirs = mapOf(
                "downloads" to Environment.DIRECTORY_DOWNLOADS,
                "dcim" to Environment.DIRECTORY_DCIM,
                "pictures" to Environment.DIRECTORY_PICTURES,
                "music" to Environment.DIRECTORY_MUSIC,
                "movies" to Environment.DIRECTORY_MOVIES,
                "documents" to Environment.DIRECTORY_DOCUMENTS
            )

            for ((name, dirType) in standardDirs) {
                val dir = Environment.getExternalStoragePublicDirectory(dirType)
                if (dir.exists() || dir.mkdirs()) {
                    createSymlink(
                        dir.absolutePath,
                        File(storageDir, name).absolutePath,
                        errors, created
                    )
                }
            }

            // 创建应用专属外部存储目录的符号链接
            val externalFilesDirs = getExternalFilesDirs(null)
            externalFilesDirs.forEachIndexed { index, dir ->
                if (dir != null) {
                    if (!dir.exists()) dir.mkdirs()
                    createSymlink(
                        dir.absolutePath,
                        File(storageDir, "external-$index").absolutePath,
                        errors, created
                    )
                }
            }

            // 创建媒体目录的符号链接
            val mediaDirs = externalMediaDirs
            mediaDirs.forEachIndexed { index, dir ->
                if (dir != null) {
                    if (!dir.exists()) dir.mkdirs()
                    createSymlink(
                        dir.absolutePath,
                        File(storageDir, "media-$index").absolutePath,
                        errors, created
                    )
                }
            }

        } catch (e: Exception) {
            errors.add("Setup failed: ${e.message}")
        }

        return mapOf(
            "success" to errors.isEmpty(),
            "created" to created,
            "errors" to errors
        )
    }

    /**
     * 创建符号链接
     */
    private fun createSymlink(
        target: String,
        link: String,
        errors: MutableList<String>,
        created: MutableList<String>
    ) {
        try {
            Os.symlink(target, link)
            created.add("$link -> $target")
        } catch (e: Exception) {
            errors.add("Failed to create symlink $link: ${e.message}")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MANAGE_STORAGE) {
            // 通知 Flutter 权限结果
            storageChannel?.invokeMethod("onPermissionResult", mapOf(
                "granted" to checkStoragePermission()
            ))
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_STORAGE_PERMISSION) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            // 通知 Flutter 权限结果
            storageChannel?.invokeMethod("onPermissionResult", mapOf(
                "granted" to granted
            ))
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeKeysEnabled) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "up",
                        "action" to "down"
                    ))
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeChannel?.invokeMethod("onVolumeKey", mapOf(
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
                    volumeChannel?.invokeMethod("onVolumeKey", mapOf(
                        "key" to "up",
                        "action" to "up"
                    ))
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeChannel?.invokeMethod("onVolumeKey", mapOf(
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
