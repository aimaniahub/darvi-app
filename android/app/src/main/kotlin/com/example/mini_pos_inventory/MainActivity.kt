package com.example.mini_pos_inventory

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.darvi.billing/bluetooth_printer"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPairedDevices" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    if (adapter == null || !adapter.isEnabled) {
                        result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off or not available", null)
                        return@setMethodCallHandler
                    }

                    val paired = adapter.bondedDevices
                    val list = mutableListOf<Map<String, Any>>()
                    for (device in paired) {
                        list.add(
                            mapOf(
                                "name" to (device.name ?: "Unknown"),
                                "address" to device.address
                            )
                        )
                    }
                    result.success(list)
                }

                "connect" -> {
                    val address = call.argument<String>("address")
                    if (address.isNullOrEmpty()) {
                        result.error("INVALID_ADDRESS", "MAC Address is required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            disconnectSocket()
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            adapter.cancelDiscovery()
                            val device: BluetoothDevice = adapter.getRemoteDevice(address)
                            val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                            socket.connect()
                            bluetoothSocket = socket
                            outputStream = socket.outputStream

                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            disconnectSocket()
                            runOnUiThread {
                                result.error("CONNECT_FAILED", "Failed to connect to $address: ${e.message}", null)
                            }
                        }
                    }.start()
                }

                "writeChunk" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || outputStream == null) {
                        result.error("NOT_CONNECTED", "Printer is not connected or bytes empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        outputStream?.write(bytes)
                        outputStream?.flush()
                        result.success(true)
                    } catch (e: Exception) {
                        disconnectSocket()
                        result.error("WRITE_FAILED", "Error writing to printer: ${e.message}", null)
                    }
                }

                "disconnect" -> {
                    disconnectSocket()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun disconnectSocket() {
        try {
            outputStream?.close()
        } catch (_: Exception) {}
        try {
            bluetoothSocket?.close()
        } catch (_: Exception) {}
        outputStream = null
        bluetoothSocket = null
    }

    override fun onDestroy() {
        disconnectSocket()
        super.onDestroy()
    }
}
