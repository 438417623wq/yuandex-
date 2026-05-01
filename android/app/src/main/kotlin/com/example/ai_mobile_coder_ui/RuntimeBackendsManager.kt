package com.yuandex

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

object RuntimeBackendsManager {
    private const val TERMUX_PACKAGE = "com.termux"
    private const val TERMUX_RUN_COMMAND_PERMISSION = "com.termux.permission.RUN_COMMAND"
    private const val TERMUX_RUN_COMMAND_ACTION = "com.termux.RUN_COMMAND"
    private const val TERMUX_RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService"
    private const val TERMUX_EXTRA_COMMAND_PATH = "com.termux.RUN_COMMAND_PATH"
    private const val TERMUX_EXTRA_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS"
    private const val TERMUX_EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
    private const val TERMUX_EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
    private const val TERMUX_EXTRA_PENDING_INTENT = "pendingIntent"
    private const val TERMUX_EXTRA_LABEL = "com.termux.RUN_COMMAND_LABEL"
    private const val TERMUX_EXTRA_DESCRIPTION = "com.termux.RUN_COMMAND_DESCRIPTION"
    private const val TERMUX_RESULT_BUNDLE = "result"
    private const val TERMUX_RESULT_STDOUT = "stdout"
    private const val TERMUX_RESULT_STDERR = "stderr"
    private const val TERMUX_RESULT_EXIT_CODE = "exitCode"
    private const val TERMUX_RESULT_ERR = "err"
    private const val TERMUX_RESULT_ERRMSG = "errmsg"
    private const val TERMUX_BASH_PATH = "/data/data/com.termux/files/usr/bin/bash"
    private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    private const val FILE_PROVIDER_SUFFIX = ".fileprovider"
    private const val EXTRA_EXECUTION_ID = "runtime_backend_execution_id"

    private val nextExecutionId = AtomicInteger(1)
    private val pendingExecutions =
        ConcurrentHashMap<Int, PendingTermuxExecution>()

    fun getBackendStatus(context: Context): Map<String, Any> {
        val termuxInstalled = isPackageInstalled(context, TERMUX_PACKAGE)
        return linkedMapOf(
            "supported" to true,
            "nativeAvailable" to true,
            "termuxInstalled" to termuxInstalled,
            "termuxPermissionGranted" to isPermissionGranted(context, TERMUX_RUN_COMMAND_PERMISSION),
            "termuxLaunchable" to (launchIntentFor(context, TERMUX_PACKAGE) != null),
            "rootAvailable" to isRootAvailable(),
            "shizukuInstalled" to isPackageInstalled(context, SHIZUKU_PACKAGE),
            "shizukuLaunchable" to (launchIntentFor(context, SHIZUKU_PACKAGE) != null),
            "systemLogcatAvailable" to canReadSystemLogcat(),
            "lastError" to "",
        )
    }

    fun openBackendApp(context: Context, backend: String): Boolean {
        val packageName = when (backend) {
            "termux" -> TERMUX_PACKAGE
            "shizuku" -> SHIZUKU_PACKAGE
            else -> return false
        }
        val launchIntent = launchIntentFor(context, packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
            return true
        }
        if (!isPackageInstalled(context, packageName)) {
            return false
        }
        val settingsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(settingsIntent)
        return true
    }

