package be.thuisradar.thuisradar

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Terug" op het hoofdscherm: naar de achtergrond in plaats van sluiten,
        // zodat het delen van de locatie doorloopt (zie AppBackground in Dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be.thuisradar/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
