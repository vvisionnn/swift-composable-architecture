import UIKit

open class PresentationActivityShareViewController: UIActivityViewController, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)?
	public var currentPresentedViewController: (ViewControllerPresentable)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
