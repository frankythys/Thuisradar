package be.thuisradar.thuisradar

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Sms'en en bellen voor de noodcontacten (zie EmergencyPhone in Dart).
 *
 * - `status`: heeft deze gsm een simkaart die klaar is?
 * - `sendSms`: verstuurt en wacht op het echte resultaat van het netwerk;
 *   fout `no_service` zonder simkaart of netwerk.
 * - `call`: belt meteen; fout `no_service` zonder simkaart.
 *
 * Zonder de toestemming SEND_SMS / CALL_PHONE de fout `no_permission`; Dart
 * opent dan de berichten- of telefoon-app.
 */
object EmergencyChannel {
    private const val SMS_TIMEOUT_MS = 30_000L
    private var nextRequest = 0

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "be.thuisradar/emergency").setMethodCallHandler { call, result ->
            if (call.method == "status") {
                result.success(mapOf("simReady" to simReady(context)))
                return@setMethodCallHandler
            }
            val phone = call.argument<String>("phone")
            if (phone.isNullOrBlank()) {
                result.error("no_phone", "Geen telefoonnummer", null)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "sendSms" -> sendSms(context, phone, call.argument<String>("text").orEmpty(), result)
                    "call" -> call(context, phone, result)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("failed", error.message, null)
            }
        }
    }

    private fun sendSms(context: Context, phone: String, text: String, result: MethodChannel.Result) {
        if (!granted(context, Manifest.permission.SEND_SMS)) {
            result.error("no_permission", "Geen toestemming om te sms'en", null)
            return
        }
        if (!simReady(context)) {
            result.error("no_service", "Geen simkaart of gsm-netwerk", null)
            return
        }
        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        // Een lange sms (de kaartlink) gaat in stukken; elk stuk meldt zijn
        // resultaat. Pas als alle stukken vertrokken zijn, is de sms verstuurd.
        val parts = sms.divideMessage(text)
        val request = nextRequest++
        val action = "be.thuisradar.SMS_SENT.$request"
        val handler = Handler(Looper.getMainLooper())
        var remaining = parts.size
        var answered = false
        lateinit var receiver: BroadcastReceiver

        fun finish(error: String?, message: String?) {
            if (answered) return
            answered = true
            handler.removeCallbacksAndMessages(null)
            try {
                context.unregisterReceiver(receiver)
            } catch (alreadyGone: IllegalArgumentException) {
                // Al afgemeld: niets te doen.
            }
            if (error == null) result.success(null) else result.error(error, message, null)
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (resultCode) {
                    Activity.RESULT_OK -> if (--remaining <= 0) finish(null, null)
                    SmsManager.RESULT_ERROR_NO_SERVICE, SmsManager.RESULT_ERROR_RADIO_OFF ->
                        finish("no_service", "Geen gsm-netwerk")
                    else -> finish("failed", "Sms mislukt (code $resultCode)")
                }
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        val sent = ArrayList<PendingIntent>()
        for (index in parts.indices) {
            val intent = Intent(action).setPackage(context.packageName)
            sent.add(
                PendingIntent.getBroadcast(
                    context,
                    request * 16 + index,
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT,
                ),
            )
        }
        handler.postDelayed({ finish("timeout", "Geen antwoord van het netwerk") }, SMS_TIMEOUT_MS)
        try {
            sms.sendMultipartTextMessage(phone, null, parts, sent, null)
        } catch (error: Exception) {
            finish("failed", error.message)
        }
    }

    private fun call(context: Context, phone: String, result: MethodChannel.Result) {
        if (!granted(context, Manifest.permission.CALL_PHONE)) {
            result.error("no_permission", "Geen toestemming om te bellen", null)
            return
        }
        if (!simReady(context)) {
            result.error("no_service", "Geen simkaart of gsm-netwerk", null)
            return
        }
        val intent = Intent(Intent.ACTION_CALL, Uri.fromParts("tel", phone, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        result.success(null)
    }

    /** Een simkaart die klaar is om te bellen en te sms'en. */
    private fun simReady(context: Context): Boolean {
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) return false
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return false
        return telephony.simState == TelephonyManager.SIM_STATE_READY
    }

    private fun granted(context: Context, permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}
