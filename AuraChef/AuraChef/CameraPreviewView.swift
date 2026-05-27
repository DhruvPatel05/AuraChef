//
//  Untitled.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @MainActor
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        // Fetch the active video preview channel from our isolated actor pipeline
        Task {
            let previewLayer = await VisionService.shared.getPreviewLayer()
            await MainActor.run {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Dynamically update sublayer bounds when dimensions change or device rotates
        if let sublayers = uiView.layer.sublayers {
            for layer in sublayers where layer is AVCaptureVideoPreviewLayer {
                layer.frame = uiView.bounds
            }
        }
    }
}
