package com.example.ai_mobile_coder_ui

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val STORAGE_CHANNEL = "ai_mobile_coder_ui/storage_access"
        private const val BACKGROUND_GUARD_CHANNEL = "ai_mobile_coder_ui/background_guard"
        private const val LOCAL_RUNTIME_CHANNEL = "ai_mobile_coder_ui/local_runtime"
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 31041
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasExternalStorageAccess" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        true
                    }
                    result.success(granted)
                }

                "hasManifestPermission" -> {
                    val permission = call.argument<String>("permission").orEmpty()
                    if (permission.isBlank()) {
                        result.success(false)
                    } else {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            permission
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                }

                "hasNetworkConnectivity" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    if (cm == null) {
                        result.success(false)
                    } else {
                        val active = cm.activeNetwork
                        val caps = cm.getNetworkCapabilities(active)
                        val hasInternet = caps?.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_INTERNET
                        ) ?: false
                        val validated = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                                ?: false
                        } else {
                            hasInternet
                        }
                        result.success(hasInternet && validated)
                    }
                }

                "openExternalStorageSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_GUARD_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ensureNotificationPermission" -> ensureNotificationPermission(result)
                    "startReplyGuard" -> {
                        startReplyGuard(call)
                        result.success(true)
                    }

                    "updateReplyGuard" -> {
                        updateReplyGuard(call)
                        result.success(true)
                    }

                    "stopReplyGuard" -> {
                        stopReplyGuard()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("background_guard_error", e.message, null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_RUNTIME_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getRuntimeStatus" -> {
                        result.success(LocalRuntimeManager.getStatus(this))
                    }

                    "startRuntime" -> {
                        LocalRuntimeManager.startRuntime(this)
                        result.success(LocalRuntimeManager.getStatus(this))
                    }

                    "stopRuntime" -> {
                        LocalRuntimeManager.stopRuntime(this)
                        result.success(LocalRuntimeManager.getStatus(this))
                    }

                    "prepareWorkspace" -> {
                        val projectRootPath = call.argument<String>("projectRootPath").orEmpty()
                        if (projectRootPath.isBlank()) {
                            result.error("invalid_args", "projectRootPath is required.", null)
                        } else {
                            result.success(
                                LocalRuntimeManager.prepareWorkspace(
                                    context = this,
                                    projectRootPath = projectRootPath
                                )
                            )
                        }
                    }

                    "getShellSnapshot" -> {
                        result.success(LocalShellSessionManager.getSnapshot(this))
                    }

                    "startShellSession" -> {
                        result.success(LocalShellSessionManager.startSession(this))
                    }

                    "stopShellSession" -> {
                        result.success(LocalShellSessionManager.stopSession(this))
                    }

                    "clearShellBuffer" -> {
                        result.success(LocalShellSessionManager.clearBuffer(this))
                    }

                    "sendShellInput" -> {
                        val input = call.argument<String>("input").orEmpty()
                        if (input.isBlank()) {
                            result.error("invalid_args", "input is required.", null)
                        } else {
                            result.success(LocalShellSessionManager.sendInput(this, input))
                        }
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                LocalRuntimeManager.recordLastError(this, e.message ?: "Unknown local runtime error")
                result.error("local_runtime_error", e.message, null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error("request_in_progress", "Notification permission request is in progress.", null)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_POST_NOTIFICATIONS
        )
    }

    private fun startReplyGuard(call: MethodCall) {
        val title = call.argument<String>("title").orEmpty().ifBlank { "AI 正在回复" }
        val text = call.argument<String>("text").orEmpty().ifBlank { "后台运行中，请稍候..." }
        val startedAtMs = call.argument<Number>("startedAtMs")?.toLong() ?: System.currentTimeMillis()
        val intent = Intent(this, ReplyForegroundService::class.java).apply {
            action = ReplyForegroundService.ACTION_START
            putExtra(ReplyForegroundService.EXTRA_TITLE, title)
            putExtra(ReplyForegroundService.EXTRA_TEXT, text)
            putExtra(ReplyForegroundService.EXTRA_STARTED_AT_MS, startedAtMs)
        }
        startReplyGuardService(intent)
    }

    private fun updateReplyGuard(call: MethodCall) {
        val title = call.argument<String>("title").orEmpty().ifBlank { "AI 正在回复" }
        val text = call.argument<String>("text").orEmpty().ifBlank { "后台运行中，请稍候..." }
        val startedAtMs = call.argument<Number>("startedAtMs")?.toLong() ?: System.currentTimeMillis()
        val intent = Intent(this, ReplyForegroundService::class.java).apply {
            action = ReplyForegroundService.ACTION_UPDATE
            putExtra(ReplyForegroundService.EXTRA_TITLE, title)
            putExtra(ReplyForegroundService.EXTRA_TEXT, text)
            putExtra(ReplyForegroundService.EXTRA_STARTED_AT_MS, startedAtMs)
        }
        startReplyGuardService(intent)
    }

    private fun stopReplyGuard() {
        val intent = Intent(this, ReplyForegroundService::class.java).apply {
            action = ReplyForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun startReplyGuardService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }
}
