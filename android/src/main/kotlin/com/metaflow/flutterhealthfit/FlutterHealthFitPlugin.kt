package com.metaflow.flutterhealthfit

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
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

class FlutterHealthFitPlugin(private val activity: Activity) : MethodCallHandler, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1
        private const val GOOGLE_FIT_SENSITIVE_PERMISSIONS_REQUEST_CODE = 4723747
        private const val SENSOR_PERMISSION_REQUEST_CODE = 9174802

        val stepsDataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val weightDataType: DataType = DataType.TYPE_WEIGHT
        val aggregatedDataType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA
        val heartRateDataType: DataType = DataType.TYPE_HEART_RATE_BPM

        val TAG: String = FlutterHealthFitPlugin::class.java.simpleName

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            if (registrar.activity() == null) return

            val plugin = FlutterHealthFitPlugin(registrar.activity())
            registrar.addActivityResultListener(plugin)
            registrar.addRequestPermissionsResultListener(plugin)

            val channel = MethodChannel(registrar.messenger(), "flutter_health_fit")
            channel.setMethodCallHandler(plugin)
        }
    }

    private var deferredResult: Result? = null

    override fun onMethodCall(call: MethodCall, result: Result) {

        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")

            "requestAuthorization" -> {
                val useSensitive = call.argument<Boolean>("useSensitive") ?: false
                if (!useSensitive || hasSensorPermissionCompat()) {
                    connect(useSensitive, result)
                } else {
                    this.deferredResult = result
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) { // Pacify lint (checked in hasSensorPermissionCompat)
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(Manifest.permission.BODY_SENSORS),
                            SENSOR_PERMISSION_REQUEST_CODE
                        )
                    }
                }

            }

            "isAuthorized" -> result.success(isAuthorized(call.argument<Boolean>("useSensitive") ?: false))

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
                    if (e != null) {
                        result.error("failed", e.message, null)
                    } else {
                        result.success(map)
                    }
                }
            }

            "getStepsBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                val duration = call.argument<Int>("duration")!!
                val unitInt = call.argument<Int>("unit")!!
                val lumenTimeUnit = LumenTimeUnit.values().first { it.value == unitInt }
                val timeUnit =
                    mapOf(LumenTimeUnit.DAYS to TimeUnit.DAYS, LumenTimeUnit.MINUTES to TimeUnit.MINUTES).getValue(
                        lumenTimeUnit
                    )
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

            "getHeartRateSample" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!

                getHeartRateInRange(start, end) { samples: List<DataPoint>?, e: Throwable? ->
                    if (samples != null) {
                        if (samples.isEmpty()) {
                            result.success(null)
                        } else {
                            val lastPoint = samples.last()
                            result.success(
                                createHeartRateSampleMap(
                                    lastPoint.getTimestamp(TimeUnit.MILLISECONDS),
                                    lastPoint.getValue(heartRateDataType.fields[0]).asFloat(),
                                    lastPoint.dataSource.appPackageName
                                )
                            )
                        }
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getAverageRestingHeartRate" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getHeartRateInRange(start, end) { samples: List<DataPoint>?, e: Throwable? ->
                    if (samples != null) {
                        if (samples.isEmpty()) {
                            result.success(emptyList<Map<String, Any?>>())
                        } else {
                            val valueSum = samples.map { it.getValue(heartRateDataType.fields[0]).asFloat() }.sum()

                            val sampleMap = createHeartRateSampleMap(
                                samples.last().getTimestamp(TimeUnit.MILLISECONDS),
                                valueSum / samples.size,
                                samples.last().dataSource.appPackageName
                            )
                            result.success(listOf(sampleMap))
                        }
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getAverageWalkingHeartRate" -> result.success(null)

            "isAnyPermissionAuthorized" -> {
                val answer = isAnyPermissionAuthorized()
                result.success(answer)
            }

            "isStepsAuthorized" -> result.success(isStepsAuthorized())

            "isCyclingAuthorized" -> result.success(false)

            "isFlightsAuthorized" -> result.success(false)

            "isSleepAuthorized" -> result.success(isSleepAuthorized())

            "isWeightAuthorized" -> result.success(isWeightAuthorized())

            "isHeartRateAuthorized" -> result.success(isHeartRateSampleAuthorized())

            "isCarbsAuthorized" -> result.success(false)

            else -> result.notImplemented()
        }
    }

    private fun isAnyPermissionAuthorized(): Boolean {
        return isWeightAuthorized() || isStepsAuthorized() || isHeartRateSampleAuthorized() || isSleepAuthorized()
    }

    private fun isStepsAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(stepsDataType).addDataType(aggregatedDataType).build())
    }

    private fun isSleepAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(DataType.TYPE_SLEEP_SEGMENT).build())
    }

    private fun isWeightAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(weightDataType).build())
    }

    private fun isHeartRateSampleAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(heartRateDataType).build())
    }

    private fun isAuthorized(fitnessOptions: FitnessOptions): Boolean {
        val account = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)
        return GoogleSignIn.hasPermissions(account, fitnessOptions)
    }

    private fun hasSensorPermissionCompat() = (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT_WATCH
            || ContextCompat.checkSelfPermission(
        activity,
        Manifest.permission.BODY_SENSORS
    ) == PackageManager.PERMISSION_GRANTED)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE || requestCode == GOOGLE_FIT_SENSITIVE_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                listOfNotNull(
                    stepsDataType,
                    weightDataType,
                    if (requestCode == GOOGLE_FIT_SENSITIVE_PERMISSIONS_REQUEST_CODE) heartRateDataType else null
                ).forEach {
                    recordFitnessData(it) { success ->
                        Log.i(TAG, "Record $it success: $success!")

                        if (success)
                            deferredResult?.success(true)
                        else
                            deferredResult?.error("no record", "Record $it operation denied", null)

                        deferredResult = null
                    }
                }
            } else {
                deferredResult?.error("canceled", "User cancelled or app not authorized", null)
                deferredResult = null
            }

            return true
        }

        return false
    }

    private fun createHeartRateSampleMap(millisSinceEpoc: Long, value: Float, sourceApp: String?): Map<String, Any?> {
        return mapOf("timestamp" to millisSinceEpoc, "value" to value.toInt(), "sourceApp" to sourceApp)
    }

    private fun isAuthorized(useSensitive: Boolean): Boolean {
        if (useSensitive && !hasSensorPermissionCompat()) {
            return false
        }
        val fitnessOptions = getFitnessOptions(useSensitive)
        val account = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)
        return GoogleSignIn.hasPermissions(account, fitnessOptions)
    }

    private fun connect(useSensitive: Boolean, result: Result) {
        val fitnessOptions = getFitnessOptions(useSensitive)

        if (!isAuthorized(useSensitive)) {
            deferredResult = result

            val client = GoogleSignIn.getClient(activity, GoogleSignInOptions.DEFAULT_SIGN_IN)
            client.signOut().addOnCompleteListener {
                GoogleSignIn.requestPermissions(
                    activity,
                    if (useSensitive) GOOGLE_FIT_SENSITIVE_PERMISSIONS_REQUEST_CODE else GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                    GoogleSignIn.getAccountForExtension(activity, fitnessOptions),
                    fitnessOptions
                )
            }
        } else {
            result.success(true)
        }
    }

    private fun recordFitnessData(type: DataType, callback: (Boolean) -> Unit) {
        val fitnessOptions = FitnessOptions.builder().addDataType(type).build()
        Fitness.getRecordingClient(activity, GoogleSignIn.getAccountForExtension(activity, fitnessOptions))
            .subscribe(type)
            .addOnSuccessListener {
                callback(true)
            }
            .addOnFailureListener {
                callback(false)
            }
    }

    @SuppressLint("UseSparseArrays") // Dart doesn't know sparse arrays
    private fun getStepsInRange(
        start: Long,
        end: Long,
        duration: Int,
        unit: TimeUnit,
        result: (Map<Long, Int>?, Throwable?) -> Unit
    ) {
        val fitnessOptions = FitnessOptions.builder().addDataType(stepsDataType).addDataType(aggregatedDataType).build()
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val ds = DataSource.Builder()
            .setAppPackageName("com.google.android.gms")
            .setDataType(stepsDataType)
            .setType(DataSource.TYPE_DERIVED)
            .setStreamName("estimated_steps")
            .build()

        val request = DataReadRequest.Builder()
            .aggregate(ds)
            .bucketByTime(duration, unit)
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await(response)
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

    private fun getHeartRateInRange(start: Long, end: Long, result: (List<DataPoint>?, Throwable?) -> Unit) {
        val fitnessOptions = FitnessOptions.builder().addDataType(heartRateDataType).build()
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder()
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .read(heartRateDataType)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await(response)
                Log.d(TAG, "datasets count: ${readDataResult.dataSets.size}")

                if (readDataResult.dataSets.isEmpty()) {
                    activity.runOnUiThread {
                        result(emptyList(), null)
                    }
                } else {
                    val dataPoints = mutableListOf<DataPoint>()

                    for (dataSet in readDataResult.dataSets) {
                        Log.d(TAG, "data set has ${dataSet.dataPoints.size} points")
                        dataPoints.addAll(dataSet.dataPoints)
                    }
                    activity.runOnUiThread {
                        result(dataPoints, null)
                    }
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
        val fitnessOptions = FitnessOptions.builder().addDataType(weightDataType).build()
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder().read(DataType.TYPE_WEIGHT)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByTime(1, TimeUnit.DAYS)
            .setLimit(1)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        var map: HashMap<Long, Float>? = null
        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp = readDataResult.buckets.lastOrNull()?.dataSets?.lastOrNull()?.dataPoints?.lastOrNull()
                val lastWeight = dp?.getValue(weightDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS)

                if (dateInMillis != null) {
                    map = HashMap<Long, Float>()
                    map!![dateInMillis] = lastWeight!!
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

    private fun getFitnessOptions(useSensitive: Boolean): FitnessOptions {
        val builder = FitnessOptions.builder()
            .addDataType(stepsDataType, FitnessOptions.ACCESS_READ)
            .addDataType(aggregatedDataType, FitnessOptions.ACCESS_READ)
            .addDataType(weightDataType, FitnessOptions.ACCESS_READ)
        if (useSensitive) {
            builder.addDataType(heartRateDataType, FitnessOptions.ACCESS_READ)
        }
        return builder.build()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>?,
        grantResults: IntArray?
    ): Boolean {
        return when (requestCode) {
            SENSOR_PERMISSION_REQUEST_CODE -> {
                val result = this.deferredResult!!
                this.deferredResult = null
                if (grantResults?.isNotEmpty() == true && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    connect(true, result)
                } else {
                    result.error("PERMISSION_DENIED", "User refused", null)
                }
                true
            }
            else -> { // Ignore all other requests.
                false
            }
        }
    }
}
