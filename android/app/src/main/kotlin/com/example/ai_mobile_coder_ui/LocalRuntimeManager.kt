package com.yuandex

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import java.io.File
import java.io.IOException
import java.security.MessageDigest

object LocalRuntimeManager {
    private const val PREFS_NAME = "local_runtime_state"
    private const val KEY_RUNNING = "running"
    private const val KEY_ACTIVE_WORKSPACE_ID = "active_workspace_id"
    private const val KEY_ACTIVE_WORKSPACE_PATH = "active_workspace_path"
    private const val KEY_LAST_PREPARED_PROJECT_PATH = "last_prepared_project_path"
    private const val KEY_LAST_ERROR = "last_error"
    private const val KEY_MIRRORED_FILE_COUNT = "mirrored_file_count"
    private const val KEY_MIRRORED_DIRECTORY_COUNT = "mirrored_directory_count"

    private val skipDirectories = setOf(
        ".dart_tool",
        "build",
        ".gradle",
        ".idea",
        "node_modules"
    )

    fun getStatus(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        ensureRuntimeDirectories(context)
        val shellSnapshot = LocalShellSessionManager.getSnapshot(context)
        val shellWorkingDirectory = shellSnapshot["workingDirectory"]?.toString().orEmpty()
        val shellLastError = shellSnapshot["lastError"]?.toString().orEmpty()
        return linkedMapOf(
            "supported" to true,
            "isRunning" to prefs.getBoolean(KEY_RUNNING, false),
            "runtimeRoot" to runtimeRoot(context).absolutePath,
            "workspacesRoot" to workspacesRoot(context).absolutePath,
            "activeWorkspaceId" to prefs.getString(KEY_ACTIVE_WORKSPACE_ID, "").orEmpty(),
            "activeWorkspacePath" to prefs.getString(KEY_ACTIVE_WORKSPACE_PATH, "").orEmpty(),
            "lastPreparedProjectPath" to prefs.getString(KEY_LAST_PREPARED_PROJECT_PATH, "").orEmpty(),
            "lastError" to prefs.getString(KEY_LAST_ERROR, "").orEmpty(),
            "mirroredFileCount" to prefs.getInt(KEY_MIRRORED_FILE_COUNT, 0),
            "mirroredDirectoryCount" to prefs.getInt(KEY_MIRRORED_DIRECTORY_COUNT, 0),
            "shellRunning" to (shellSnapshot["isRunning"] == true),
            "shellWorkingDirectory" to shellWorkingDirectory,
            "shellLastError" to shellLastError,
        )
    }

    fun startRuntime(context: Context) {
        ensureRuntimeDirectories(context)
        startRuntimeStateOnly(context)
        clearLastError(context)
        val intent = Intent(context, LocalRuntimeService::class.java).apply {
            action = LocalRuntimeService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, intent)
        } else {
            context.startService(intent)
        }
    }

    fun stopRuntime(context: Context) {
        LocalShellSessionManager.stopSession(context)
        stopRuntimeStateOnly(context)
        val intent = Intent(context, LocalRuntimeService::class.java).apply {
            action = LocalRuntimeService.ACTION_STOP
        }
        context.startService(intent)
    }

    fun prepareWorkspace(context: Context, projectRootPath: String): Map<String, Any> {
        val sourceRoot = File(projectRootPath.trim())
        require(sourceRoot.exists()) { "Project root does not exist." }
        require(sourceRoot.isDirectory) { "Project root is not a directory." }

        ensureRuntimeDirectories(context)
        LocalShellSessionManager.stopSession(context)
        val workspaceId = "ws_${stableHash(sourceRoot.absolutePath)}"
        val workspaceRoot = File(workspacesRoot(context), workspaceId)
        val mirrorRoot = File(workspaceRoot, "source")
        if (workspaceRoot.exists()) {
            workspaceRoot.deleteRecursively()
        }
        if (!mirrorRoot.mkdirs() && !mirrorRoot.exists()) {
            throw IOException("Failed to create local workspace mirror.")
        }

        val stats = CopyStats()
        copyDirectoryRecursively(sourceRoot, mirrorRoot, stats)

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACTIVE_WORKSPACE_ID, workspaceId)
            .putString(KEY_ACTIVE_WORKSPACE_PATH, mirrorRoot.absolutePath)
            .putString(KEY_LAST_PREPARED_PROJECT_PATH, sourceRoot.absolutePath)
            .putString(KEY_LAST_ERROR, "")
            .putInt(KEY_MIRRORED_FILE_COUNT, stats.fileCount)
            .putInt(KEY_MIRRORED_DIRECTORY_COUNT, stats.directoryCount)
            .apply()

        return getStatus(context)
    }

    fun recordLastError(context: Context, error: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_ERROR, error)
            .apply()
    }

    fun startRuntimeStateOnly(context: Context) {
        updateRunningState(context, true)
    }

    fun stopRuntimeStateOnly(context: Context) {
        updateRunningState(context, false)
    }

    private fun ensureRuntimeDirectories(context: Context) {
        runtimeRoot(context).mkdirs()
        workspacesRoot(context).mkdirs()
    }

    private fun runtimeRoot(context: Context): File {
        return File(context.filesDir, "local_runtime")
    }

    private fun workspacesRoot(context: Context): File {
        return File(runtimeRoot(context), "workspaces")
    }

    fun defaultExecutionDirectory(context: Context): File {
        ensureRuntimeDirectories(context)
        return File(runtimeRoot(context), "workspace_boot")
    }

    fun activeExecutionDirectory(context: Context): File {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val path = prefs.getString(KEY_ACTIVE_WORKSPACE_PATH, "").orEmpty().trim()
        if (path.isEmpty()) {
            return defaultExecutionDirectory(context)
        }
        return File(path)
    }

    private fun clearLastError(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_ERROR, "")
            .apply()
    }

    private fun updateRunningState(context: Context, isRunning: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_RUNNING, isRunning)
            .apply()
    }

    private fun stableHash(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-1").digest(value.toByteArray())
        return bytes.joinToString(separator = "") { byte -> "%02x".format(byte) }.take(12)
    }

    private fun copyDirectoryRecursively(source: File, target: File, stats: CopyStats) {
        val children = source.listFiles().orEmpty()
        for (child in children) {
            if (child.isDirectory && skipDirectories.contains(child.name)) {
                continue
            }
            val nextTarget = File(target, child.name)
            if (child.isDirectory) {
                if (!nextTarget.exists()) {
                    nextTarget.mkdirs()
                }
                stats.directoryCount += 1
                copyDirectoryRecursively(child, nextTarget, stats)
            } else if (child.isFile) {
                nextTarget.parentFile?.mkdirs()
                child.copyTo(nextTarget, overwrite = true)
                stats.fileCount += 1
            }
        }
    }

    private class CopyStats(
        var fileCount: Int = 0,
        var directoryCount: Int = 0
    )
}
