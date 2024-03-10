import SwiftUI

open class HostingPresentationViewController<
	Content: View
>: UIHostingController<Content>, ViewControllerPresentable {
	public var onDismiss: (@MainActor () -> Void)? = nil
	public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	public override init(rootView: Content) {
		super.init(rootView: rootView)
	}
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
	
	@available(*, unavailable)
	@MainActor required dynamic public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
