package com.metaflow.flutterhealthfit

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.request.SessionReadRequest
import com.google.android.gms.tasks.Tasks
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.util.*
import java.util.concurrent.TimeUnit

enum class LumenTimeUnit(val value: Int) {
    MINUTES(0),
    DAYS(1),
}

class FlutterHealthFitPlugin : MethodCallHandler,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener,
    FlutterPlugin,
    ActivityAware, EventChannel.StreamHandler {

    companion object {
        private const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1
        private const val SENSOR_PERMISSION_REQUEST_CODE = 9174802

        val stepsDataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val weightDataType: DataType = DataType.TYPE_WEIGHT
        val aggregatedDataType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA
        val heartRateDataType: DataType = DataType.TYPE_HEART_RATE_BPM
        val sleepDataType: DataType = DataType.TYPE_SLEEP_SEGMENT
        val bodyFatDataType: DataType = DataType.TYPE_BODY_FAT_PERCENTAGE

        val TAG: String = FlutterHealthFitPlugin::class.java.simpleName

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            if (registrar.activity() == null) return

            val plugin = FlutterHealthFitPlugin()
            plugin.activity = registrar.activity()
            registrar.addActivityResultListener(plugin)
            registrar.addRequestPermissionsResultListener(plugin)

            plugin.onAttachedToEngine(registrar.messenger())
        }
    }

    private var logger : EventChannel.EventSink? = null
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var logsChannel: EventChannel? = null
    private var deferredResult: Result? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(binding.binaryMessenger)
    }

    private fun onAttachedToEngine(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "flutter_health_fit")
        channel?.setMethodCallHandler(this)

        logsChannel = EventChannel(messenger, "flutter_health_fit_logs_channel")
        logsChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null

        logsChannel?.setStreamHandler(null)
        logsChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        this.activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        binding?.let {
            it.removeActivityResultListener(this)
            it.removeRequestPermissionsResultListener(this)
        }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
        binding?.let {
            it.removeActivityResultListener(this)
            it.removeRequestPermissionsResultListener(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")

            "requestAuthorization" -> {
                val useSensitive = call.argument<Boolean>("useSensitive") ?: false
                connect(useSensitive, result)
            }

            "requestBodySensorsPermission" -> requestBodySensorsPermission(result)

            "isAuthorized" -> result.success(
                isAuthorized(
                    call.argument<Boolean>("useSensitive") ?: false
                )
            )

            "signOut" -> result.success(activity?.let { signOut(it) })

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

            "getBodyFatPercentageBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getBodyFat(start, end) { map: Map<Long, Float>?, e: Throwable? ->
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
                    mapOf(
                        LumenTimeUnit.DAYS to TimeUnit.DAYS,
                        LumenTimeUnit.MINUTES to TimeUnit.MINUTES
                    ).getValue(
                        lumenTimeUnit
                    )
                getStepsInRange(
                    start,
                    end,
                    duration,
                    timeUnit
                ) { map: Map<Long, Int>?, e: Throwable? ->
                    if (map != null) {
                        result.success(map)
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getSleepBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!

                getSleepDataInRange(
                    start,
                    end
                ) { samples: List<Map<String, Any?>>?, e: Throwable? ->
                    samples?.let {
                        if (samples.isEmpty()) {
                            result.success(null)
                        } else {
                            result.success(it)
                        }
                    } ?: kotlin.run {
                        result.error(
                            "failed",
                            "Failed to retrieve sleep samples, reason: ${e?.localizedMessage}",
                            e
                        )
                    }
                }
            }

            "getFlightsBySegment" -> { // only implemented on iOS
                result.success(emptyMap<Long, Int>())
            }

            "getCyclingDistanceBySegment" -> { // only implemented on iOS
                result.success(emptyMap<Long, Double>())
            }

            "getTotalStepsInInterval" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                val duration = (end - start).toInt()
                getStepsInRange(
                    start,
                    end,
                    duration,
                    TimeUnit.MILLISECONDS
                ) { map: Map<Long, Int>?, e: Throwable? ->
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
                            val valueSum =
                                samples.map { it.getValue(heartRateDataType.fields[0]).asFloat() }
                                    .sum()

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

            "isAnyPermissionAuthorized" -> result.success(isAnyPermissionAuthorized())

            "isStepsAuthorized" -> result.success(isStepsAuthorized())

            "isCyclingAuthorized" -> // only implemented on iOS
                result.success(false)

            "isFlightsAuthorized" -> // only implemented on iOS
                result.success(false)

            "isSleepAuthorized" -> result.success(isSleepAuthorized())

            "isWeightAuthorized" -> result.success(isWeightAuthorized())

            "isHeartRateAuthorized" -> result.success(isHeartRateSampleAuthorized())

            "isBodyFatPercentageAuthorized" -> result.success(isBodyFatAuthorized())

            "isCarbsAuthorized" -> // only implemented on iOS
                result.success(false)

            "isBodySensorsAuthorized" -> result.success(hasSensorPermissionCompat())

            else -> result.notImplemented()
        }
    }

    private fun requestBodySensorsPermission(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            this.deferredResult = result
            activity?.let {
                ActivityCompat.requestPermissions(
                    it,
                    arrayOf(Manifest.permission.BODY_SENSORS),
                    SENSOR_PERMISSION_REQUEST_CODE
                )
            }
        } else {
            result.success(true)
        }
    }

    private fun isAnyPermissionAuthorized(): Boolean {
        return isWeightAuthorized() || isStepsAuthorized() || isHeartRateSampleAuthorized() || isSleepAuthorized()
    }

    private fun isStepsAuthorized(): Boolean {
        return isAuthorized(
            FitnessOptions.builder().addDataType(stepsDataType).addDataType(aggregatedDataType)
                .build()
        )
    }

    private fun isSleepAuthorized(): Boolean {
        return isAuthorized(
            FitnessOptions.builder().addDataType(DataType.TYPE_SLEEP_SEGMENT).build()
        )
    }

    private fun isWeightAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(weightDataType).build())
    }

    private fun isBodyFatAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(bodyFatDataType).build())
    }

    private fun isHeartRateSampleAuthorized(): Boolean {
        return isAuthorized(FitnessOptions.builder().addDataType(heartRateDataType).build())
    }

    private fun isAuthorized(fitnessOptions: FitnessOptions): Boolean {
        val account = activity?.let { GoogleSignIn.getAccountForExtension(it, fitnessOptions) }
        return GoogleSignIn.hasPermissions(account, fitnessOptions)
    }

    private fun hasSensorPermissionCompat() =
        (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT_WATCH
                || activity?.let {
            ContextCompat.checkSelfPermission(
                it,
                Manifest.permission.BODY_SENSORS
            )
        } == PackageManager.PERMISSION_GRANTED)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            GOOGLE_FIT_PERMISSIONS_REQUEST_CODE -> {
                recordDataPointsIfGranted(
                    resultCode == Activity.RESULT_OK, listOfNotNull(
                        stepsDataType,
                        weightDataType,
                        bodyFatDataType,
                        if (hasSensorPermissionCompat()) heartRateDataType else null
                    ),
                    deferredResult
                )
                deferredResult = null
                true
            }
            else -> false
        }
    }

    private fun recordDataPointsIfGranted(
        isGranted: Boolean,
        dataPoints: List<DataType>,
        result: Result?
    ) {
        if (isGranted) {
            val failedTypes = arrayListOf<DataType>()
            dataPoints.forEach {
                recordFitnessData(it) { success ->
                    sendNativeLog(" $TAG | Record $it success: $success!")
                    if (!success) failedTypes.add(it)
                }
            }
            if (failedTypes.isEmpty())
                result?.success(true)
            else
                result?.error("no record", "Record $failedTypes operation denied", null)
        } else {
            result?.error("canceled", "User cancelled or app not authorized", null)
        }
    }

    private fun createHeartRateSampleMap(
        millisSinceEpoc: Long,
        value: Float,
        sourceApp: String?
    ): Map<String, Any?> {
        return mapOf(
            "timestamp" to millisSinceEpoc,
            "value" to value.toInt(),
            "sourceApp" to sourceApp
        )
    }

    private fun isAuthorized(useSensitive: Boolean): Boolean {
        val fitnessOptions = getFitnessOptions(useSensitive)
        val account = activity?.let { GoogleSignIn.getAccountForExtension(it, fitnessOptions) }
        sendNativeLog("isAuthorized: Google account = $account")
        val hasPermissions = GoogleSignIn.hasPermissions(account, fitnessOptions)
        sendNativeLog("isAuthorized result: hasPermissions = $hasPermissions")
        return hasPermissions
    }

    private fun sendNativeLog(message: String) {
        activity?.runOnUiThread {
            logger?.success(message)
        }
    }

    private fun connect(useSensitive: Boolean, result: Result) {
        sendNativeLog("Connecting with useSensitive = $useSensitive")
        val fitnessOptions = getFitnessOptions(useSensitive)
        if (!isAuthorized(useSensitive)) {
            sendNativeLog("User has no permissions")
            deferredResult = result
            activity?.let { activity ->
                val client = GoogleSignIn.getClient(activity, GoogleSignInOptions.DEFAULT_SIGN_IN)
                sendNativeLog("Calling for google client sign out")
                client.signOut().addOnCompleteListener {
                    sendNativeLog("Signed out, requesting permissions again")
                    GoogleSignIn.requestPermissions(
                        activity,
                        GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                        GoogleSignIn.getAccountForExtension(activity, fitnessOptions),
                        fitnessOptions
                    )
                }
            }
        } else {
            sendNativeLog("User authorized all required permissions")
            result.success(true)
        }
    }

    private fun recordFitnessData(type: DataType, callback: (Boolean) -> Unit) {
        val fitnessOptions = FitnessOptions.builder().addDataType(type).build()
        activity?.let { activity ->
            Fitness.getRecordingClient(
                activity,
                GoogleSignIn.getAccountForExtension(activity, fitnessOptions)
            )
                .subscribe(type)
                .addOnSuccessListener {
                    callback(true)
                }
                .addOnFailureListener {
                    callback(false)
                }
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
        val fitnessOptions =
            FitnessOptions.builder().addDataType(stepsDataType).addDataType(aggregatedDataType)
                .build()
        val activity = activity ?: return
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
                sendNativeLog("$TAG | buckets count: ${readDataResult.buckets.size}")

                val map = HashMap<Long, Int>() // need to return to Dart so can't use sparse array
                for (bucket in readDataResult.buckets) {
                    val dp = bucket.dataSets.firstOrNull()?.dataPoints?.firstOrNull()
                    if (dp != null) {
                        val count = dp.getValue(aggregatedDataType.fields[0])

                        val startTime = dp.getStartTime(TimeUnit.MILLISECONDS)
                        val startDate = Date(startTime)
                        val endDate = Date(dp.getEndTime(TimeUnit.MILLISECONDS))
                        sendNativeLog("$TAG | returning $count steps for $startDate - $endDate")
                        map[startTime] = count.asInt()
                    } else {
                        val startDay = Date(start)
                        val endDay = Date(end)
                        sendNativeLog("$TAG | no steps for $startDay - $endDay")
                    }
                }
                activity.runOnUiThread {
                    result(map, null)
                }
            } catch (e: Throwable) {
                sendNativeLog("$TAG | failed to get steps in range ${e.message}")
                handleGoogleDisconnection(e, activity)
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun getSleepDataInRange(
        start: Long,
        end: Long,
        result: (List<Map<String, Any?>>?, Throwable?) -> Unit
    ) {

        val fitnessOptions = FitnessOptions.builder().addDataType(sleepDataType).build()

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val SLEEP_STAGE_NAMES = arrayOf(
            "Unused",
            "Awake (during sleep)",
            "Sleep",
            "Out-of-bed",
            "Light sleep",
            "Deep sleep",
            "REM sleep"
        )

        val request = SessionReadRequest.Builder()
            .read(DataType.TYPE_SLEEP_SEGMENT)
            // By default, only activity sessions are included, not sleep sessions. Specifying
            // includeSleepSessions also sets the behaviour to *exclude* activity sessions.
            .includeSleepSessions()
            .enableServerQueries()
            .readSessionsFromAllApps()
            .setTimeInterval(start, end, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getSessionsClient(activity, gsa).readSession(request)
            .addOnSuccessListener { response ->

                val resultList = mutableListOf<Map<String, Any?>>()

                for (session in response.sessions) {
                    val sessionResults = mutableListOf<Map<String, Any?>>()
                    val sessionStart = session.getStartTime(TimeUnit.MILLISECONDS)
                    val sessionEnd = session.getEndTime(TimeUnit.MILLISECONDS)
                    sendNativeLog("$TAG | Sleep between $sessionStart and $sessionEnd")

                    val dataSets = response.getDataSet(session)

                    for (dataSet in dataSets) {
                        for (point in dataSet.dataPoints) {
                            try {
                                val sleepStageVal =
                                    point.getValue(Field.FIELD_SLEEP_SEGMENT_TYPE).asInt()
                                val sleepStage = SLEEP_STAGE_NAMES[sleepStageVal]
                                val segmentStart = point.getStartTime(TimeUnit.MILLISECONDS)
                                val segmentEnd = point.getEndTime(TimeUnit.MILLISECONDS)
                                sendNativeLog("$TAG | \t* Type $sleepStage between $segmentStart and $segmentEnd")
                                sessionResults.add(
                                    mapOf(
                                        "type" to sleepStageVal,
                                        "start" to segmentStart,
                                        "end" to segmentEnd,
                                        "source" to session.appPackageName,
                                    )
                                )
                            } catch (e: Exception) {
                                sendNativeLog("$TAG | \tFailed to parse data point, ${e.localizedMessage}")
                                handleGoogleDisconnection(e, activity)
                            }
                        }
                    }
                    // If we were unable to get granular data from the session, we will use not rough data:
                    if (sessionResults.isEmpty()) {
                        resultList.add(
                            mapOf(
                                "type" to 0,
                                "start" to sessionStart,
                                "end" to sessionEnd,
                                "source" to session.appPackageName,
                            )
                        )
                    } else {
                        resultList.addAll(sessionResults)
                    }
                }

                result(resultList, null)
            }
            .addOnFailureListener { error ->
                sendNativeLog("$TAG | \tFailed to get sleep data ${error.localizedMessage}")
                result(null, error)
            }
    }

    private fun getHeartRateInRange(
        start: Long,
        end: Long,
        result: (List<DataPoint>?, Throwable?) -> Unit
    ) {
        val fitnessOptions = FitnessOptions.builder().addDataType(heartRateDataType).build()

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder()
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .read(heartRateDataType)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await(response)
                sendNativeLog("$TAG | datasets count: ${readDataResult.dataSets.size}")

                if (readDataResult.dataSets.isEmpty()) {
                    activity.runOnUiThread {
                        result(emptyList(), null)
                    }
                } else {
                    val dataPoints = mutableListOf<DataPoint>()

                    for (dataSet in readDataResult.dataSets) {
                        sendNativeLog("$TAG | data set has ${dataSet.dataPoints.size} points")
                        dataPoints.addAll(dataSet.dataPoints)
                    }
                    activity.runOnUiThread {
                        result(dataPoints, null)
                    }
                }
            } catch (e: Throwable) {
                sendNativeLog("$TAG | failed: ${e.message}")
                handleGoogleDisconnection(e, activity)
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun signOut(activity: Activity) {
        sendNativeLog("$TAG | signing out from google client")
        val client =
            GoogleSignIn.getClient(activity, GoogleSignInOptions.DEFAULT_SIGN_IN)
        Tasks.await(client.signOut())
    }

    private fun getBodyFat(
        startTime: Long,
        endTime: Long,
        result: (Map<Long, Float>?, Throwable?) -> Unit
    ) {
        val fitnessOptions = FitnessOptions.builder().addDataType(bodyFatDataType).build()

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder().read(DataType.TYPE_BODY_FAT_PERCENTAGE)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByTime(1, TimeUnit.DAYS)
            .setLimit(1)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        var map: HashMap<Long, Float>? = null
        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp =
                    readDataResult.buckets.lastOrNull()?.dataSets?.lastOrNull()?.dataPoints?.lastOrNull()
                val lastBodyFat = dp?.getValue(bodyFatDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS)

                if (dateInMillis != null) {
                    map = HashMap<Long, Float>()
                    map!![dateInMillis] = lastBodyFat!!
                    sendNativeLog("$TAG | lastBodyFat: $lastBodyFat")
                }
                activity.runOnUiThread {
                    result(map, null)
                }
            } catch (e: Throwable) {
                sendNativeLog("$TAG | failed: ${e.message}")
                handleGoogleDisconnection(e, activity)
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun getWeight(
        startTime: Long,
        endTime: Long,
        result: (Map<Long, Float>?, Throwable?) -> Unit
    ) {
        val fitnessOptions = FitnessOptions.builder().addDataType(weightDataType).build()

        val activity = activity ?: return
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
                val dp =
                    readDataResult.buckets.lastOrNull()?.dataSets?.lastOrNull()?.dataPoints?.lastOrNull()
                val lastWeight = dp?.getValue(weightDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS)

                if (dateInMillis != null) {
                    map = HashMap<Long, Float>()
                    map!![dateInMillis] = lastWeight!!
                    sendNativeLog("$TAG | lastWeight: $lastWeight")
                }
                activity.runOnUiThread {
                    result(map, null)
                }
            } catch (e: Throwable) {
                sendNativeLog("$TAG | failed: ${e.message}")
                handleGoogleDisconnection(e, activity)
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    /**
     * This is a workaround for a rare case, when google client can be disconnected, in that case
     * we logging out the user from google services, and revoking the permission.
     * It will allow the user to login properly and ask for a permissions again.
     */
    private fun handleGoogleDisconnection(e: Throwable, activity: Activity) {
        sendNativeLog("$TAG | checking if disconnected from the client")
        if ((e.cause as? ApiException)?.statusCode == 4) {
            sendNativeLog("$TAG | disconnected from Google client")
            signOut(activity)
        }
    }

    private fun getFitnessOptions(useSensitive: Boolean): FitnessOptions {
        val builder = FitnessOptions.builder()
            .addDataType(stepsDataType, FitnessOptions.ACCESS_READ)
            .addDataType(aggregatedDataType, FitnessOptions.ACCESS_READ)
            .addDataType(weightDataType, FitnessOptions.ACCESS_READ)
        if (useSensitive) {
            builder.addDataType(heartRateDataType, FitnessOptions.ACCESS_READ)
            builder.addDataType(sleepDataType, FitnessOptions.ACCESS_READ)
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
                    if (isHeartRateSampleAuthorized()) {
                        recordDataPointsIfGranted(true, listOf(heartRateDataType), result)
                    } else {
                        result.success(true)
                    }
                } else {
                    result.success(false)
                }
                true
            }
            else ->  // Ignore all other requests.
                false
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        this.logger = events
    }

    override fun onCancel(arguments: Any?) {
        this.logger?.endOfStream()
    }
}
