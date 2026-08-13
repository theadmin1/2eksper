package com.synaptropic.twoeksper

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val createPdfRequestCode = 24681
    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.synaptropic.twoeksper/pdf_file"
        ).setMethodCallHandler { call, result ->
            val bytes = call.argument<ByteArray>("bytes")
            val filename = File(
                call.argument<String>("filename")?.takeIf { it.isNotBlank() }
                ?: "2EKSPER-Rapor.pdf"
            ).name
            if (bytes == null || bytes.isEmpty()) {
                result.error("PDF_EMPTY", "PDF verisi boş.", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "savePdf" -> {
                    if (pendingResult != null) {
                        result.error("PDF_SAVE_BUSY", "Başka bir PDF kaydetme işlemi devam ediyor. Lütfen bekleyin.", null)
                        return@setMethodCallHandler
                    }
                    pendingBytes = bytes
                    pendingResult = result
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        startActivityForResult(intent, createPdfRequestCode)
                    } catch (error: Exception) {
                        pendingBytes = null
                        pendingResult = null
                        android.util.Log.e("PdfFileService", "Save intent failed", error)
                        result.error("PDF_SAVE_FAILED", "Dosya kaydetme ekranı açılamadı: ${error.message}", null)
                    }
                }
                "sharePdf" -> sharePdf(bytes, filename, call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun sharePdf(
        bytes: ByteArray,
        filename: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        try {
            val shareDirectory = File(cacheDir, "pdf_share").apply { mkdirs() }
            if (!shareDirectory.isDirectory) {
                throw IllegalStateException("PDF paylaşım klasörü oluşturulamadı.")
            }
            val file = File(shareDirectory, filename)
            FileOutputStream(file, false).use { stream ->
                stream.write(bytes)
                stream.flush()
            }
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.pdf.files",
                file
            )
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject") ?: "2EKSPER Raporu")
                putExtra(Intent.EXTRA_TEXT, call.argument<String>("body") ?: "")
                clipData = ClipData.newUri(contentResolver, filename, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(shareIntent, "PDF raporunu paylaş")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            result.success(true)
        } catch (error: Exception) {
            android.util.Log.e("PdfFileService", "Share failed", error)
            result.error("PDF_SHARE_FAILED", "PDF paylaşılamadı: ${error.message}", null)
        }
    }

    @Deprecated("Deprecated in Android SDK; required for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createPdfRequestCode) return

        val result = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null

        if (result == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }

        try {
            val stream = contentResolver.openOutputStream(uri, "rwt")
                ?: throw IllegalStateException("Seçilen hedef dosya açılamadı veya erişim izni yok.")
            stream.use {
                it.write(bytes ?: throw IllegalStateException("PDF verisi hafızada bulunamadı."))
                it.flush()
            }
            result.success(true)
        } catch (error: Exception) {
            android.util.Log.e("PdfFileService", "Save failed in onActivityResult", error)
            result.error("PDF_SAVE_FAILED", "PDF dosyası kaydedilemedi: ${error.message}", null)
        }
    }
}
