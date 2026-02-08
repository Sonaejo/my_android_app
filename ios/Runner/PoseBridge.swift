import Foundation
import AVFoundation
import Vision


class PoseBridge: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
private let session = AVCaptureSession()
private var request = VNDetectHumanBodyPoseRequest()
private let queue = DispatchQueue(label: "pose.bridge")
private var channel: FlutterMethodChannel


init(channel: FlutterMethodChannel) {
self.channel = channel
super.init()
}


func start() {
session.beginConfiguration()
session.sessionPreset = .vga640x480
guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
let input = try? AVCaptureDeviceInput(device: device) else { return }
if session.canAddInput(input) { session.addInput(input) }


let output = AVCaptureVideoDataOutput()
output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
output.setSampleBufferDelegate(self, queue: queue)
if session.canAddOutput(output) { session.addOutput(output) }
output.alwaysDiscardsLateVideoFrames = true
if let conn = output.connection(with: .video), conn.isVideoOrientationSupported {
conn.videoOrientation = .landscapeRight
}
session.commitConfiguration()
session.startRunning()
}


func stop() { session.stopRunning() }


func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
let handler = VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .right, options: [:])
do { try handler.perform([request]) } catch { return }
guard let obs = request.results?.first as? VNHumanBodyPoseObservation else { return }
do {
let points = try obs.recognizedPoints(.all)
func pt(_ k: VNHumanBodyPoseObservation.JointName) -> [String: Double]? {
if let p = points[k], p.confidence > 0.2 {
// Visionは(0..1)空間で返す（左上原点）。Flutterはそのまま解釈
return ["x": Double(p.location.x), "y": Double(1.0 - p.location.y)]
}
return nil
}
var map: [String: Any] = [:]
map["leftShoulder"] = pt(.leftShoulder)
map["rightShoulder"] = pt(.rightShoulder)
map["leftElbow"] = pt(.leftElbow)
map["rightElbow"] = pt(.rightElbow)
map["leftWrist"] = pt(.leftWrist)
map["rightWrist"] = pt(.rightWrist)
map["leftHip"] = pt(.leftHip)
map["rightHip"] = pt(.rightHip)
map["leftKnee"] = pt(.leftKnee)
map["rightKnee"] = pt(.rightKnee)
map["leftAnkle"] = pt(.leftAnkle)
map["rightAnkle"] = pt(.rightAnkle)
DispatchQueue.main.async {
self.channel.invokeMethod("onPose", arguments: map)
}
} catch { return }
}
}