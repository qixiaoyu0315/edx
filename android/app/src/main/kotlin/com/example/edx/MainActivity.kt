package com.example.edx

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.edx/backup"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    try {
                        val name = call.argument<String>("name") ?: return@setMethodCallHandler result.error("ARG", "name is required", null)
                        val bytes = call.argument<ByteArray>("bytes") ?: return@setMethodCallHandler result.error("ARG", "bytes is required", null)
                        val mime = call.argument<String>("mime") ?: "application/zip"

                        val savedPath = saveToDownloads(name, bytes, mime)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(fileName: String, data: ByteArray, mime: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = applicationContext.contentResolver
            val uri: Uri? = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            requireNotNull(uri) { "Failed to create MediaStore record" }
            resolver.openOutputStream(uri).use { out ->
                requireNotNull(out) { "Failed to open output stream" }
                out.write(data)
                out.flush()
            }
            uri.toString()
        } else {
            // Legacy: write directly to public Downloads directory
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloads.exists()) downloads.mkdirs()
            val file = File(downloads, fileName)
            FileOutputStream(file).use { out: OutputStream ->
                out.write(data)
                out.flush()
            }
            file.absolutePath
        }
    }
}