    fun executeTermuxCommand(
        context: Context,
        command: String,
        renderedCommand: String,
        workingDirectory: String,
        timeoutMs: Long,
        maxOutputBytes: Int,
    ): Map<String, Any> {
        require(command.isNotBlank()) { "command is required." }
        if (!isPackageInstalled(context, TERMUX_PACKAGE)) {
            return linkedMapOf(
                "ok" to false,
                "command" to command,
                "workingDirectory" to workingDirectory,
                "exitCode" to -1,
                "timedOut" to false,
                "stdout" to "",
                "stderr" to "",
                "backend" to "termux",
                "lastError" to "Termux is not installed.",
            )
        }
        if (!isPermissionGranted(context, TERMUX_RUN_COMMAND_PERMISSION)) {
            return linkedMapOf(
                "ok" to false,
                "command" to command,
                "workingDirectory" to workingDirectory,
                "exitCode" to -1,
                "timedOut" to false,
                "stdout" to "",
                "stderr" to "",
                "backend" to "termux",
                "lastError" to "RUN_COMMAND permission is not granted.",
            )
        }

        val boundedTimeoutMs = timeoutMs.coerceIn(1000L, 240000L)
        val boundedMaxOutputBytes = maxOutputBytes.coerceIn(4096, 524288)
        val executionId = nextExecutionId.getAndIncrement()
        val latch = CountDownLatch(1)
        pendingExecutions[executionId] = PendingTermuxExecution(
            latch = latch,
            command = command,
            workingDirectory = workingDirectory,
            maxOutputBytes = boundedMaxOutputBytes,
            timeoutMs = boundedTimeoutMs,
        )

        try {
            val callbackIntent = Intent(context, TermuxCommandResultReceiver::class.java).apply {
                putExtra(EXTRA_EXECUTION_ID, executionId)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            } else {
                android.app.PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                executionId,
                callbackIntent,
                flags
            )
            val workdir = workingDirectory.ifBlank { "/data/data/com.termux/files/home" }
            val commandText = renderedCommand.ifBlank { command }
            val intent = Intent(TERMUX_RUN_COMMAND_ACTION).apply {
                setClassName(TERMUX_PACKAGE, TERMUX_RUN_COMMAND_SERVICE)
                putExtra(TERMUX_EXTRA_COMMAND_PATH, TERMUX_BASH_PATH)
                putExtra(TERMUX_EXTRA_ARGUMENTS, arrayOf("-lc", commandText))
                putExtra(TERMUX_EXTRA_WORKDIR, workdir)
                putExtra(TERMUX_EXTRA_BACKGROUND, true)
                putExtra(TERMUX_EXTRA_LABEL, "AI Mobile Coder")
                putExtra(TERMUX_EXTRA_DESCRIPTION, "Execute toolchain command from Flutter")
                putExtra(TERMUX_EXTRA_PENDING_INTENT, pendingIntent)
            }
            context.startService(intent)

            val completed = latch.await(boundedTimeoutMs + 5000L, TimeUnit.MILLISECONDS)
            val pending = pendingExecutions.remove(executionId)
            if (!completed || pending?.result == null) {
                return linkedMapOf(
                    "ok" to false,
                    "command" to command,
                    "workingDirectory" to workdir,
                    "exitCode" to -1,
                    "timedOut" to true,
                    "stdout" to "",
                    "stderr" to "Timed out waiting for Termux result.",
                    "backend" to "termux",
                    "timeoutMs" to boundedTimeoutMs,
                    "maxOutputBytes" to boundedMaxOutputBytes,
                )
            }
            return pending.result!!
        } catch (error: Exception) {
            pendingExecutions.remove(executionId)
            return linkedMapOf(
                "ok" to false,
                "command" to command,
                "workingDirectory" to workingDirectory,
                "exitCode" to -1,
                "timedOut" to false,
                "stdout" to "",
                "stderr" to (error.message ?: "Failed to dispatch Termux command."),
                "backend" to "termux",
                "timeoutMs" to boundedTimeoutMs,
                "maxOutputBytes" to boundedMaxOutputBytes,
            )
        }
    }

    fun onTermuxCommandResult(intent: Intent?) {
        val safeIntent = intent ?: return
        val executionId = safeIntent.getIntExtra(EXTRA_EXECUTION_ID, -1)
        if (executionId <= 0) {
            return
        }
        val pending = pendingExecutions[executionId] ?: return
        val extras = safeIntent.extras
        val bundle = extractResultBundle(extras)
        val stdout = trimToBytes(bundle?.getString(TERMUX_RESULT_STDOUT).orEmpty(), pending.maxOutputBytes)
        val stderr = trimToBytes(bundle?.getString(TERMUX_RESULT_STDERR).orEmpty(), pending.maxOutputBytes)
        val exitCode = bundle?.getInt(TERMUX_RESULT_EXIT_CODE, -1) ?: -1
        val err = bundle?.getInt(TERMUX_RESULT_ERR, 0) ?: 0
        val errMsg = bundle?.getString(TERMUX_RESULT_ERRMSG).orEmpty()
        val timedOut = false
        val result = linkedMapOf(
            "ok" to (exitCode == 0 && err == 0),
            "command" to pending.command,
            "workingDirectory" to pending.workingDirectory,
            "exitCode" to exitCode,
            "timedOut" to timedOut,
            "stdout" to stdout,
            "stderr" to buildString {
                if (stderr.isNotBlank()) {
                    append(stderr)
                }
                if (errMsg.isNotBlank()) {
                    if (isNotEmpty()) append('\n')
                    append(errMsg)
                }
            },
            "backend" to "termux",
            "timeoutMs" to pending.timeoutMs,
            "maxOutputBytes" to pending.maxOutputBytes,
        )
        pending.result = result
        pending.latch.countDown()
    }

