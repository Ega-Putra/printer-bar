package com.egaputra.thermal_print

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// Menambah discovery Bluetooth klasik (inquiry scan) yang tidak disediakan
/// package print_bluetooth_thermal — agar daftar perangkat hanya berisi
/// perangkat yang AKTIF terdeteksi di sekitar, bukan riwayat pairing.
///
/// Dart: MethodChannel "com.egaputra.thermal_print/bt_discovery"
/// (startDiscovery / cancelDiscovery), hasil via EventChannel
/// "com.egaputra.thermal_print/bt_discovery_events".
class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.egaputra.thermal_print/bt_discovery"
    private val eventChannelName = "com.egaputra.thermal_print/bt_discovery_events"
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDiscovery" -> result.success(startDiscovery())
                    "cancelDiscovery" -> {
                        cancelDiscovery()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun startDiscovery(): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        if (!adapter.isEnabled) return false
        cancelDiscovery() // hentikan scan lama bila masih jalan
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        @Suppress("DEPRECATION")
                        val device: BluetoothDevice? =
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        if (device != null) {
                            val name = try {
                                device.name ?: ""
                            } catch (_: SecurityException) {
                                ""
                            }
                            eventSink?.success(
                                mapOf("name" to name, "mac" to device.address)
                            )
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        eventSink?.success(mapOf("event" to "finished"))
                    }
                }
            }
        }
        receiver = r
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        // Wajib di Android 13+: tentukan exported / not-exported.
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(r, filter)
        }
        return adapter.startDiscovery()
    }

    @Suppress("DEPRECATION")
    private fun cancelDiscovery() {
        try {
            BluetoothAdapter.getDefaultAdapter()?.cancelDiscovery()
        } catch (_: Exception) {
        }
        try {
            receiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {
        }
        receiver = null
    }

    override fun onDestroy() {
        cancelDiscovery()
        super.onDestroy()
    }
}
