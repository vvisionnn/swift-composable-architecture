#if canImport(UIKit) && !os(watchOS)
import UIKit

open class PresentationDocumentPickerViewController: UIDocumentPickerViewController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
#endif
