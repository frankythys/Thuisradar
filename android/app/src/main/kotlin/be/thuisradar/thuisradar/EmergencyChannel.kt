package be.thuisradar.thuisradar

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Sms'en en bellen voor de noodcontacten (zie EmergencyPhone in Dart). Werkt
 * enkel met de toestemmingen SEND_SMS en CALL_PHONE; anders een fout, en Dart
 * opent dan de berichten- of telefoon-app.
 */
object EmergencyChannel {
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "be.thuisradar/emergency").setMethodCallHandler { call, result ->
            val phone = call.argument<String>("phone")
            if (phone.isNullOrBlank()) {
                result.error("no_phone", "Geen telefoonnummer", null)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "sendSms" -> {
                        if (!granted(context, Manifest.permission.SEND_SMS)) {
                            result.error("no_permission", "Geen toestemming om te sms'en", null)
                            return@setMethodCallHandler
                        }
                        val text = call.argument<String>("text").orEmpty()
                        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            context.getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        // Een lange sms (de kaartlink) wordt in stukken verstuurd.
                        sms.sendMultipartTextMessage(phone, null, sms.divideMessage(text), null, null)
                        result.success(null)
                    }
                    "call" -> {
                        if (!granted(context, Manifest.permission.CALL_PHONE)) {
                            result.error("no_permission", "Geen toestemming om te bellen", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_CALL, Uri.fromParts("tel", phone, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("failed", error.message, null)
            }
        }
    }

    private fun granted(context: Context, permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}