    fun installApkWithSystem(context: Context, apkPath: String): Map<String, Any> {
        require(apkPath.isNotBlank()) { "apkPath is required." }
        val apkFile = File(apkPath)
        require(apkFile.exists()) { "APK file does not exist." }
        require(apkFile.isFile) { "APK path is not a file." }

        val authority = context.packageName + FILE_PROVIDER_SUFFIX
        val contentUri = FileProvider.getUriForFile(context, authority, apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        return linkedMapOf(
            "ok" to true,
            "command" to "system_install",
            "apkPath" to apkFile.absolutePath,
            "workingDirectory" to apkFile.parent.orEmpty(),
            "exitCode" to 0,
            "timedOut" to false,
            "stdout" to "System package installer launched.",
            "stderr" to "",
        )
    }

    fun installApkWithRoot(
        apkPath: String,
        replace: Boolean,
        grantAll: Boolean,
        timeoutMs: Long,
        maxOutputBytes: Int,
    ): Map<String, Any> {
        require(apkPath.isNotBlank()) { "apkPath is required." }
        val apkFile = File(apkPath)
        require(apkFile.exists()) { "APK file does not exist." }
        require(apkFile.isFile) { "APK path is not a file." }
        val args = mutableListOf("pm", "install")
        if (replace) args.add("-r")
        if (grantAll) args.add("-g")
        args.add(apkFile.absolutePath)
        val command = args.joinToString(" ") { shellQuote(it) }
        val result = runRootCommand(
            command = command,
            timeoutMs = timeoutMs,
            maxOutputBytes = maxOutputBytes,
        )
        return linkedMapOf(
            "ok" to (result["ok"] == true),
            "command" to "su -c $command",
            "workingDirectory" to apkFile.parent.orEmpty(),
            "exitCode" to (result["exitCode"] ?: -1),
            "timedOut" to (result["timedOut"] == true),
            "stdout" to (result["stdout"] ?: ""),
            "stderr" to (result["stderr"] ?: ""),
        )
    }

    fun captureSystemLogcat(
        filterSpec: String,
        clearBefore: Boolean,
        timeoutMs: Long = 20000L,
        maxOutputBytes: Int = 262144,
    ): Map<String, Any> {
        val boundedTimeoutMs = timeoutMs.coerceIn(1000L, 120000L)
        val boundedMaxOutputBytes = maxOutputBytes.coerceIn(4096, 524288)
        if (clearBefore) {
            runProcess(
                command = listOf("logcat", "-c"),
                timeoutMs = 5000L,
                maxOutputBytes = 16384,
            )
        }
        val command = mutableListOf("logcat", "-d")
        val parts = filterSpec.trim()
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() }
        if (parts.isNotEmpty()) {
            command.addAll(parts)
        }
        val result = runProcess(
            command = command,
            timeoutMs = boundedTimeoutMs,
            maxOutputBytes = boundedMaxOutputBytes,
        )
        return linkedMapOf(
            "ok" to (result["ok"] == true),
            "command" to command.joinToString(" "),
            "workingDirectory" to "/",
            "exitCode" to (result["exitCode"] ?: -1),
            "timedOut" to (result["timedOut"] == true),
            "stdout" to (result["stdout"] ?: ""),
            "stderr" to (result["stderr"] ?: ""),
            "timeoutMs" to boundedTimeoutMs,
            "maxOutputBytes" to boundedMaxOutputBytes,
        )
    }

    fun captureRootLogcat(
        filterSpec: String,
        clearBefore: Boolean,
        timeoutMs: Long = 20000L,
        maxOutputBytes: Int = 262144,
    ): Map<String, Any> {
        val command = buildLogcatCommand(filterSpec, clearBefore)
        val result = runRootCommand(
            command = command,
            timeoutMs = timeoutMs,
            maxOutputBytes = maxOutputBytes,
        )
        return linkedMapOf(
            "ok" to (result["ok"] == true),
            "command" to "su -c $command",
            "workingDirectory" to "/",
            "exitCode" to (result["exitCode"] ?: -1),
            "timedOut" to (result["timedOut"] == true),
            "stdout" to (result["stdout"] ?: ""),
            "stderr" to (result["stderr"] ?: ""),
            "timeoutMs" to timeoutMs.coerceIn(1000L, 120000L),
            "maxOutputBytes" to maxOutputBytes.coerceIn(4096, 524288),
        )
    }

