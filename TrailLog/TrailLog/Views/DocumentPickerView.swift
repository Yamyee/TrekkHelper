import SwiftUI
import UIKit

struct DocumentPickerView: View {
    let documentTypes: [String]
    let onPick: ([URL]) -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        DocumentPickerWrapper(documentTypes: documentTypes, onPick: { urls in
            onPick(urls)
            presentationMode.wrappedValue.dismiss()
        })
    }
}

private struct DocumentPickerWrapper: UIViewControllerRepresentable {
    let documentTypes: [String]
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
