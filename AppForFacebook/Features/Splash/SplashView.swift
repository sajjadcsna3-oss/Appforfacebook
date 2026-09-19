//
//  SplashView.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//

import SwiftUI

struct SplashView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.060, blue: 0.070)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.48, blue: 0.96),
                                    Color(red: 0.12, green: 0.32, blue: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 122, height: 122)

                    Image("AppIcon")
                        .font(.system(size: 55, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("App for Facebook")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                Text("Your accounts, one window")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 7)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.07))

                        Capsule()
                            .fill(Color.blue)
                            .frame(
                                width: proxy.size.width * max(0, min(progress, 1))
                            )
                    }
                }
                .frame(width: 130, height: 4)
                .padding(.top, 31)

                Spacer()
            }
            .padding(.vertical, 60)
        }
    }
}

