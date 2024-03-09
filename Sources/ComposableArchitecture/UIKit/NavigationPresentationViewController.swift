import UIKit

open class NavigationPresentationViewController: UINavigationController, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)? = nil
	public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
