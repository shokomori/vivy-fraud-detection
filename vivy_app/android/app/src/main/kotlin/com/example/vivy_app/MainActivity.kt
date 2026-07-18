package com.example.vivy_app

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfDouble
import org.opencv.core.MatOfPoint
import org.opencv.core.Rect
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

private const val CHANNEL = "vivy/preprocess"
private const val TAG = "VivyPreprocess"
private const val INPUT_SIZE = 224
private const val MIN_AREA_RATIO = 0.12
private const val MIN_ASPECT = 0.25
private const val MAX_ASPECT = 3.5
private const val TEMPLATE_CONFIDENCE_FLOOR = 0.55
private const val TEMPLATE_CONFIDENCE_CEIL = 0.95

private val ZONE_LAYOUTS: Map<String, Map<String, DoubleArray>> = mapOf(
	"android-like" to mapOf(
		"transaction_amount" to doubleArrayOf(0.52, 0.16, 0.95, 0.32),
		"reference_number" to doubleArrayOf(0.52, 0.34, 0.95, 0.48),
		"timestamp" to doubleArrayOf(0.52, 0.50, 0.95, 0.63),
		"name_block" to doubleArrayOf(0.08, 0.66, 0.95, 0.84),
	),
	"ios-like" to mapOf(
		"transaction_amount" to doubleArrayOf(0.50, 0.18, 0.94, 0.34),
		"reference_number" to doubleArrayOf(0.50, 0.35, 0.94, 0.50),
		"timestamp" to doubleArrayOf(0.50, 0.52, 0.94, 0.66),
		"name_block" to doubleArrayOf(0.08, 0.67, 0.94, 0.86),
	),
)

