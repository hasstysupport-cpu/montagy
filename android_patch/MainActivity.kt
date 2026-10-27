package com.montagy.app

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private var recorder: MediaRecorder? = null
    private var outFile: String? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "montagy/record")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val path = call.argument<String>("path")!!
                            // امسح ملفاً قديماً إن وجد
                            val f = File(path)
                            if (f.exists()) f.delete()
                            stopRecorder()
                            val r = if (Build.VERSION.SDK_INT >= 31) {
                                MediaRecorder(this)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }
                            r.setAudioSource(MediaRecorder.AudioSource.MIC)
                            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            r.setAudioEncodingBitRate(128000)
                            r.setAudioSamplingRate(44100)
                            r.setAudioChannels(1)
                            r.setOutputFile(path)
                            r.prepare()
                            r.start()
                            recorder = r
                            outFile = path
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            stopRecorder()
                            val p = outFile
                            outFile = null
                            if (p != null && File(p).exists()) {
                                result.success(p)
                            } else {
                                result.success(null)
                            }
                        } catch (e: Exception) {
                            result.error("STOP_FAILED", e.message, null)
                        }
                    }
                    "cancel" -> {
                        try {
                            val p = outFile
                            stopRecorder()
                            outFile = null
                            if (p != null) {
                                val f = File(p)
                                if (f.exists()) f.delete()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CANCEL_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun stopRecorder() {
        try {
            recorder?.stop()
        } catch (_: Exception) {
        }
        try {
            recorder?.release()
        } catch (_: Exception) {
        }
        recorder = null
    }

    override fun onDestroy() {
        stopRecorder()
        super.onDestroy()
    }
}
