import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 68))
                    .foregroundColor(.blue)

                Text("导入 GPX 轨迹")
                    .font(.title2)
                    .bold()
                Text("支持本地文件、微信、网盘等来源的 GPX 文件导入解析，离线查看轨迹详情。")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: { showDocumentPicker = true }) {
                    Label("选择 GPX 文件", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if let status = store.importStatus {
                    Text(status)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                if let error = store.lastError {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("轨迹导入")
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(supportedTypes: [UTType(filenameExtension: "gpx")!]) { urls in
                    guard let url = urls.first else { return }
                    Task { await store.importGPX(from: url) }
                }
            }
        }
    }
}
