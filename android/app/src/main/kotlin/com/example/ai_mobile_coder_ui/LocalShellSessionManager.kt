package com.example.ai_mobile_coder_ui

import android.content.Context
import java.io.BufferedWriter
import java.io.File
import java.io.InputStream
import java.io.OutputStreamWriter
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object LocalShellSessionManager {
    private const val MAX_LINES = 600

    private val lock = Any()
    private val lines = Collections.synchronizedList(mutableListOf<String>())
    private val executor = Executors.newCachedThreadPool()

    @Volatile
    private var process: Process? = null

    @Volatile
    private var writer: BufferedWriter? = null

    @Volatile
    private var activeWorkingDirectory: String = ""

    @Volatile
    private var lastError: String = ""

    private val readersStarted = AtomicBoolean(false)

    fun getSnapshot(context: Context): Map<String, Any> {
        val current = process
        val alive = current?.isAlive == true
        return linkedMapOf(
            "supported" to true,
            "isRunning" to alive,
            "workingDirectory" to activeWorkingDirectory.ifBlank {
                LocalRuntimeManager.defaultExecutionDirectory(context).absolutePath
            },
            "lastError" to lastError,
            "lines" to synchronized(lines) { lines.toList() },
        )
    }

    fun startSession(context: Context): Map<String, Any> {
        synchronized(lock) {
            if (process?.isAlive == true) {
                return getSnapshot(context)
            }

            val workingDir = LocalRuntimeManager.activeExecutionDirectory(context)
            workingDir.mkdirs()
            val started = ProcessBuilder("/system/bin/sh")
                .directory(workingDir)
                .redirectErrorStream(false)
                .start()
            process = started
            writer = BufferedWriter(OutputStreamWriter(started.outputStream))
            activeWorkingDirectory = workingDir.absolutePath
            lastError = ""
            readersStarted.set(false)
            appendSystemLine("shell session started at $activeWorkingDirectory")
            startReaders(started)
        }
        return getSnapshot(context)
    }

    fun stopSession(context: Context): Map<String, Any> {
        synchronized(lock) {
            appendSystemLine("shell session stopping")
            safelyCloseWriter()
            process?.destroy()
            process = null
            writer = null
            readersStarted.set(false)
        }
        return getSnapshot(context)
    }

    fun clearBuffer(context: Context): Map<String, Any> {
        synchronized(lines) {
            lines.clear()
            lines.add("Local shell buffer cleared.")
        }
        return getSnapshot(context)
    }

    fun sendInput(context: Context, input: String): Map<String, Any> {
        val trimmed = input.trimEnd()
        require(trimmed.isNotEmpty()) { "input is empty" }
        val snapshot = startSession(context)
        if (snapshot["isRunning"] != true) {
            throw IllegalStateException("Shell session failed to start.")
        }
        synchronized(lock) {
            val currentWriter = writer ?: throw IllegalStateException("Shell writer is not available.")
            currentWriter.write(trimmed)
            currentWriter.newLine()
            currentWriter.flush()
        }
        appendCommandLine(trimmed)
        return getSnapshot(context)
    }

    private fun startReaders(started: Process) {
        if (!readersStarted.compareAndSet(false, true)) {
            return
        }
        executor.execute { pumpStream(started.inputStream, "stdout") }
        executor.execute { pumpStream(started.errorStream, "stderr") }
        executor.execute {
            try {
                val exitCode = started.waitFor()
                appendSystemLine("shell session exited with code $exitCode")
            } catch (error: InterruptedException) {
                Thread.currentThread().interrupt()
                lastError = error.message ?: "shell session interrupted"
                appendSystemLine("shell session interrupted")
            } finally {
                synchronized(lock) {
                    safelyCloseWriter()
                    if (process === started) {
                        process = null
                    }
                    writer = null
                    readersStarted.set(false)
                }
            }
        }
    }

    private fun pumpStream(stream: InputStream, source: String) {
        val buffer = ByteArray(2048)
        var pending = ""
        try {
            while (true) {
                val count = stream.read(buffer)
                if (count <= 0) break
                val chunk = String(buffer, 0, count)
                val text = pending + chunk.replace("\r\n", "\n").replace('\r', '\n')
                val endsWithNewline = text.endsWith('\n')
                val parts = text.split('\n')
                val completed = if (endsWithNewline) parts else parts.dropLast(1)
                pending = if (endsWithNewline) "" else parts.lastOrNull().orEmpty()
                for (line in completed) {
                    appendOutputLine(line, source = source)
                }
            }
            if (pending.isNotEmpty()) {
                appendOutputLine(pending, source = source)
            }
        } catch (error: Exception) {
            lastError = error.message ?: "shell stream error"
            appendSystemLine("$source reader error: $lastError")
        }
    }

    private fun appendCommandLine(command: String) {
        appendLine("\$ $command")
    }

    private fun appendOutputLine(line: String, source: String) {
        val normalized = line.ifEmpty { " " }
        if (source == "stderr") {
            appendLine("[stderr] $normalized")
            return
        }
        appendLine(normalized)
    }

    private fun appendSystemLine(message: String) {
        appendLine("[local-shell] $message")
    }

    private fun appendLine(value: String) {
        synchronized(lines) {
            lines.add(value)
            while (lines.size > MAX_LINES) {
                lines.removeAt(0)
            }
        }
    }

    private fun safelyCloseWriter() {
        try {
            writer?.close()
        } catch (_: Exception) {
        }
    }
}
