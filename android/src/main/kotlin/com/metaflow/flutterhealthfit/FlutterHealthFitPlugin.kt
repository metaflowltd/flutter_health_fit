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
import com.google.android.gms.fitness.data.*
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

enum class LumenUnit(val value: String) {
    KG("kg"),
    G("g"),
    KCAL("kCal"),
    PERCENT("percent"),
    COUNT("count"),
}

enum class CallDataType {
    AGGREGATE_STEP_COUNT,
    BASIC_HEALTH,
    BLOOD_GLUCOSE,
    BLOOD_PRESSURE,
    BODY_FAT_PERCENTAGE,
    HEART_RATE,
    HEIGHT,
    MENSTRUATION,
    NUTRITION,
    RESTING_ENERGY,
    SLEEP,
    STEPS,
    WEIGHT,
    WORKOUT,

    // Not implemented on Android
    CYCLING,
    FLIGHTS
}

class FlutterHealthFitPlugin : MethodCallHandler,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener,
    FlutterPlugin,
    ActivityAware, EventChannel.StreamHandler {

    companion object {
        const val AGGREGATED_SOURCE_APP = "Aggregated"
        private const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1
        private const val SENSOR_PERMISSION_REQUEST_CODE = 9174802

        val weightDataType: DataType = DataType.TYPE_WEIGHT
        val heartRateDataType: DataType = DataType.TYPE_HEART_RATE_BPM
        val sleepDataType: DataType = DataType.TYPE_SLEEP_SEGMENT
        val bodyFatDataType: DataType = DataType.TYPE_BODY_FAT_PERCENTAGE
        val menstruationDataType: DataType = HealthDataTypes.TYPE_MENSTRUATION
        val TAG: String = FlutterHealthFitPlugin::class.java.simpleName

        fun getFitnessOptions(type: DataType): FitnessOptions = getFitnessOptions(setOf(type))

        fun getFitnessOptions(types: Set<DataType>): FitnessOptions {
            val builder = FitnessOptions.builder()
            types.forEach {
                builder.addDataType(it, FitnessOptions.ACCESS_READ)
            }
            return builder.build()
        }

        @Suppress("unused")
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

    private var logger: EventChannel.EventSink? = null
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var logsChannel: EventChannel? = null
    private var deferredResult: Result? = null
    private var activity: Activity? = null

    // Keep track of which data types are requested to then start recording once permissions are returned
    private var requestedDataTypes: Set<DataType> = setOf()

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
                try {
                    val types = extractDataTypesFromCall(call)
                    requestAuthorization(types, result)
                } catch (e: IllegalArgumentException) {
                    result.error("illegal-argument", e.message, null)
                }
            }

            "requestBodySensorsPermission" -> requestBodySensorsPermission(result)

            "isAuthorized" -> {
                try {
                    val types = extractDataTypesFromCall(call)
                    result.success(isAuthorized(types))
                } catch (e: IllegalArgumentException) {
                    result.error("illegal-argument", e.message, null)
                }
            }

            "signOut" -> result.success(activity?.let { signOut(it) })

            "getBasicHealthData" -> result.success(HashMap<String, String>())

            "getActivity" -> {
                val map = HashMap<String, Double>()
                map["value"] = 0.0
                result.success(map)
            }

            "getWeightInInterval" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("failed", "missing start and end params", null)
                    return
                }

                getWeight(start, end) { value: DataPointValue?, e: Throwable? ->
                    if (e != null) {
                        result.error("failed", e.message, null)
                    } else {
                        result.success(value?.resultMap())
                    }
                }
            }

            "getMenstrualDataBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getMenstruationData(start, end) { list: List<DataPointValue>?, e: Throwable? ->
                    handleDataPointValueListResponse(result = result, list = list, e = e)
                }
            }

            "getBodyFatPercentageBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getBodyFat(start, end) { value: DataPointValue?, e: Throwable? ->
                    if (e != null) {
                        result.error("failed", e.message, null)
                    } else {
                        result.success(value?.resultMap())
                    }
                }
            }

            "getBloodGlucose" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                VitalsReader().getBloodGlucose(activity, start, end) { values: List<Map<String, Any>>?, e: Throwable? ->
                    if (e != null) {
                        sendNativeLog("$TAG | failed: ${e.message}")
                        activity?.let { handleGoogleDisconnection(e, it) }

                        result.error("failed", e.message, null)
                    } else {
                        result.success(values)
                    }
                }
            }

            "getBloodPressure" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                VitalsReader().getBloodPressure(
                    activity,
                    start,
                    end
                ) { values: List<Map<String, Any>>?, e: Throwable? ->
                    if (e != null) {
                        sendNativeLog("$TAG | failed: ${e.message}")
                        activity?.let { handleGoogleDisconnection(e, it) }

                        result.error("failed", e.message, null)
                    } else {
                        result.success(values)
                    }
                }
            }

            "getEnergyConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getEnergyConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getFiberConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getFiberConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getCarbsConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getCarbsConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getSugarConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getSugarConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getFatConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getFatConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getProteinConsumed" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    NutritionReader().getProteinConsumed(
                        activity,
                        start,
                        end
                    ) { list: List<DataPointValue>?, e: Throwable? ->
                        handleDataPointValueListResponse(result = result, list = list, e = e)
                    }
                }
            }

            "getStepsBySegment" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    UserActivityReader().getSteps(
                        activity,
                        start,
                        end
                    ) { dataPointValue: DataPointValue?, e: Throwable? ->
                        e?.let { error ->
                            sendNativeLog("${UserEnergyReader::class.java.simpleName} | failed: ${error.message}")
                            result.error("failed", e.message, null)
                        } ?: run {
                            result.success(dataPointValue?.resultMap())
                        }
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
            "getWorkoutsBySegment" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                WorkoutsReader().getWorkouts(
                    activity,
                    start,
                    end
                ) { list: List<Map<String, Any>>?, e: Throwable? ->
                    if (e != null) {
                        sendNativeLog("$TAG | failed: ${e.message}")
                        activity?.let { handleGoogleDisconnection(e, it) }

                        result.error("failed", e.message, null)
                    } else {
                        result.success(list)
                    }
                }
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

            "getLatestHeartRate" -> {
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

            "getAverageHeartRate" -> {
                val start = call.argument<Long>("start")!!
                val end = call.argument<Long>("end")!!
                getHeartRateInRange(start, end) { samples: List<DataPoint>?, e: Throwable? ->
                    if (samples != null) {
                        if (samples.isEmpty()) {
                            result.success(null)
                        } else {
                            val valueSum =
                                samples.map { it.getValue(heartRateDataType.fields[0]).asFloat() }
                                    .sum()

                            val sampleMap = createHeartRateSampleMap(
                                samples.last().getTimestamp(TimeUnit.MILLISECONDS),
                                valueSum / samples.size,
                                samples.last().originalDataSource.appPackageName
                                    ?: samples.last().dataSource.appPackageName
                            )
                            result.success(sampleMap)
                        }
                    } else {
                        result.error("failed", e?.message, null)
                    }
                }
            }

            "getRestingEnergy" -> {
                val start = call.argument<Long>("start")
                val end = call.argument<Long>("end")
                if (start == null || end == null) {
                    sendNativeLog("${UserEnergyReader::class.java.simpleName} | Missing mandatory fields")
                    result.error("Missing mandatory fields", "start, end", null)
                } else {
                    UserEnergyReader().getRestingEnergy(
                        activity,
                        start,
                        end
                    ) { dataPointValue: DataPointValue?, e: Throwable? ->
                        e?.let { error ->
                            sendNativeLog("${UserEnergyReader::class.java.simpleName} | failed: ${error.message}")
                            result.error("failed", e.message, null)
                        } ?: run {
                            result.success(dataPointValue?.resultMap())
                        }
                    }
                }
            }

            "isAnyPermissionAuthorized" -> result.success(isAnyPermissionAuthorized())

            "isStepsAuthorized" -> result.success(isAuthorized(CallDataType.STEPS))

            "isCyclingAuthorized" -> // only implemented on iOS
                result.success(false)

            "isFlightsAuthorized" -> // only implemented on iOS
                result.success(false)

            "isSleepAuthorized" -> result.success(isAuthorized(CallDataType.SLEEP))

            "isMenstrualDataAuthorized" -> result.success(isAuthorized(CallDataType.MENSTRUATION))

            "isWeightAuthorized" -> result.success(isAuthorized(CallDataType.WEIGHT))

            "isBloodGlucoseAuthorized" -> result.success(isAuthorized(CallDataType.BLOOD_GLUCOSE))

            "isBloodPressureAuthorized" -> result.success(isAuthorized(CallDataType.BLOOD_PRESSURE))

            "isHeartRateAuthorized" -> result.success(isAuthorized(CallDataType.HEART_RATE))

            "isBodyFatPercentageAuthorized" -> result.success(isAuthorized(CallDataType.BODY_FAT_PERCENTAGE))

            "isEnergyConsumedAuthorized",
            "isProteinConsumedAuthorized",
            "isSugarConsumedAuthorized",
            "isFatConsumedAuthorized",
            "isFiberConsumedAuthorized",
            "isCarbsConsumedAuthorized",
            -> result.success(isAuthorized(CallDataType.NUTRITION))

            "isWorkoutsAuthorized" -> result.success(isAuthorized(CallDataType.WORKOUT))

            "isBodySensorsAuthorized" -> result.success(hasSensorPermissionCompat())

            "isRestingEnergyAuthorized" -> result.success(isAuthorized(CallDataType.RESTING_ENERGY))

            else -> result.notImplemented()
        }
    }

    private fun handleDataPointValueListResponse(
        result: Result,
        list: List<DataPointValue>?,
        e: Throwable?,
    ) {
        if (e != null) {
            sendNativeLog("$TAG | failed: ${e.message}")
            activity?.let { handleGoogleDisconnection(e, it) }

            result.error("failed", e.message, null)
        } else {
            val outList = list?.map { dataPointValue ->
                dataPointValue.resultMap()
            }
            result.success(outList)
        }
    }

    private fun callTypeToDataTypes(type: CallDataType): Set<DataType> {
        return when (type) {
            CallDataType.AGGREGATE_STEP_COUNT -> setOf(UserActivityReader.aggregatedStepDataType)
            CallDataType.BASIC_HEALTH -> setOf(weightDataType, DataType.TYPE_HEIGHT)
            CallDataType.BLOOD_GLUCOSE -> setOf(VitalsReader.bloodGlucoseType)
            CallDataType.BLOOD_PRESSURE -> setOf(VitalsReader.bloodPressureType)
            CallDataType.BODY_FAT_PERCENTAGE -> setOf(bodyFatDataType)
            CallDataType.CYCLING, CallDataType.FLIGHTS -> setOf()
            CallDataType.HEART_RATE -> setOf(heartRateDataType)
            CallDataType.HEIGHT -> setOf(DataType.TYPE_HEIGHT)
            CallDataType.MENSTRUATION -> setOf(menstruationDataType)
            CallDataType.NUTRITION -> setOf(NutritionReader.nutritionType)
            CallDataType.RESTING_ENERGY -> setOf(UserEnergyReader.restingEnergyType)
            CallDataType.SLEEP -> setOf(sleepDataType)
            CallDataType.STEPS -> setOf(UserActivityReader.stepsDataType)
            CallDataType.WEIGHT -> setOf(weightDataType)
            CallDataType.WORKOUT -> setOf(
                DataType.AGGREGATE_ACTIVITY_SUMMARY,
                DataType.TYPE_CALORIES_EXPENDED,
                DataType.TYPE_DISTANCE_DELTA
            )
        }
    }

    private fun extractDataTypesFromCall(call: MethodCall): Set<DataType> {
        val args = call.arguments as HashMap<*, *>
        if (!args.containsKey("types")) {
            throw IllegalArgumentException("Invalid arguments")
        }
        val callTypes = (args["types"] as ArrayList<*>).filterIsInstance<String>()
        return callTypes.fold(setOf()) { r, t -> r.union(callTypeToDataTypes(CallDataType.valueOf(t))) }
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

    private fun isAnyPermissionAuthorized(): Boolean =
        isAuthorized(CallDataType.WEIGHT) ||
                isAuthorized(CallDataType.BLOOD_GLUCOSE) ||
                isAuthorized(CallDataType.BLOOD_PRESSURE) ||
                isAuthorized(CallDataType.STEPS) ||
                isAuthorized(CallDataType.HEART_RATE) ||
                isAuthorized(CallDataType.SLEEP)

    private fun isAuthorized(callType: CallDataType): Boolean = isAuthorized(callTypeToDataTypes(callType))

    private fun isAuthorized(types: Set<DataType>): Boolean {
        val fitnessOptions = getFitnessOptions(types)
        val account = activity?.let { GoogleSignIn.getAccountForExtension(it, fitnessOptions) }
        sendNativeLog("isAuthorized: Google account = $account")
        val hasPermissions = GoogleSignIn.hasPermissions(account, fitnessOptions)
        sendNativeLog("isAuthorized result: hasPermissions = $hasPermissions")
        return hasPermissions
    }

    private fun hasSensorPermissionCompat(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT_WATCH) return true

        return activity?.let {
            return@let ContextCompat.checkSelfPermission(
                it,
                Manifest.permission.BODY_SENSORS
            ) == PackageManager.PERMISSION_GRANTED
        } ?: false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            GOOGLE_FIT_PERMISSIONS_REQUEST_CODE -> {
                recordDataPointsIfGranted(
                    resultCode == Activity.RESULT_OK,
                    requestedDataTypes,
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
        dataPoints: Set<DataType>,
        result: Result?,
    ) {
        sendNativeLog(" $TAG | Recording for ${dataPoints.map { it.name }}!")
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
        sourceApp: String?,
    ): Map<String, Any?> {
        return mapOf(
            "timestamp" to millisSinceEpoc,
            "value" to value.toInt(),
            "sourceApp" to sourceApp
        )
    }

    private fun sendNativeLog(message: String) {
        activity?.runOnUiThread {
            logger?.success(message)
        }
    }

    private fun requestAuthorization(types: Set<DataType>, result: Result) {
        sendNativeLog("Connecting for types $types")
        val fitnessOptions = getFitnessOptions(types)
        if (!isAuthorized(types)) {
            sendNativeLog("User has no permissions")
            deferredResult = result
            requestedDataTypes = types
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
        result: (Map<Long, Int>?, Throwable?) -> Unit,
    ) {
        val fitnessOptions =
            getFitnessOptions(setOf(UserActivityReader.stepsDataType, UserActivityReader.aggregatedStepDataType))
        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val ds = DataSource.Builder()
            .setAppPackageName("com.google.android.gms")
            .setDataType(UserActivityReader.stepsDataType)
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
                        val count = dp.getValue(UserActivityReader.aggregatedStepDataType.fields[0])
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
        result: (List<Map<String, Any?>>?, Throwable?) -> Unit,
    ) {

        val fitnessOptions = getFitnessOptions(sleepDataType)

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val sleepStageNames = arrayOf(
            "Unused",
            "Awake (during sleep)",
            "Sleep",
            "Out-of-bed",
            "Light sleep",
            "Deep sleep",
            "REM sleep"
        )

        val request = SessionReadRequest.Builder()
            .read(sleepDataType)
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
                                val sleepStage = sleepStageNames[sleepStageVal]
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
        result: (List<DataPoint>?, Throwable?) -> Unit,
    ) {
        val fitnessOptions = getFitnessOptions(heartRateDataType)

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
        result: (DataPointValue?, Throwable?) -> Unit,
    ) {
        val fitnessOptions = getFitnessOptions(bodyFatDataType)

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder().read(bodyFatDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .setLimit(1)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp =
                    readDataResult.dataSets.lastOrNull()?.dataPoints?.lastOrNull()
                val lastBodyFat = dp?.getValue(bodyFatDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS)

                if (lastBodyFat != null && dateInMillis != null) {
                    val value = DataPointValue(
                        dateInMillis = dateInMillis,
                        value = lastBodyFat,
                        units = LumenUnit.PERCENT,
                        sourceApp = dp.originalDataSource.appPackageName,
                    )
                    activity.runOnUiThread {
                        result(value, null)
                    }
                } else {
                    activity.runOnUiThread {
                        result(null, null)
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

    private fun getMenstruationData(
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        val fitnessOptions = getFitnessOptions(menstruationDataType)

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder().read(menstruationDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByTime(1, TimeUnit.DAYS)
            .setLimit(1)
            .build()

        Fitness.getHistoryClient(activity, gsa)
            .readData(request)
            .addOnSuccessListener { response ->
                val resultList = mutableListOf<DataPointValue>()
                for (dataSet in response.buckets.flatMap { it.dataSets }) {
                    dataSet
                        .dataPoints
                        .lastOrNull()
                        ?.let {
                            try {
                                resultList.add(
                                    DataPointValue(
                                        dateInMillis = it.getTimestamp(TimeUnit.MILLISECONDS),
                                        value = it.getValue(menstruationDataType.fields[0]).asInt().toFloat(),
                                        units = LumenUnit.COUNT,
                                        sourceApp = it.originalDataSource.appPackageName
                                    )
                                )
                            } catch (e: Exception) {
                                sendNativeLog("$TAG | \tFailed to parse data point, ${e.localizedMessage}")
                                handleGoogleDisconnection(e, activity)
                            }
                        }
                }
                result(resultList, null)
            }
            .addOnFailureListener { exception ->
                result(null, exception)
            }
    }

    private fun getWeight(
        startTime: Long,
        endTime: Long,
        result: (DataPointValue?, Throwable?) -> Unit,
    ) {
        val fitnessOptions = getFitnessOptions(weightDataType)

        val activity = activity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)

        val request = DataReadRequest.Builder().read(weightDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .setLimit(1)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

        Thread {
            try {
                val readDataResult = Tasks.await(response)
                val dp =
                    readDataResult.dataSets.lastOrNull()?.dataPoints?.lastOrNull()
                val lastWeight = dp?.getValue(weightDataType.fields[0])?.asFloat()
                val dateInMillis = dp?.getTimestamp(TimeUnit.MILLISECONDS)

                if (lastWeight != null && dateInMillis != null) {
                    val value = DataPointValue(
                        dateInMillis = dateInMillis,
                        value = lastWeight,
                        units = LumenUnit.KG,
                        sourceApp = dp.originalDataSource.appPackageName,
                    )
                    activity.runOnUiThread {
                        result(value, null)
                    }
                } else {
                    activity.runOnUiThread {
                        result(null, null)
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>?,
        grantResults: IntArray?,
    ): Boolean {
        return when (requestCode) {
            SENSOR_PERMISSION_REQUEST_CODE -> {
                val result = this.deferredResult!!
                this.deferredResult = null
                if (grantResults?.isNotEmpty() == true && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    if (isAuthorized(CallDataType.HEART_RATE)) {
                        recordDataPointsIfGranted(true, callTypeToDataTypes(CallDataType.HEART_RATE), result)
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
