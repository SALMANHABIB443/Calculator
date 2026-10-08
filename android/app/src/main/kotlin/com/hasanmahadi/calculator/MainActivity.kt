package com.hasanmahadi.calculator

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "calculator/storage",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // StatFs on the data partition: what the phone ships with and
                // how much of it is still free, in bytes.
                "getInternalStorage" -> result.success(
                    statOf(Environment.getDataDirectory().path),
                )
                // The external-files list's first entry is the phone's own
                // emulated storage; anything after it is a removable volume.
                // Absent or unmounted means no card in the slot.
                "getSdCard" -> {
                    val dirs = context.getExternalFilesDirs(null)
                    val secondary = dirs.drop(1).firstOrNull {
                        it != null &&
                            Environment.getExternalStorageState(it) ==
                            Environment.MEDIA_MOUNTED
                    }
                    if (secondary == null) result.success(null)
                    else result.success(statOf(secondary.path))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun statOf(path: String): Map<String, Long> {
        val stat = StatFs(path)
        val total = stat.blockCountLong * stat.blockSizeLong
        val free = stat.availableBlocksLong * stat.blockSizeLong
        return mapOf("totalBytes" to total, "freeBytes" to free)
    }
}
