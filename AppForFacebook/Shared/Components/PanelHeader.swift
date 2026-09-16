import SwiftUI

struct PanelHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 10) { Image(icon).foregroundStyle(Color.facebookBlue); Text(title).font(.title3.bold()); Spacer() }
    }
}
