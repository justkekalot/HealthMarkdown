import SwiftUI

/// First-run onboarding: a few doodle-illustrated pages, then the Connect step.
struct IntroCarousel: View {
    /// Called when the user finishes the carousel (taps Continue on the last page).
    let onFinish: () -> Void

    @State private var page = 0
    @State private var appear = false

    private struct Slide {
        let doodle: Doodle.Kind
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        .init(doodle: .heartToDoc,
              title: "Health, into one file",
              body: "HealthMarkdown turns everything in Apple Health into a single clean Markdown document."),
        .init(doodle: .privacy,
              title: "Private by design",
              body: "It's all read on your device. Nothing is uploaded or shared — unless you choose to."),
        .init(doodle: .askAI,
              title: "Made for your AI",
              body: "Hand the file to ChatGPT or Claude, or ask the on-device model how ready you are today."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip
            HStack {
                Spacer()
                Button("Skip") { onFinish() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { i in
                    slideView(slides[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: page)

            // Dots
            HStack(spacing: 8) {
                ForEach(slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Theme.hairline.opacity(0.18))
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
                }
            }
            .padding(.bottom, 24)

            Button {
                if page < slides.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < slides.count - 1 ? "Next" : "Get started")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appear = true } }
    }

    private func slideView(_ s: Slide) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Doodle(kind: s.doodle)
                .frame(maxWidth: 280)
                .padding(.horizontal, 40)
            Spacer().frame(height: 44)
            VStack(spacing: 14) {
                Text(s.title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(s.body)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Spacer()
        }
    }
}
