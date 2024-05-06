#if canImport(UIKit)
import UIKit
import Combine

open class PresentationViewController: UIViewController, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)? = nil
	public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
#endif
