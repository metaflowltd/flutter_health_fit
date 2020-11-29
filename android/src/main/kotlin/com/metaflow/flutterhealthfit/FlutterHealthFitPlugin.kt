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

class FlutterHealthFitPlugin(private val activity: Activity) : MethodCallHandler, PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1
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
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

            "requestAuthorization" -> {
                if (hasSensorPermissionCompat()) {
                    connect(result)
                } else {
                    this.deferredResult = result
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) { // Pacify lint (checked in hasSensorPermissionCompat)
                        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.BODY_SENSORS), SENSOR_PERMISSION_REQUEST_CODE)
                    }
                }

            }

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

            "getHeartRateSample" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!

                getHeartRateInRange(start, end) { samples: List<DataPoint>?, e: Throwable? ->
                    if (samples != null) {
                        if (samples.isEmpty()) {
                            result.success(null)
                        } else {
                            val lastPoint = samples.last()
                            result.success(createHeartRateSampleMap(lastPoint.getTimestamp(TimeUnit.MILLISECONDS),
                                    lastPoint.getValue(heartRateDataType.fields[0]).asFloat(),
                                    lastPoint.dataSource.appPackageName))
                        }
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getAverageRestingHeartRate" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getAverageHeartRateHourlyBucketsInRange(start, end) { samples: Map<String, Map<String, Any?>>?, e: Throwable? ->
                    samples?.let {
                        val resultList = mutableListOf<Map<String, Any?>>()
                        it.forEach { entry ->
                            resultList.add(entry.value)
                        }
                        result.success(resultList)
                    } ?: run {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getAverageWalkingHeartRate" -> result.success(null)

            else -> result.notImplemented()
        }
    }

    private fun hasSensorPermissionCompat() = (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT_WATCH
            || ContextCompat.checkSelfPermission(activity, Manifest.permission.BODY_SENSORS) == PackageManager.PERMISSION_GRANTED)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                listOf(stepsDataType, weightDataType, heartRateDataType).forEach {
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

    private fun isAuthorized(): Boolean {
        if (!hasSensorPermissionCompat()) {
            return false
        }
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

    private fun recordFitnessData(type: DataType, callback: (Boolean) -> Unit) {
        Fitness.getRecordingClient(activity, GoogleSignIn.getAccountForExtension(activity, getFitnessOptions()))
                .subscribe(type)
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

    private fun getHeartRateInRange(start: Long, end: Long, result: (List<DataPoint>?, Throwable?) -> Unit) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val request = DataReadRequest.Builder()
                .setTimeRange(start, end, TimeUnit.MILLISECONDS)
                .read(DataType.TYPE_HEART_RATE_BPM)
                .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await<DataReadResponse>(response)
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

    private fun getAverageHeartRateHourlyBucketsInRange(start: Long, end: Long, result: (Map<String, Map<String, Any?>>?, Throwable?) -> Unit) {
        val gsa = GoogleSignIn.getAccountForExtension(activity, getFitnessOptions())

        val request = DataReadRequest.Builder()
                .setTimeRange(start, end, TimeUnit.MILLISECONDS)
                .read(DataType.TYPE_HEART_RATE_BPM)
                .bucketByTime(1, TimeUnit.HOURS)
                .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await<DataReadResponse>(response)
                Log.d(TAG, "datasets count: ${readDataResult.dataSets.size}")

                val dataPointsSourceList = mutableListOf<Map<String, List<DataPoint>>>()

                //
                // Collect a map of maps of sources to heart rates in a given time frame bucket
                readDataResult
                        .buckets
                        .flatMap { bucket -> bucket.dataSets }
                        .forEach { dataSet ->
                            val dataPointsList = mutableMapOf<String, MutableList<DataPoint>>()
                            dataSet.dataPoints.takeIf { it.isNotEmpty() }?.filterNotNull()?.forEach { dataPoint ->
                                dataPoint.dataSource.appPackageName?.let { sourceName ->
                                    if (!dataPointsList.containsKey(sourceName)) {
                                        dataPointsList[sourceName] = mutableListOf()
                                    }
                                    dataPointsList[sourceName]?.add(dataPoint)
                                }
                            }

                            if ( dataPointsList.isNotEmpty()) {
                                dataPointsSourceList.add(dataPointsList)
                            }
                        }

                val heartRateBySourceList = mutableMapOf<String, MutableList<Map<String, Any?>>>()

                //
                // For each map of source maps create a map of source to heart rate averages
                dataPointsSourceList.forEach { dataPointMap ->
                    dataPointMap.forEach { entry ->
                        val source = entry.key
                        if (!heartRateBySourceList.containsKey(source)) {
                            heartRateBySourceList[source] = mutableListOf()
                        }
                        val dataPoints = entry.value
                        val heartRateAverage = dataPoints.map { dataPoint -> dataPoint.heartRateValue() }.sum() / dataPoints.size
                        val heartRateTime = Calendar.getInstance()
                        heartRateTime.timeInMillis = dataPoints[0].getTimestamp(TimeUnit.MILLISECONDS)
                        heartRateTime.set(Calendar.MINUTE, 0)
                        heartRateTime.set(Calendar.SECOND, 0)
                        heartRateTime.set(Calendar.MILLISECOND, 0)
                        heartRateBySourceList[source]?.add(createHeartRateSampleMap(heartRateTime.timeInMillis, heartRateAverage, entry.key))
                    }
                }

                val lowestHeartRatesBySource = mutableMapOf<String, Map<String, Any?>>()

                //
                // For each map of sources to heart rate averages find the lowest value
                heartRateBySourceList.forEach { sourceEntry ->
                    var minDataPoint: Map<String, Any?> = mapOf()
                    sourceEntry.value.forEach { dataPointMap ->
                        if (minDataPoint.isEmpty()) {
                            minDataPoint = dataPointMap
                        } else if ((dataPointMap["value"] as Int) < (minDataPoint["value"] as Int)) {
                            minDataPoint = dataPointMap
                        }
                    }
                    lowestHeartRatesBySource[sourceEntry.key] = createHeartRateSampleMap(
                            minDataPoint["timestamp"] as Long,
                            (minDataPoint["value"] as Int).toFloat(),
                            minDataPoint["sourceApp"] as String)
                }

                activity.runOnUiThread {
                    result(lowestHeartRatesBySource, null)
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

        var map: HashMap<Long, Float>? = null
        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp = readDataResult.buckets.lastOrNull()?.dataSets?.lastOrNull()?.dataPoints?.lastOrNull()
                val lastWeight = dp?.getValue(weightDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS);

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

    private fun getFitnessOptions() = FitnessOptions.builder()
            .addDataType(stepsDataType, FitnessOptions.ACCESS_READ)
            .addDataType(aggregatedDataType, FitnessOptions.ACCESS_READ)
            .addDataType(weightDataType, FitnessOptions.ACCESS_READ)
            .addDataType(heartRateDataType, FitnessOptions.ACCESS_READ)
            .build()

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
        return when (requestCode) {
            SENSOR_PERMISSION_REQUEST_CODE -> {
                val result = this.deferredResult!!
                this.deferredResult = null
                if (grantResults?.isNotEmpty() == true && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    connect(result)
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

    private fun DataPoint.heartRateValue(): Float { return getValue(heartRateDataType.fields[0]).asFloat() }
}
