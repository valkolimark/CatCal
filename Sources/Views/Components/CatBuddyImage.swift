import SwiftUI

/// The cat peeking up from the bottom of Today and Tasks.
///
/// Real artwork goes in the `CatBuddy` image set (`Sources/Resources/
/// Assets.xcassets/CatBuddy.imageset`) — drop 1x/2x/3x PNGs onto it in
/// Xcode and this picks them up with no code change. Until then it falls
/// back to an SF Symbol so layout and spacing are already correct.
struct CatBuddyImage: View {
    var height: CGFloat = 190

    private var hasArtwork: Bool {
        UIImage(named: "CatBuddy") != nil
    }

    var body: some View {
        Group {
            if hasArtwork {
                Image("CatBuddy")
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "cat.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(CatCalColor.brandSecondary.opacity(0.35))
                    .padding(height * 0.18)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        CatCalBackground()
        VStack {
            Spacer()
            CatBuddyImage()
        }
    }
}
