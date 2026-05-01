package com.yuandex

import android.content.Context
import com.android.apksig.ApkVerifier
import jadx.api.JadxArgs
import jadx.api.JadxDecompiler
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.lib.Constants
import java.io.File

object EmbeddedDevToolkitManager {
    fun getStatus(context: Context): Map<String, Any> {
        val workspaceRoot = LocalRuntimeManager.activeExecutionDirectory(context)
        val supportsGit = true
        val supportsJadx = true
        val supportsApkSig = true
        return linkedMapOf(
            "supported" to true,
            "workspaceRoot" to workspaceRoot.absolutePath,
            "gitAvailable" to supportsGit,
            "jadxAvailable" to supportsJadx,
            "apkSigAvailable" to supportsApkSig,
            "gitVersionLabel" to "JGit (内置)",
            "jadxVersionLabel" to "jadx-core (内置)",
            "apkSigVersionLabel" to "apksig (内置)",
            "lastError" to "",
        )
    }

    fun inspectGitRepository(context: Context, repoPath: String): Map<String, Any> {
        require(repoPath.isNotBlank()) { "repoPath is required." }
        val root = File(repoPath)
        require(root.exists()) { "Repository path does not exist." }
        require(root.isDirectory) { "Repository path is not a directory." }

        val gitDir = File(root, ".git")
        require(gitDir.exists()) { "No .git directory found in repository path." }

        Git.open(root).use { git ->
            val repo = git.repository
            val branch = repo.branch.orEmpty()
            val head = repo.resolve(Constants.HEAD)?.name().orEmpty()
            val status = git.status().call()
            return linkedMapOf(
                "ok" to true,
                "repoPath" to root.absolutePath,
                "branch" to branch,
                "head" to head,
                "isClean" to status.isClean,
                "added" to status.added.toSortedSet().toList(),
                "changed" to status.changed.toSortedSet().toList(),
                "modified" to status.modified.toSortedSet().toList(),
                "missing" to status.missing.toSortedSet().toList(),
                "removed" to status.removed.toSortedSet().toList(),
                "untracked" to status.untracked.toSortedSet().toList(),
                "conflicting" to status.conflicting.toSortedSet().toList(),
            )
        }
    }

    fun decompileApkWithEmbeddedJadx(
        context: Context,
        apkPath: String,
        outputLabel: String,
    ): Map<String, Any> {
        require(apkPath.isNotBlank()) { "apkPath is required." }
        val apkFile = File(apkPath)
        require(apkFile.exists()) { "APK file does not exist." }
        require(apkFile.isFile) { "APK path is not a file." }

        val workspaceRoot = LocalRuntimeManager.activeExecutionDirectory(context)
        val safeLabel = outputLabel.ifBlank { apkFile.nameWithoutExtension }
            .replace(Regex("[^a-zA-Z0-9._-]"), "_")
            .take(64)
            .ifBlank { "jadx_output" }
        val outputDir = File(File(workspaceRoot, "embedded_tools"), "jadx_$safeLabel")
        if (outputDir.exists()) {
            outputDir.deleteRecursively()
        }
        outputDir.mkdirs()

        val args = JadxArgs().apply {
            inputFiles = listOf(apkFile)
            outDir = outputDir
            isSkipResources = false
            isShowInconsistentCode = true
            isRespectBytecodeAccModifiers = true
        }
        val decompiler = JadxDecompiler(args)
        decompiler.load()
        decompiler.save()

        val javaDir = File(outputDir, "sources")
        val resDir = File(outputDir, "resources")
        return linkedMapOf(
            "ok" to true,
            "apkPath" to apkFile.absolutePath,
            "outputDir" to outputDir.absolutePath,
            "sourcesDir" to javaDir.absolutePath,
            "resourcesDir" to resDir.absolutePath,
            "backend" to "embedded_jadx",
        )
    }

    fun verifyApkSignature(apkPath: String): Map<String, Any> {
        require(apkPath.isNotBlank()) { "apkPath is required." }
        val apkFile = File(apkPath)
        require(apkFile.exists()) { "APK file does not exist." }
        require(apkFile.isFile) { "APK path is not a file." }

        val result = ApkVerifier.Builder(apkFile).build().verify()
        val signerSummaries = result.signerCertificates.map { certificate ->
            linkedMapOf(
                "subject" to certificate.subjectX500Principal.name,
                "issuer" to certificate.issuerX500Principal.name,
            )
        }

        return linkedMapOf(
            "ok" to true,
            "apkPath" to apkFile.absolutePath,
            "verified" to result.isVerified,
            "verifiedUsingV1Scheme" to result.isVerifiedUsingV1Scheme,
            "verifiedUsingV2Scheme" to result.isVerifiedUsingV2Scheme,
            "verifiedUsingV3Scheme" to result.isVerifiedUsingV3Scheme,
            "verifiedUsingV31Scheme" to result.isVerifiedUsingV31Scheme,
            "verifiedUsingV4Scheme" to result.isVerifiedUsingV4Scheme,
            "signers" to signerSummaries,
            "errors" to result.errors.map { it.toString() },
            "warnings" to result.warnings.map { it.toString() },
        )
    }
}
