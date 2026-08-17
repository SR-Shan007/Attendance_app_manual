package com.example.attend_

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.example.attend_/bluetooth"
        private const val ATTENDANCE_UUID = "7A7F0001-4A56-4D3A-9C01-250000000001"

        // Arbitrary company ID for manufacturer data framing.
        // Not officially registered with Bluetooth SIG — fine for a
        // private/internal app, but be aware it's not a "real" assigned ID.
        private const val MANUFACTURER_ID = 0x02E0
    }

    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val args = call.arguments as? Map<*, *>
                    val sessionToken = args?.get("sessionToken") as? String

                    if (sessionToken.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "sessionToken is required to start advertising.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    startAdvertising(sessionToken, result)
                }

                "stopAdvertising" -> {
                    stopAdvertising()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // START BLE ADVERTISING
    // ============================================================

    private fun startAdvertising(
        sessionToken: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_ADVERTISE
            ) == PackageManager.PERMISSION_GRANTED

            if (!granted) {
                result.error(
                    "PERMISSION_DENIED",
                    "BLUETOOTH_ADVERTISE permission not granted.",
                    null
                )
                return
            }
        }

        val bluetoothManager =
            getSystemService(BLUETOOTH_SERVICE) as BluetoothManager

        val bluetoothAdapter = bluetoothManager.adapter

        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available.", null)
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off.", null)
            return
        }

        if (!bluetoothAdapter.isMultipleAdvertisementSupported) {
            result.error(
                "BLE_ADVERTISING_UNSUPPORTED",
                "This phone does not support BLE advertising.",
                null
            )
            return
        }

        bluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser

        if (bluetoothLeAdvertiser == null) {
            result.error("BLE_ADVERTISER_UNAVAILABLE", "BLE advertiser is unavailable.", null)
            return
        }

        // Avoid starting it twice.
        if (advertiseCallback != null) {
            result.success(true)
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)
            .build()

        // Token is sent as raw ASCII bytes in manufacturer data. Total
        // packet budget is 31 bytes; the 128-bit service UUID alone costs
        // 18 bytes, leaving very little room. Keep the token short
        // (6 ASCII chars fits) — if you ever change the token format,
        // recheck this budget or you'll hit ADVERTISE_FAILED_DATA_TOO_LARGE.
        val tokenBytes = sessionToken.toByteArray(Charsets.US_ASCII)

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(UUID.fromString(ATTENDANCE_UUID)))
            .addManufacturerData(MANUFACTURER_ID, tokenBytes)
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                advertiseCallback = null
                result.error(
                    "BLE_ADVERTISE_FAILED",
                    "BLE advertising failed. Error code: $errorCode",
                    null
                )
            }
        }

        bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    // ============================================================
    // STOP BLE ADVERTISING
    // ============================================================

    private fun stopAdvertising() {
        val callback = advertiseCallback
        if (callback != null) {
            bluetoothLeAdvertiser?.stopAdvertising(callback)
        }
        advertiseCallback = null
    }

    // ============================================================
    // CLEANUP
    // ============================================================

    override fun onDestroy() {
        stopAdvertising()
        super.onDestroy()
    }
}