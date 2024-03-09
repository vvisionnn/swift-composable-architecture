import SwiftUI

open class HostingPresentationViewController<Content: View>: UIHostingController<Content>, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)? = nil
	public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
