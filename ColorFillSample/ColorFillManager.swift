import UIKit
import SwiftUICore

final class ColorFillManager {
    
    func floodFill(at point: CGPoint,
                       in inputImg: UIImage,
                       to fillColor: Color,
                       similarThreshold: Double = 95) async -> UIImage? {
        
        let task = Task<UIImage?, Never> {
            let color = fillColor.getRGBComponents()
            
            // 1. UIImage에서 CGImage를 추출 (픽셀 데이터 접근을 위해 필요)
            guard let inputCGImg = inputImg.cgImage else { return nil }
            
            // 2. 이미지의 크기 및 픽셀 데이터 관련 정보 설정
            let width = inputCGImg.width                  // 이미지 너비
            let height = inputCGImg.height                // 이미지 높이
            let bytesPerPixel = 4                      // RGBA 채널: 4바이트
            let bitsPerComponent = 8                   // 각 채널당 8비트
            let bytesPerRow = bytesPerPixel * width     // 한 행의 총 바이트 수

            // 3. CGImage의 dataProvider를 통해 원본 픽셀 데이터에 접근
            guard let inputImgDataProvider = inputCGImg.dataProvider else { return nil }
            guard let inputImgPixelData = inputImgDataProvider.data else { return nil }
            
            // 4. 결과 이미지를 위한 빈 버퍼 생성 (투명한 배경)
            let mutableEmptyData = CFDataCreateMutable(nil, 0)
            CFDataSetLength(mutableEmptyData, Int(width * height * bytesPerPixel))
            guard let outputPtr = CFDataGetMutableBytePtr(mutableEmptyData) else { return nil }
            
            // 모든 픽셀을 투명하게 초기화
            for i in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
                outputPtr[i] = 0     // R
                outputPtr[i + 1] = 0 // G
                outputPtr[i + 2] = 0 // B
                outputPtr[i + 3] = 0 // A (투명)
            }

            // 5. 원본 이미지를 수정 가능한 버퍼로 복사
            let inputImgMutableData = CFDataCreateMutableCopy(nil, CFDataGetLength(inputImgPixelData), inputImgPixelData)
            guard let inputPixelPtr = CFDataGetMutableBytePtr(inputImgMutableData) else { return nil }

            // 6. 시작점의 픽셀 위치 계산
            let byteIndex = (Int(point.y) * width + Int(point.x)) * bytesPerPixel

            // 7. 시작점 픽셀의 색상을 originalColor 변수에 저장
            let originalColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) = (inputPixelPtr[byteIndex], inputPixelPtr[byteIndex+1], inputPixelPtr[byteIndex+2], inputPixelPtr[byteIndex+3])
            
            // 8. 시작점의 색상이 이미 채울 색상과 다를 경우에만 플러드 필 수행
            if originalColor == color { return nil }

            // 채워진 영역의 경계를 추적하기 위한 변수들
            var minX = Int(point.x)
            var maxX = Int(point.x)
            var minY = Int(point.y)
            var maxY = Int(point.y)
            
            // 스택을 사용하여 처리할 좌표를 저장 (시작점을 스택에 추가)
            var stack: [(Int, Int)] = [(Int(point.x), Int(point.y))]

            // 색상 유사도 캐시 딕셔너리 추가
            var similarityCache: [UInt64: Double] = [:]
            
            // 방문한 픽셀을 추적하기 위한 Set 추가
            var visited = Set<Int>()
            
