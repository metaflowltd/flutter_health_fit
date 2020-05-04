package com.metaflow.flutterhealthfit

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
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
import java.util.*
import java.util.concurrent.TimeUnit

enum class LumenTimeUnit(val value: Int) {
    MINUTES(0),
    DAYS(1),
}

class FlutterHealthFitPlugin(private val activity: Activity) : MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1

        val stepsDataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val weightDataType: DataType = DataType.TYPE_WEIGHT
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

            "getWeightInInterval" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getWeight(start, end) { map: Map<Long, Float>?, e: Throwable? ->
                    if (map != null) {
                        result.success(map)
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getStepsBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                val duration = call.argument<Int>("duration")!!
                val unitInt = call.argument<Int>("unit")!!
                val lumenTimeUnit = LumenTimeUnit.values().first { it.value == unitInt }
                val timeUnit = mapOf(LumenTimeUnit.DAYS to TimeUnit.DAYS, LumenTimeUnit.MINUTES to TimeUnit.MINUTES).getValue(lumenTimeUnit)
                getStepsInRange(start, end, duration, timeUnit) { map: Map<Long, Int>?, e: Throwable? ->
                    if (map != null) {
                        result.success(map)
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getFlightsBySegment" -> {
                result.success(emptyMap<Long, Int>())
            }

            "getCyclingDistanceBySegment" -> {
                result.success(emptyMap<Long, Double>())
            }

            "getTotalStepsInInterval" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                val duration = (end - start).toInt()
                getStepsInRange(start, end, duration, TimeUnit.MILLISECONDS) { map: Map<Long, Int>?, e: Throwable? ->
                    if (map != null) {
                        assert(map.size <= 1) { "getTotalStepsInInterval should return only one interval. Found: ${map.size}" }
                        result.success(map.values.firstOrNull())
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                recordStepsData { success ->
                    Log.i(TAG, "Record steps data success: $success!")

                    if (success)
                        deferredResult?.success(true)
                    else
                        deferredResult?.error("no record", "Steps record data operation denied", null)

                    deferredResult = null
                }

                recordWeightData { success ->
                    Log.i(TAG, "Record weight data success: $success!")

                    if (success)
                        deferredResult?.success(true)
                    else
                        deferredResult?.error("no record", "Weight record data operation denied", null)

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
        val account = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)
        return GoogleSignIn.hasPermissions(account, fitnessOptions)
    }

    private fun connect(result: Result) {
        val fitnessOptions = getFitnessOptions()

        if (!isAuthorized()) {
            deferredResult = result

            val client = GoogleSignIn.getClient(activity, GoogleSignInOptions.DEFAULT_SIGN_IN)
            client.signOut().addOnCompleteListener {
                GoogleSignIn.requestPermissions(
                        activity,
                        GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                        GoogleSignIn.getAccountForExtension(activity, fitnessOptions),
                        fitnessOptions)
            }
        } else {
            result.success(true)
        }
    }

    private fun recordStepsData(callback: (Boolean) -> Unit) {
        val fitnessOptions = getFitnessOptions()
        Fitness.getRecordingClient(activity, GoogleSignIn.getAccountForExtension(activity, fitnessOptions))
                .subscribe(stepsDataType)
                .addOnSuccessListener {
                    callback(true)
                }
                .addOnFailureListener {
                    callback(false)
                }
    }

    private fun recordWeightData(callback: (Boolean) -> Unit) {
        val fitnessOptions = getFitnessOptions()
        Fitness.getRecordingClient(activity, GoogleSignIn.getAccountForExtension(activity, fitnessOptions))
                .subscribe(weightDataType)
                .addOnSuccessListener {
                    callback(true)
                }
                .addOnFailureListener {
                    callback(false)
                }
    }

    @SuppressLint("UseSparseArrays") // Dart doesn't know sparse arrays
    private fun getStepsInRange(start: Long, end: Long, duration: Int, unit: TimeUnit, result: (Map<Long, Int>?, Throwable?) -> Unit) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val ds = DataSource.Builder()
                .setAppPackageName("com.google.android.gms")
                .setDataType(DataType.TYPE_STEP_COUNT_DELTA)
                .setType(DataSource.TYPE_DERIVED)
                .setStreamName("estimated_steps")
                .build()

        val request = DataReadRequest.Builder()
                .aggregate(ds, DataType.AGGREGATE_STEP_COUNT_DELTA)
                .bucketByTime(duration, unit)
                .setTimeRange(start, end, TimeUnit.MILLISECONDS)
                .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await<DataReadResponse>(response)
                Log.d(TAG, "buckets count: ${readDataResult.buckets.size}")

                val map = HashMap<Long, Int>() // need to return to Dart so can't use sparse array
                for (bucket in readDataResult.buckets) {
                    val dp = bucket.dataSets.firstOrNull()?.dataPoints?.firstOrNull()
                    if (dp != null) {
                        val count = dp.getValue(aggregatedDataType.fields[0])

                        val startTime = dp.getStartTime(TimeUnit.MILLISECONDS)
                        val startDate = Date(startTime)
                        val endDate = Date(dp.getEndTime(TimeUnit.MILLISECONDS))
                        Log.d(TAG, "returning $count steps for $startDate - $endDate")
                        map[startTime] = count.asInt()
                    } else {
                        val startDay = Date(start)
                        val endDay = Date(end)
                        Log.d(TAG, "no steps for $startDay - $endDay")
                    }
                }
                activity.runOnUiThread {
                    result(map, null)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "failed: ${e.message}")

                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun getWeight(startTime: Long, endTime: Long, result: (Map<Long, Float>?, Throwable?) -> Unit) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val request = DataReadRequest.Builder().read(DataType.TYPE_WEIGHT)
                .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                .bucketByTime(1, TimeUnit.DAYS)
                .setLimit(1)
                .build();

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        val map = HashMap<Long, Float>()
        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp = readDataResult.buckets.lastOrNull()?.dataSets?.lastOrNull()?.dataPoints?.lastOrNull()
                val lastWeight = dp?.getValue(weightDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS);

                if (dateInMillis != null) {
                    map[dateInMillis] = lastWeight!!
                    Log.d(TAG, "lastWeight: $lastWeight")
                }
                activity.runOnUiThread {
                    result(map, null)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "failed: ${e.message}")
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun getFitnessOptions() = FitnessOptions.builder()
            .addDataType(stepsDataType, FitnessOptions.ACCESS_READ)
            .addDataType(aggregatedDataType, FitnessOptions.ACCESS_READ)
            .addDataType(weightDataType, FitnessOptions.ACCESS_READ)
            .build()
}
