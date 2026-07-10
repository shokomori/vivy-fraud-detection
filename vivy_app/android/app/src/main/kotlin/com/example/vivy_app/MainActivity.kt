package com.example.vivy_app

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import org.opencv.android.OpenCVLoader
import org.opencv.core.CvType
import org.opencv.core.Mat
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

class MainActivity : FlutterActivity() {
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
			"crop" to hashMapOf(
				"x0" to x0,
				"y0" to y0,
				"x1" to (x1Exclusive - 1),
				"y1" to (y1Exclusive - 1),
			),
			"tensorBytes" to floatBuffer.array(),
		)
	}
}
