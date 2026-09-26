package com.yamaguchi.shiori

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.yamaguchi.shiori/browser"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("ERROR", "URL is null", null)
                        }
                    }
                    "createShortcut" -> {
                        try {
                            val iconBytes = call.argument<ByteArray>("iconBytes")
                            val shortcutIntent = Intent(applicationContext, MainActivity::class.java)
                            shortcutIntent.action = Intent.ACTION_MAIN

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val shortcutManager = getSystemService(ShortcutManager::class.java)
                                if (shortcutManager != null && shortcutManager.isRequestPinShortcutSupported) {
                                    val icon = if (iconBytes != null) {
                                        val bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                                        Icon.createWithBitmap(bitmap)
                                    } else {
                                        Icon.createWithResource(this, R.mipmap.ic_launcher)
                                    }
                                    val pinShortcutInfo = ShortcutInfo.Builder(this, "shiori_home")
                                        .setShortLabel("栞")
                                        .setLongLabel("栞 - 読書管理サービス")
                                        .setIcon(icon)
                                        .setIntent(shortcutIntent)
                                        .build()
                                    shortcutManager.requestPinShortcut(pinShortcutInfo, null)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            } else {
                                @Suppress("DEPRECATION")
                                val intent = Intent("com.android.launcher.action.INSTALL_SHORTCUT")
                                intent.putExtra(Intent.EXTRA_SHORTCUT_INTENT, shortcutIntent)
                                intent.putExtra(Intent.EXTRA_SHORTCUT_NAME, "栞")
                                intent.putExtra("duplicate", false)
                                sendBroadcast(intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
