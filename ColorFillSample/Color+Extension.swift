import SwiftUICore
import UIKit

extension Color {
    
    func getRGBComponents() -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255), UInt8(alpha * 255))
    }
    
    func getHexString() -> String {
        let rgba = self.getRGBComponents()
        let r = Int(rgba.r)
        let g = Int(rgba.g)
        let b = Int(rgba.b)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
