import SwiftUI
import UIKit

struct BikePhotoView: View {
    let data: Data?
    var height: CGFloat = 160

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.12)
                    Image(systemName: "motorcycle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(data == nil ? "No bike photo" : "Bike photo")
    }
}