    private fun canReadSystemLogcat(): Boolean {
        val result = runProcess(
            command = listOf("logcat", "-d", "-t", "1"),
            timeoutMs = 4000L,
            maxOutputBytes = 4096,
        )
        return result["ok"] == true
    }

    private fun isRootAvailable(): Boolean {
        if (File("/system/xbin/su").exists() || File("/system/bin/su").exists()) {
            return true
        }
        val result = runProcess(
            command = listOf("sh", "-c", "command -v su"),
            timeoutMs = 3000L,
            maxOutputBytes = 1024,
        )
        return result["ok"] == true
    }

    private fun buildLogcatCommand(filterSpec: String, clearBefore: Boolean): String {
        val parts = filterSpec.trim()
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() }
        val logcatCommand = buildString {
            append("logcat -d")
            if (parts.isNotEmpty()) {
                append(' ')
                append(parts.joinToString(" ") { shellQuote(it) })
            }
        }
        if (!clearBefore) {
            return logcatCommand
        }
        return "logcat -c && $logcatCommand"
    }

    private fun runRootCommand(
        command: String,
        timeoutMs: Long,
        maxOutputBytes: Int,
    ): Map<String, Any> {
        return runProcess(
            command = listOf("su", "-c", command),
            timeoutMs = timeoutMs.coerceIn(1000L, 120000L),
            maxOutputBytes = maxOutputBytes.coerceIn(4096, 524288),
        )
    }

    private fun runProcess(
        command: List<String>,
        timeoutMs: Long,
        maxOutputBytes: Int,
    ): Map<String, Any> {
        return try {
            val started = ProcessBuilder(command)
                .redirectErrorStream(false)
                .start()
            val finished = started.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
            if (!finished) {
                started.destroy()
                if (started.isAlive) started.destroyForcibly()
            }
            val stdout = readStreamLimited(started.inputStream, maxOutputBytes)
            val stderr = readStreamLimited(started.errorStream, maxOutputBytes)
            val exitCode = if (finished) started.exitValue() else -1
            linkedMapOf(
                "ok" to (finished && exitCode == 0),
                "exitCode" to exitCode,
                "timedOut" to !finished,
                "stdout" to stdout,
                "stderr" to stderr,
            )
        } catch (error: Exception) {
            linkedMapOf(
                "ok" to false,
                "exitCode" to -1,
                "timedOut" to false,
                "stdout" to "",
                "stderr" to (error.message ?: "Process execution failed."),
            )
        }
    }

    private fun readStreamLimited(stream: InputStream, maxBytes: Int): String {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            val count = stream.read(buffer)
            if (count <= 0) break
            val remaining = maxBytes - output.size()
            if (remaining <= 0) break
            output.write(buffer, 0, count.coerceAtMost(remaining))
        }
        return output.toString(Charsets.UTF_8.name())
    }

    private fun trimToBytes(text: String, maxOutputBytes: Int): String {
        val bytes = text.toByteArray(Charsets.UTF_8)
        if (bytes.size <= maxOutputBytes) {
            return text
        }
        return bytes.copyOf(maxOutputBytes).toString(Charsets.UTF_8)
    }

    private fun extractResultBundle(extras: Bundle?): Bundle? {
        if (extras == null) return null
        val direct = extras.getBundle(TERMUX_RESULT_BUNDLE)
        if (direct != null) return direct
        for (key in extras.keySet()) {
            val value = extras.get(key)
            if (value is Bundle) {
                return value
            }
        }
        return null
    }

    private fun isPermissionGranted(context: Context, permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun launchIntentFor(context: Context, packageName: String): Intent? {
        return context.packageManager.getLaunchIntentForPackage(packageName)
    }

    private fun shellQuote(value: String): String {
        return "'" + value.replace("'", "'\"'\"'") + "'"
    }

    private data class PendingTermuxExecution(
        val latch: CountDownLatch,
        val command: String,
        val workingDirectory: String,
        val maxOutputBytes: Int,
        val timeoutMs: Long,
        @Volatile var result: Map<String, Any>? = null,
    )
}
