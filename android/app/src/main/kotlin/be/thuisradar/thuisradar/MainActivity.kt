package be.thuisradar.thuisradar

import android.os.Bundle
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // De Flutter-engine leeft los van dit scherm. Veegt iemand de app weg uit
    // "Recente apps", dan sluit Android enkel het scherm: de engine (en dus het
    // delen van de locatie, met zijn voorgronddienst) loopt door. Komt het
    // scherm terug, dan hangt het zich aan dezelfde, draaiende engine.
    // Een gecachte engine (en niet provideFlutterEngine): enkel die wordt door
    // Flutter niet samen met het scherm vernietigd.
    override fun onCreate(savedInstanceState: Bundle?) {
        ensureEngine()
        super.onCreate(savedInstanceState)
    }

    override fun getCachedEngineId(): String = ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    private fun ensureEngine() {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(ENGINE_ID) != null) return
        // Debugvlaggen van `flutter run` (bv. start-paused) komen via de intent.
        val engine = FlutterEngine(applicationContext, FlutterShellArgs.fromIntent(intent).toArray())
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        cache.put(ENGINE_ID, engine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Terug" op het hoofdscherm: naar de achtergrond in plaats van sluiten,
        // zodat het delen van de locatie doorloopt (zie AppBackground in Dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "hasSmsSim" -> {
                        val telephony = getSystemService(TELEPHONY_SERVICE) as? TelephonyManager
                        val hasSim = if (
                            !packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION) ||
                            telephony == null
                        ) {
                            false
                        } else {
                            val states = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                (0 until telephony.phoneCount).map(telephony::getSimState)
                            } else {
                                listOf(telephony.simState)
                            }
                            states.any {
                                it != TelephonyManager.SIM_STATE_ABSENT && it != TelephonyManager.SIM_STATE_UNKNOWN
                            }
                        }
                        result.success(hasSim)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // De engine overleeft dit scherm: laat het kanaal niet naar een
        // gesloten scherm wijzen.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val ENGINE_ID = "thuisradar_main"
        const val CHANNEL = "be.thuisradar/app"
    }
}
