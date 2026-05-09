import SwiftUI

struct ImportView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroSection

                        VStack(alignment: .leading, spacing: 18) {
                            AppStatusPill(text: "轨迹导入", tint: AppDesign.accentDeep)

                            Text("把轨迹带回家")
                                .font(.appTitle)
                                .foregroundColor(AppDesign.ink)

                            Text("支持本地文件、微信和网盘来源的 GPX 导入。导入后会自动解析、清洗异常点，并生成可离线查看的地图与海拔剖面。")
                                .font(.appBody)
                                .foregroundColor(AppDesign.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(action: { showDocumentPicker = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.down.on.square")
                                    Text("选择 GPX 文件")
                                }
                            }
                            .buttonStyle(AppPrimaryButtonStyle())

                            statusSection
                        }
                        .padding(24)
                        .appCardStyle()
                    }
                    .padding(.horizontal, AppDesign.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitle(Text("轨迹导入"), displayMode: .large)
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(
                    documentTypes: [
                        "com.topografix.gpx",
                        "com.gpx.gpx",
                        "public.xml",
                        "public.text",
                        "public.plain-text",
                        "public.data",
                        "public.content"
                    ],
                    onPick: { urls in
                    if let url = urls.first {
                        store.importGPX(from: url)
                    }
                    showDocumentPicker = false
                })
            }
        }
    }

    private var heroSection: some View {
            ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppDesign.surface, AppDesign.panel, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppDesign.accent.opacity(0.18))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: -40)

            VStack(alignment: .leading, spacing: 14) {
                Text("TrailLog")
                    .font(.appCaption)
                    .foregroundColor(AppDesign.accent)

                Text("把每一次山行，写成一段可回看的路线。")
                    .font(.appHero)
                    .foregroundColor(AppDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("导入 GPX 后，应用会帮你清理噪点、整理统计，再把路线、海拔与时间安静地留在这里。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            }
            .padding(24)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppDesign.line, lineWidth: 1)
        )
        .shadow(color: AppDesign.shadow, radius: 24, x: 0, y: 12)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let status = store.importStatus {
            AppStatusPill(text: status, tint: AppDesign.secondaryInk)
        }

        if let error = store.lastError {
            Text(error)
                .font(.appCaption)
                .foregroundColor(AppDesign.error)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppDesign.error.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
