import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        VStack {
            CameraPreviewView(session: cameraManager.session)
                .onAppear {
                    cameraManager.configure()
                }
                .edgesIgnoringSafeArea(.all)
                .aspectRatio(contentMode: .fill)
            
            Spacer()
            
            HStack {
                Button(action: {
                    cameraManager.startRecording()
                }) {
                    Text("Start Recording")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(cameraManager.isRecording)
                
                Button(action: {
                    cameraManager.stopRecording()
                }) {
                    Text("Stop Recording")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!cameraManager.isRecording)
            }
            .padding()
            
            HStack {
                Button(action: {
                    cameraManager.setFrameRate(120)
                }) {
                    Text("120 fps")
                        .padding()
                        .background(cameraManager.currentFrameRate == 120 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    cameraManager.setFrameRate(240)
                }) {
                    Text("240 fps")
                        .padding()
                        .background(cameraManager.currentFrameRate == 240 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else {
            return
        }
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
