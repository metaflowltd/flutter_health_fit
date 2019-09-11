package com.metaflow.flutterhealthfit

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.PluginRegistry.Registrar

import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.result.DataReadResponse
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.PluginRegistry
import java.text.DateFormat
import java.util.*
import java.util.concurrent.TimeUnit


class FlutterHealthFitPlugin(private val activity: Activity) : MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1

        val dataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val aggregatedDataType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA

        val TAG = FlutterHealthFitPlugin::class.java.simpleName

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val plugin = FlutterHealthFitPlugin(registrar.activity())
            registrar.addActivityResultListener(plugin)

            val channel = MethodChannel(registrar.messenger(), "flutter_health_fit")
            channel.setMethodCallHandler(plugin)
        }
    }

    private var deferredResult: Result? = null

    override fun onMethodCall(call: MethodCall, result: Result) {

        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

            "requestAuthorization" -> connect(result)

            "getBasicHealthData" -> result.success(HashMap<String, String>())

            "getActivity" -> {
                val name = call.argument<String>("name")

                when (name) {
                    "steps" -> getYesterdaysStepsTotal(result)

                    else -> {
                        val map = HashMap<String, Double>()
                        map["value"] = 0.0
                        result.success(map)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                recordData { success ->
                    Log.i(TAG, "Record data success: $success!")

                    if (success)
                        deferredResult?.success(true)
                    else
                        deferredResult?.error("no record", "Record data operation denied", null)

                    deferredResult = null
                }
            } else {
                deferredResult?.error("canceled", "User cancelled or app not authorized", null)
                deferredResult = null
            }

            return true
        }

        return false
    }

    private fun connect(result: Result) {
        val fitnessOptions = getFitnessOptions()

        if (!GoogleSignIn.hasPermissions(GoogleSignIn.getLastSignedInAccount(activity), fitnessOptions)) {
            deferredResult = result

            GoogleSignIn.requestPermissions(
                    activity,
                    GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                    GoogleSignIn.getLastSignedInAccount(activity),
                    fitnessOptions)
        } else {
            result.success(true)
        }
    }

    private fun recordData(callback: (Boolean) -> Unit) {
        Fitness.getRecordingClient(activity, GoogleSignIn.getLastSignedInAccount(activity)!!)
                .subscribe(dataType)
                .addOnSuccessListener {
                    callback(true)
                }
                .addOnFailureListener {
                    callback(false)
                }
    }

    private fun getYesterdaysStepsTotal(result: Result) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val startCal = GregorianCalendar()
        startCal.add(Calendar.DAY_OF_YEAR, -1)
        startCal.set(Calendar.HOUR_OF_DAY, 0)
        startCal.set(Calendar.MINUTE, 0)
        startCal.set(Calendar.SECOND, 0)

        val endCal = GregorianCalendar(
                startCal.get(Calendar.YEAR),
                startCal.get(Calendar.MONTH),
                startCal.get(Calendar.DAY_OF_MONTH),
                23,
                59)

        val request = DataReadRequest.Builder()
                .aggregate(dataType, aggregatedDataType)
                .bucketByTime(1, TimeUnit.DAYS)
                .setTimeRange(startCal.timeInMillis, endCal.timeInMillis, TimeUnit.MILLISECONDS)
                .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        val dateFormat = DateFormat.getDateInstance()
        val dayString = dateFormat.format(Date(startCal.timeInMillis))

        Thread {
            try {
                val readDataResult = Tasks.await<DataReadResponse>(response)
                Log.d(TAG, "buckets count: ${readDataResult.buckets.size}")

                if (!readDataResult.buckets.isEmpty()) {
                    val dp = readDataResult.buckets[0].dataSets[0].dataPoints[0]
                    val count = dp.getValue(aggregatedDataType.fields[0])

                    Log.d(TAG, "returning $count steps for $dayString")
                    val map = HashMap<String, Double>()
                    map["value"] = count.asInt().toDouble()

                    activity.runOnUiThread {
                        result.success(map)
                    }

                } else {
                    activity.runOnUiThread {
                        result.error("No data", "No data found for $dayString", null)
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "failed: ${e.message}")

                activity.runOnUiThread {
                    result.error("failed", e.message, null)
                }
            }

        }.start()
    }

    private fun getFitnessOptions() = FitnessOptions.builder()
            .addDataType(dataType, FitnessOptions.ACCESS_READ)
            .build()
}
