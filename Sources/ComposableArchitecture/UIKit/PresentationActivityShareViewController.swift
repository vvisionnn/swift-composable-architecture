#if canImport(UIKit)
import UIKit

open class PresentationActivityShareViewController: UIActivityViewController, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)?
  public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
#endif
