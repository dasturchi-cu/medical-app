package com.example.medical_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // FCM fon bildirishnomalari Flutter ishga tushishidan oldin ham shu kanal orqali chiqsin (heads-up).
        ensureHighImportancePushChannel()
        super.onCreate(savedInstanceState)
    }

    private fun ensureHighImportancePushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channelId = "neuroscience_push"
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val importance =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                NotificationManager.IMPORTANCE_MAX
            } else {
                NotificationManager.IMPORTANCE_HIGH
            }
        val channel =
            NotificationChannel(channelId, "Bildirishnomalar", importance).apply {
                description = "Admin va tizim bildirishnomalari"
                enableVibration(true)
                setShowBadge(true)
                val attrs =
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, attrs)
            }
        manager.createNotificationChannel(channel)
    }
}
