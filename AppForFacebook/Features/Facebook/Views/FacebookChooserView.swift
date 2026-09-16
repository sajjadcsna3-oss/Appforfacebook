import SwiftUI

struct FacebookChooserView: View {
    let openFacebook: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("App For Facebook")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 0.095, green: 0.10, blue: 0.11))
            HStack(spacing: 0) {
                introduction
                Divider()
                facebookChoice
            }
        }
        .background(Color.appBackground)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Image("Background")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
            Text("All the chrome in one bar.")
                .font(.system(size: 34, weight: .bold))
            Text("Tabs and tools stay out of the way, so Facebook gets the whole window.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(8)
                .frame(maxWidth: 490, alignment: .leading)
            
            Divider()
            .padding(.top, 28)
            benefit("lockIcon", "Your Facebook session stays on this Mac")
            benefit("lock2Icon", "Facebook credentials are entered only on facebook.com")
            benefit("lock3Icon", "Your password never reaches this app")
            Spacer()
        }
        .padding(.horizontal, 56).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var facebookChoice: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("CHOOSE A PLATFORM").font(.caption.monospaced()).tracking(3).foregroundStyle(.secondary)
            Button(action: openFacebook) {
                HStack(spacing: 14) {
                    Image("facbookloginIcon").resizable().scaledToFit().frame(width: 24, height: 24)
                    Text("Facebook").font(.title3.bold())
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.horizontal, 20).frame(height: 66).frame(maxWidth: .infinity)
                .background(Color.facebookBlue).clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.white)
            Text("Facebook is the only platform supported in this version.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 72).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        Label { Text(text) } icon: { Image(icon) }.foregroundStyle(.secondary).symbolRenderingMode(.hierarchical)
    }
}
