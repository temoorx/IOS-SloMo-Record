import AVFoundation
import Photos
import Combine

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice!
    private var fileOutput = AVCaptureMovieFileOutput()
    private var outputURL: URL!
    
    @Published var isRecording = false
    @Published var currentFrameRate: Int = 120 // Default frame rate
    
    func configure() {
        checkPermissions { [weak self] granted in
            guard let self = self, granted else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.setupSession()
            }
        }
    }
    
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        let photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        let group = DispatchGroup()
        var permissionsGranted = true
        
        if cameraStatus == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                permissionsGranted = permissionsGranted && granted
                group.leave()
            }
        } else if cameraStatus != .authorized {
            permissionsGranted = false
        }
        
        if microphoneStatus == .undetermined {
            group.enter()
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                permissionsGranted = permissionsGranted && granted
                group.leave()
            }
        } else if microphoneStatus != .granted {
            permissionsGranted = false
        }
        
        if photoLibraryStatus == .notDetermined {
            group.enter()
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                permissionsGranted = permissionsGranted && (status == .authorized || status == .limited)
                group.leave()
            }
        } else if photoLibraryStatus != .authorized && photoLibraryStatus != .limited {
            permissionsGranted = false
        }
        
        group.notify(queue: .main) {
            completion(permissionsGranted)
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        
        // Select the back wide-angle camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            videoDevice = device
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        }

        // Configure the device for high frame rate capture
        configureFrameRate()
        
        if session.canAddOutput(fileOutput) {
            session.addOutput(fileOutput)
        }
        
        session.commitConfiguration()
        session.startRunning()
    }
    
    func configureFrameRate() {
        guard let videoDevice = videoDevice else { return }
        do {
            try videoDevice.lockForConfiguration()
            
            if let highestFrameRateFormat = videoDevice.formats.filter({ format in
                format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate == 240 })
            }).max(by: { $0.highResolutionStillImageDimensions.width < $1.highResolutionStillImageDimensions.width }) {
                let targetFrameRate = currentFrameRate
                videoDevice.activeFormat = highestFrameRateFormat
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(targetFrameRate))
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(targetFrameRate))
            }
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not configure device for high frame rate: \(error)")
        }
    }
    
    func setFrameRate(_ frameRate: Int) {
        currentFrameRate = frameRate
        configureFrameRate()
    }
    
    func startRecording() {
        let uniqueFileName = UUID().uuidString + ".mov"
        outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueFileName)
        fileOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        fileOutput.stopRecording()
        isRecording = false
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording movie: \(String(describing: error))")
            return
        }
        
        // Save video to the photo library
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { saved, error in
            if saved {
                print("Saved to photo library")
            } else if let error = error {
                print("Error saving to photo library: \(error)")
            }
        }
    }
}