class MainActivity : FlutterActivity() {
	data class GlyphStat(
		val centerX: Double,
		val centerY: Double,
		val height: Double,
	)

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"preprocessReceipt" -> {
					val path = call.argument<String>("path")
					if (path.isNullOrBlank()) {
						result.error("invalid_args", "Missing image path", null)
						return@setMethodCallHandler
					}

					try {
						Log.i(TAG, "preprocessReceipt invoked. path=$path")
						if (!OpenCVLoader.initDebug()) {
							Log.e(TAG, "OpenCV init failed")
							result.error("opencv_init_failed", "OpenCV failed to initialize", null)
							return@setMethodCallHandler
						}
						Log.i(TAG, "OpenCV init succeeded")
						result.success(preprocessReceipt(path))
					} catch (t: Throwable) {
						Log.e(TAG, "Native preprocess failed", t)
						result.error("preprocess_failed", t.message, null)
					}
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun preprocessReceipt(path: String): HashMap<String, Any> {
		val file = File(path)
		if (!file.exists()) {
			throw IllegalArgumentException("Image does not exist: $path")
		}

		val bgr = Imgcodecs.imread(path, Imgcodecs.IMREAD_COLOR)
		if (bgr.empty()) {
			throw IllegalArgumentException("Failed to decode image: $path")
		}

		val h = bgr.rows()
		val w = bgr.cols()

		val gray = Mat()
		Imgproc.cvtColor(bgr, gray, Imgproc.COLOR_BGR2GRAY)

		val blur = Mat()
		Imgproc.GaussianBlur(gray, blur, Size(5.0, 5.0), 0.0)

		val thresh = Mat()
		Imgproc.threshold(blur, thresh, 0.0, 255.0, Imgproc.THRESH_BINARY + Imgproc.THRESH_OTSU)

		val kernel = Mat.ones(5, 5, CvType.CV_8U)
		val closed = Mat()
		Imgproc.morphologyEx(
			thresh,
			closed,
			Imgproc.MORPH_CLOSE,
			kernel,
			org.opencv.core.Point(-1.0, -1.0),
			2,
		)

		val contours = ArrayList<MatOfPoint>()
		Imgproc.findContours(closed, contours, Mat(), Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE)

		val minArea = MIN_AREA_RATIO * h * w
		var bestRect: Rect? = null
		var bestArea = 0.0
		for (c in contours) {
			val area = Imgproc.contourArea(c)
			if (area < minArea) continue
			val rect = Imgproc.boundingRect(c)
			val aspect = rect.width.toDouble() / maxOf(1.0, rect.height.toDouble())
			if (aspect in MIN_ASPECT..MAX_ASPECT && area > bestArea) {
				bestRect = rect
				bestArea = area
			}
		}

		if (bestRect == null) {
			Log.w(TAG, "ROI rejected by native geometry gate")
			return hashMapOf(
				"backend" to "native-opencv",
				"reason" to "geometry gate failed",
				"geometryPass" to false,
				"areaRatio" to 0.0,
				"aspectRatio" to 0.0,
				"templateFamily" to "generic",
				"templateConfidence" to 0.0,
				"zoneMetrics" to hashMapOf<String, HashMap<String, Double>>(),
			)
		}

		val rect = bestRect
		val areaRatio = bestArea / (h * w)
		val aspectRatio = rect.width.toDouble() / maxOf(1.0, rect.height.toDouble())

		val padX = (0.03 * rect.width).toInt()
		val padY = (0.03 * rect.height).toInt()
		val x0 = maxOf(rect.x - padX, 0)
		val y0 = maxOf(rect.y - padY, 0)
		val x1Exclusive = minOf(rect.x + rect.width + padX, w)
		val y1Exclusive = minOf(rect.y + rect.height + padY, h)

		val cropW = maxOf(1, x1Exclusive - x0)
		val cropH = maxOf(1, y1Exclusive - y0)
		val roiRect = Rect(x0, y0, cropW, cropH)
		val roi = Mat(bgr, roiRect)
		val roiGray = Mat()
		Imgproc.cvtColor(roi, roiGray, Imgproc.COLOR_BGR2GRAY)
		val templatePrediction = inferTemplateFamily(cropW, cropH)
		val zoneMetrics = extractZoneMetrics(roiGray, templatePrediction.first)

		val resized = Mat()
		Imgproc.resize(roi, resized, Size(INPUT_SIZE.toDouble(), INPUT_SIZE.toDouble()), 0.0, 0.0, Imgproc.INTER_AREA)

		val rgb = Mat()
		Imgproc.cvtColor(resized, rgb, Imgproc.COLOR_BGR2RGB)

		val rgbBytes = ByteArray(INPUT_SIZE * INPUT_SIZE * 3)
		rgb.get(0, 0, rgbBytes)

		val floatBuffer = ByteBuffer
			.allocate(rgbBytes.size * 4)
			.order(ByteOrder.LITTLE_ENDIAN)

		for (byteVal in rgbBytes) {
			val u = byteVal.toInt() and 0xFF
			floatBuffer.putFloat(u / 255.0f)
		}

		Log.i(TAG, "Native preprocess succeeded. crop=($x0,$y0)-(${x1Exclusive - 1},${y1Exclusive - 1}), areaRatio=$areaRatio, aspectRatio=$aspectRatio")

		return hashMapOf(
			"backend" to "native-opencv",
			"reason" to "ok",
			"geometryPass" to true,
			"areaRatio" to areaRatio,
			"aspectRatio" to aspectRatio,
			"templateFamily" to templatePrediction.first,
			"templateConfidence" to templatePrediction.second,
			"zoneMetrics" to zoneMetrics,
			"crop" to hashMapOf(
				"x0" to x0,
				"y0" to y0,
				"x1" to (x1Exclusive - 1),
				"y1" to (y1Exclusive - 1),
			),
			"tensorBytes" to floatBuffer.array(),
		)
	}

	private fun inferTemplateFamily(roiWidth: Int, roiHeight: Int): Pair<String, Double> {
		val aspect = roiWidth.toDouble() / maxOf(1.0, roiHeight.toDouble())
		val androidTarget = 0.62
		val iosTarget = 0.56
		val dAndroid = kotlin.math.abs(aspect - androidTarget)
		val dIos = kotlin.math.abs(aspect - iosTarget)
		val family = if (dAndroid <= dIos) "android-like" else "ios-like"
		val separation = kotlin.math.abs(dAndroid - dIos)
		val confidence = (0.75 + (separation * 2.2)).coerceIn(
			TEMPLATE_CONFIDENCE_FLOOR,
			TEMPLATE_CONFIDENCE_CEIL,
		)
		return Pair(family, confidence)
	}

	private fun extractZoneMetrics(
		roiGray: Mat,
		templateFamily: String,
	): HashMap<String, HashMap<String, Double>> {
		val layout = ZONE_LAYOUTS[templateFamily] ?: ZONE_LAYOUTS["android-like"]!!
		val output = HashMap<String, HashMap<String, Double>>()
		for ((zoneName, bounds) in layout) {
			val zone = cropNormalized(roiGray, bounds)
			output[zoneName] = computeZoneMetrics(zone)
		}
		return output
	}

	private fun cropNormalized(gray: Mat, bounds: DoubleArray): Mat {
		val x0 = ((bounds[0] * gray.cols()).toInt()).coerceIn(0, gray.cols() - 1)
		val y0 = ((bounds[1] * gray.rows()).toInt()).coerceIn(0, gray.rows() - 1)
		val x1 = ((bounds[2] * gray.cols()).toInt()).coerceIn(x0 + 1, gray.cols())
		val y1 = ((bounds[3] * gray.rows()).toInt()).coerceIn(y0 + 1, gray.rows())
		return Mat(gray, Rect(x0, y0, maxOf(1, x1 - x0), maxOf(1, y1 - y0)))
	}

	private fun computeZoneMetrics(zoneGray: Mat): HashMap<String, Double> {
		val lap = Mat()
		Imgproc.Laplacian(zoneGray, lap, CvType.CV_64F)
		val mean = MatOfDouble()
		val std = MatOfDouble()
		Core.meanStdDev(lap, mean, std)
		val lapStd = std.toArray().firstOrNull() ?: 0.0
		val lapVar = lapStd * lapStd

		val edges = Mat()
		Imgproc.Canny(zoneGray, edges, 80.0, 180.0)
		val edgeDensity = Core.countNonZero(edges).toDouble() /
			maxOf(1.0, (zoneGray.rows() * zoneGray.cols()).toDouble())

		val binInv = Mat()
		Imgproc.threshold(
			zoneGray,
			binInv,
			0.0,
			255.0,
			Imgproc.THRESH_BINARY_INV + Imgproc.THRESH_OTSU,
		)
		val strokeFillRatio = Core.countNonZero(binInv).toDouble() /
			maxOf(1.0, (zoneGray.rows() * zoneGray.cols()).toDouble())

		val labels = Mat()
		val stats = Mat()
		val centroids = Mat()
		val numLabels = Imgproc.connectedComponentsWithStats(
			binInv,
			labels,
			stats,
			centroids,
			8,
			CvType.CV_32S,
		)

		val glyphs = ArrayList<GlyphStat>()
		for (i in 1 until numLabels) {
			val area = stats.get(i, Imgproc.CC_STAT_AREA)?.firstOrNull() ?: 0.0
			val w = stats.get(i, Imgproc.CC_STAT_WIDTH)?.firstOrNull() ?: 0.0
			val h = stats.get(i, Imgproc.CC_STAT_HEIGHT)?.firstOrNull() ?: 0.0
			if (area < 10.0 || w < 2.0 || h < 4.0) {
				continue
			}
			val cx = centroids.get(i, 0)?.firstOrNull() ?: 0.0
			val cy = centroids.get(i, 1)?.firstOrNull() ?: 0.0
			glyphs.add(GlyphStat(centerX = cx, centerY = cy, height = h))
		}

		val (spacingCv, alignmentStd, fontHeightCv) = if (glyphs.size < 4) {
			Triple(0.0, 0.0, 0.0)
		} else {
			val xs = glyphs.map { it.centerX }.sorted()
			val gaps = ArrayList<Double>()
			for (i in 1 until xs.size) {
				val gap = xs[i] - xs[i - 1]
				if (gap > 1.0) {
					gaps.add(gap)
				}
			}

			val spacingCvLocal = if (gaps.size < 2) {
				0.0
			} else {
				stddev(gaps) / maxOf(1e-6, mean(gaps))
			}

			val ys = glyphs.map { it.centerY }
			val hs = glyphs.map { it.height }
			val alignLocal = stddev(ys) / maxOf(1.0, zoneGray.rows().toDouble())
			val fontCvLocal = stddev(hs) / maxOf(1e-6, mean(hs))
			Triple(spacingCvLocal, alignLocal, fontCvLocal)
		}

		return hashMapOf(
			"laplacian_var" to lapVar,
			"edge_density" to edgeDensity,
			"spacing_cv" to spacingCv,
			"alignment_std" to alignmentStd,
			"font_height_cv" to fontHeightCv,
			"stroke_fill_ratio" to strokeFillRatio,
		)
	}

	private fun mean(values: List<Double>): Double {
		if (values.isEmpty()) return 0.0
		var sum = 0.0
		for (v in values) {
			sum += v
		}
		return sum / values.size
	}

	private fun stddev(values: List<Double>): Double {
		if (values.size < 2) return 0.0
		val m = mean(values)
		var sumSq = 0.0
		for (v in values) {
			val d = v - m
			sumSq += d * d
		}
		return kotlin.math.sqrt(sumSq / values.size)
	}
}