            // 캐시를 활용하는 지역 함수로 색상 유사도 계산
            func getCachedColorSimilarity(at index: Int, with targetColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Double {
                let currentColor = (
                    inputPixelPtr[index],
                    inputPixelPtr[index + 1],
                    inputPixelPtr[index + 2],
                    inputPixelPtr[index + 3]
                )
                
                let cacheKey = makeCacheKey(rgba1: currentColor, rgba2: targetColor)
                
                if let cachedValue = similarityCache[cacheKey] {
                    return cachedValue
                }
                
                let similarity = colorSimilarity(rgba1: currentColor, rgba2: targetColor)
                similarityCache[cacheKey] = similarity
                return similarity
            }

            // 스택이 빌 때까지 반복
            while !stack.isEmpty {
                let (x, y) = stack.removeLast()
                let baseIndex = (y * width + x)
                
                // 이미 방문한 픽셀이면 건너뛰기
                if !visited.insert(baseIndex).inserted {
                    continue
                }
                
                // 현재 행에서 좌우 확장을 위한 초기값 설정
                var left = x - 1   // 왼쪽으로 확장 시작
                var right = x      // 오른쪽은 시작점부터

                // 좌측 확장
                while left >= 0 && getCachedColorSimilarity(
                    at: (y * width + left) * bytesPerPixel,
                    with: originalColor
                ) >= similarThreshold {
                    let pixelIndex = y * width + left
                    
                    if !visited.insert(pixelIndex).inserted {
                        left -= 1
                        continue
                    }
                    
                    minX = min(minX, left)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                    
                    let byteIndex = pixelIndex * bytesPerPixel
                    outputPtr[byteIndex] = color.r
                    outputPtr[byteIndex + 1] = color.g
                    outputPtr[byteIndex + 2] = color.b
                    outputPtr[byteIndex + 3] = color.a
                    
                    left -= 1
                }
                left += 1

                // 우측 확장
                while right < width && getCachedColorSimilarity(
                    at: (y * width + right) * bytesPerPixel,
                    with: originalColor
                ) >= similarThreshold {
                    let pixelIndex = y * width + right
                    
                    if !visited.insert(pixelIndex).inserted {
                        right += 1
                        continue
                    }
                    
                    maxX = max(maxX, right)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                    
                    let byteIndex = pixelIndex * bytesPerPixel
                    outputPtr[byteIndex] = color.r
                    outputPtr[byteIndex + 1] = color.g
                    outputPtr[byteIndex + 2] = color.b
                    outputPtr[byteIndex + 3] = color.a
                    
                    right += 1
                }
                right -= 1
                
//                if maxX - minX + 1 >= width {
//                    return nil
//                }

                // 인접 행 검사
                for newY in [y - 1, y + 1] {
                    if newY >= 0 && newY < height {
                        if right >= left {
                            for newX in left...right {
                                if getCachedColorSimilarity(
                                    at: (newY * width + newX) * bytesPerPixel,
                                    with: originalColor
                                ) >= similarThreshold {
                                    stack.append((newX, newY))
                                }
                            }
                        }
                    }
                }
                
//                if maxY - minY + 1 >= height {
//                    return nil
//                }
            }
            
            // 결과 이미지 생성
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(data: outputPtr,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: bitsPerComponent,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo)
            else {
                return nil
            }

            guard let newCgImage = context.makeImage() else { return nil }
            
            return UIImage(cgImage: newCgImage)
        }
        return await task.value
    }

    // ------------------------------------------------------------------------
    // 두 색상 간 유사도를 계산하는 함수
    // ------------------------------------------------------------------------
    func colorSimilarity(rgba1: (UInt8, UInt8, UInt8, UInt8),
                         rgba2: (UInt8, UInt8, UInt8, UInt8)) -> Double {
        // RGBA 각 채널 값 추출
        let (r1, g1, b1, a1) = rgba1
        let (r2, g2, b2, a2) = rgba2

        // 각 채널별 차이를 절대값으로 계산
        let deltaR = abs(Int(r1) - Int(r2))
        let deltaG = abs(Int(g1) - Int(g2))
        let deltaB = abs(Int(b1) - Int(b2))
        let deltaA = abs(Int(a1) - Int(a2))

        // 단순 비교: 각 채널의 차이를 모두 더함
        let deltaTotal = deltaR + deltaG + deltaB + deltaA
        let maxDifference = 255 * 4  // 가능한 최대 차이 (각 채널 255, 4채널)
        
        // 유사도 계산: (1 - (실제 차이/최대 차이))를 백분율로 변환
        let similarity = (1.0 - Double(deltaTotal) / Double(maxDifference)) * 100
        return similarity
    }

    func getPixelColor(at index: Int, from pixelData: UnsafeMutablePointer<UInt8>, bytesPerPixel: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let baseIndex = index * bytesPerPixel
        return (
            pixelData[baseIndex],
            pixelData[baseIndex + 1],
            pixelData[baseIndex + 2],
            pixelData[baseIndex + 3]
        )
    }

    // 색상 유사도 캐시를 위한 키 생성 함수
    private func makeCacheKey(rgba1: (UInt8, UInt8, UInt8, UInt8), rgba2: (UInt8, UInt8, UInt8, UInt8)) -> UInt64 {
        let key1 = UInt64(rgba1.0) << 56 | UInt64(rgba1.1) << 48 | UInt64(rgba1.2) << 40 | UInt64(rgba1.3) << 32
        let key2 = UInt64(rgba2.0) << 24 | UInt64(rgba2.1) << 16 | UInt64(rgba2.2) << 8 | UInt64(rgba2.3)
        return key1 | key2
    }
}
