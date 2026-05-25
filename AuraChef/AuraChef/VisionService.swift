//
//  VisionService.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import Foundation
import AVFoundation
import Vision

@globalActor
actor CameraPipelineActor {
    static let shared = CameraPipelineActor()
}

@CameraPipelineActor
final class VisionService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    static let shared = VisionService()

    private let captureSession = AVCaptureSession()
    private var continuation: AsyncThrowingStream<[String], Error>.Continuation?
    
    func startScanning() -> AsyncThrowingStream<[String], Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            do {
                try configureCaptureSession()
                captureSession.startRunning()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        continuation?.finish()
        continuation = nil
    }
    
    private func configureCaptureSession() throws {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceUnavailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        let videoOutput = AVCaptureVideoDataOutput()
        
        captureSession.beginConfiguration()
        if captureSession.canAddInput(videoInput) { captureSession.addInput(videoInput) }
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.aurachef.vision-queue"))
        captureSession.commitConfiguration()
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: cvBuffer, orientation: .up, options: [:])
        
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                Task { await self.continuation?.finish(throwing: error) }
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            
            Task { await self.yieldTokens(recognizedStrings) }
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        try? requestHandler.perform([textRequest])
    }
    
    private func yieldTokens(_ tokens: [String]) {
        guard !tokens.isEmpty else { return }
        continuation?.yield(tokens)
    }
}

enum CameraError: Error {
    case deviceUnavailable
}
