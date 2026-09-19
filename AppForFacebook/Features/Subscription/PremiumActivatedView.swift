//
//  PremiumActivatedView.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//
import SwiftUI

struct PremiumActivatedView: View {
    let onBackToDesk: () -> Void
    let onAddAccount: () -> Void
    let onTryAI: () -> Void
    let onDockAccount: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.green)
                        .background(Circle().fill(Color(red: 0.075, green: 0.082, blue: 0.102)))
                        .offset(x: 23, y: 23)
                }

                Text("You’re on Premium")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Text("Your purchase is active. Everything below is available right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 8)
                    .frame(maxWidth: 310)

                VStack(spacing: 9) {
                    actionRow(
                        title: "Add your other accounts",
                        icon: "person.badge.plus",
                        action: onAddAccount
                    )

                    actionRow(
                        title: "Try AI assist on a thread",
                        icon: "sparkles",
                        action: onTryAI
                    )

                    actionRow(
                        title: "Dock a second account",
                        icon: "rectangle.split.2x1",
                        action: onDockAccount
                    )
                }
                .padding(.top, 20)

                Button(action: onBackToDesk) {
                    Text("Back to the desk")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                Text("Receipt handled by the App Store · Manage or cancel in Apple ID settings")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            .padding(26)
            .frame(width: 410)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.060, blue: 0.073))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 35, y: 12)
        }
    }

    private func actionRow(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.blue)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.84))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
