package com.example.medical_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Butun ilovada skrinshot va ekranni video qilib olishni taqiqlaymiz.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
