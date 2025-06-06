//
//  ContentView.swift
//  ColorFillSample
//
//  Created by ksy on 6/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedColor: Color = .blue
    @State private var currentImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var imageViewSize: CGSize = .zero
    @State private var isLoading: Bool = false
    @State private var fillLayers: [UIImage] = []
    private let colorFillManager = ColorFillManager()
    let imgName = "moomin"
    
    // 이미지뷰 좌표를 실제 이미지 좌표로 변환하는 함수
    private func convertToImageCoordinates(_ viewPoint: CGPoint) -> CGPoint? {
        guard let image = currentImage else { return nil }
        
        let imageSize = CGSize(width: image.size.width, height: image.size.height)
        let viewSize = imageViewSize
        
        // 이미지뷰의 비율 계산
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        
        // 좌표 변환
        let imageX = viewPoint.x * scaleX
        let imageY = viewPoint.y * scaleY
        
        return CGPoint(x: imageX, y: imageY)
    }
    
    var body: some View {
        VStack {
            HStack {
                ColorPicker("색상 선택", selection: $selectedColor)
                    .padding()
                    .labelsHidden()
                
                let rgb = selectedColor.getRGBComponents()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("선택된 색상")
                        .foregroundColor(selectedColor)
                        .padding()
                    Text("RGB: \(Int(rgb.r)), \(Int(rgb.g)), \(Int(rgb.b))")
                        .foregroundColor(selectedColor)
                    Text("HEX: \(selectedColor.getHexString())")
                        .foregroundColor(selectedColor)
                }
                .font(.system(.body, design: .monospaced))
                .padding()
                
                Button(action: {
                    if let original = originalImage {
                        currentImage = original
                        fillLayers.removeAll()
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .padding()
                .disabled(isLoading)
            }
            
            if let image = currentImage {
                ZStack {
                    // 기본 이미지
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250)
                    
                    // 채워진 레이어들
                    ForEach(fillLayers.indices, id: \.self) { index in
                        Image(uiImage: fillLayers[index])
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250)
                    }
                    
                    // 로딩 오버레이
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.onAppear {
                            imageViewSize = geometry.size
                        }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard !isLoading else { return }
                            let location = value.location
                            if let imagePoint = convertToImageCoordinates(location),
                               let currentImage = currentImage {
                                Task {
                                    isLoading = true
                                    if let filledImage = await colorFillManager.floodFill(
                                        at: imagePoint,
                                        in: currentImage,
                                        to: selectedColor
                                    ) {
                                        await MainActor.run {
                                            fillLayers.append(filledImage)
                                        }
                                    }
                                    isLoading = false
                                }
                            }
                        }
                )
                .disabled(isLoading)
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .onAppear {
            if let image = UIImage(named: imgName) {
                originalImage = image
                currentImage = image
            }
        }
    }
}

#Preview {
    ContentView()
}
