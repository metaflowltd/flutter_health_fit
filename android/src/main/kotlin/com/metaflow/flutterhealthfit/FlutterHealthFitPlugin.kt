package com.metaflow.flutterhealthfit

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.result.DataReadResponse
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.text.DateFormat
import java.util.*
import java.util.concurrent.TimeUnit


class FlutterHealthFitPlugin(private val activity: Activity) : MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1

        val dataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val aggregatedDataType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA

        val TAG: String = FlutterHealthFitPlugin::class.java.simpleName

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            if (registrar.activity() == null) return

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

            "isAuthorized" -> result.success(isAuthorized())

            "getBasicHealthData" -> result.success(HashMap<String, String>())

            "getActivity" -> {
                val map = HashMap<String, Double>()
                map["value"] = 0.0
                result.success(map)
            }

            "getSteps" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getStepsInRange(start, end, result)
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

    private fun isAuthorized(): Boolean {
        val fitnessOptions = getFitnessOptions()
        return GoogleSignIn.hasPermissions(GoogleSignIn.getLastSignedInAccount(activity), fitnessOptions)
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

    @SuppressLint("UseSparseArrays") // Dart doesn't know sparse arrays
    private fun getStepsInRange(start: Long, end: Long, result: Result) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val ds = DataSource.Builder()
                .setAppPackageName("com.google.android.gms")
                .setDataType(DataType.TYPE_STEP_COUNT_DELTA)
                .setType(DataSource.TYPE_DERIVED)
                .setStreamName("estimated_steps")
                .build()

        val request = DataReadRequest.Builder()
                .aggregate(ds, DataType.AGGREGATE_STEP_COUNT_DELTA)
                .bucketByTime(1, TimeUnit.DAYS)
                .setTimeRange(start, end, TimeUnit.MILLISECONDS)
                .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        val dateFormat = DateFormat.getDateInstance()
        val dayString = dateFormat.format(Date(start))

        Thread {
            try {
                val readDataResult = Tasks.await<DataReadResponse>(response)
                Log.d(TAG, "buckets count: ${readDataResult.buckets.size}")

                val map = HashMap<Long, Int>() // need to return to Dart so can't use sparse array
                for (bucket in readDataResult.buckets) {
                    val dp = bucket.dataSets[0].dataPoints[0]
                    val count = dp.getValue(aggregatedDataType.fields[0])

                    Log.d(TAG, "returning $count steps for $dayString")
                    map[dp.getStartTime(TimeUnit.MILLISECONDS)] = count.asInt()
                }
                activity.runOnUiThread {
                    result.success(map)
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
            .addDataType(aggregatedDataType, FitnessOptions.ACCESS_READ)
            .build()
}
