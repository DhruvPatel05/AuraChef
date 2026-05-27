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

    @MainActor var currentSampleBuffer: CMSampleBuffer? = nil
    
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
    
    @CameraPipelineActor
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
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
    
    private func yieldTokens(_ tokens: [String]) {
        guard !tokens.isEmpty else { return }
        continuation?.yield(tokens)
    }
    
    @MainActor
    func updateSampleBuffer(_ buffer: CMSampleBuffer) {
        self.currentSampleBuffer = buffer
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            // FIXED: Call the isolated setter method instead of mutating the property directly
            Task { @MainActor in
                await VisionService.shared.updateSampleBuffer(sampleBuffer)
            }
            
            // Your text extraction pipeline remains completely unchanged below:
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
}

enum CameraError: Error {
    case deviceUnavailable
}

extension VisionService {
    /// Analyzes a frozen frame buffer to detect standard grocery barcodes (UPC/EAN)
    @CameraPipelineActor
    func scanBarcodeInFrame(_ sampleBuffer: CMSampleBuffer) async -> String? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNBarcodeObservation],
                      let firstBarcode = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Return the raw payload string (the 12-digit UPC number)
                continuation.resume(returning: firstBarcode.payloadStringValue)
            }
            
            // Set the scanning targeting rules to look for standard grocery symbologies
            request.symbologies = [.upce, .ean13, .ean8]
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }
    
    /// Quick network utility helper that hits the open-source OpenFoodFacts database API
    func fetchProductNameFromWeb(barCode: String) async -> String? {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barCode).json"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let product = json["product"] as? [String: Any],
               let productName = product["product_name"] as? String, !productName.isEmpty {
                return productName
            }
        } catch {
            print("Network lookup failed: \(error)")
        }
        return nil
    }
    
    func classifyImageFrame(_ sampleBuffer: CMSampleBuffer) async -> String? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        return await withCheckedContinuation { continuation in
            // Create the native system image classification request
            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter for classifications with a high confidence rating (> 60%)
                // Look for common kitchen items or agricultural food identifiers
                let highConfidenceResults = results
                    .filter { $0.confidence > 0.60 }
                    .map { $0.identifier.lowercased() }
                
                // Return the top matched food identifier (e.g., "banana", "tomato")
                continuation.resume(returning: highConfidenceResults.first)
            }
            
            // Execute the request over the target frame image coordinates
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }
}
