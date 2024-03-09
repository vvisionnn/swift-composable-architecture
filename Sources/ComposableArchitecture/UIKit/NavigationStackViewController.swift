import UIKit
import OrderedCollections
import Combine

open class NavigationStackViewController<
	State,
	Action
>: UINavigationController, UINavigationControllerDelegate, ViewControllerPresentable, UIGestureRecognizerDelegate {
	typealias Destinations = OrderedDictionary<StackElementID, UIViewController>
	
	private var store: Store<StackState<State>, StackAction<State, Action>>!
	private var rootDestination: UIViewController!
	private var destinations: Destinations = .init()

	public var onDismiss: (@MainActor () -> Void)? = nil
	public var currentPresentedViewController: (any ViewControllerPresentable)?
	
	@MainActor
	public init() { super.init(nibName: nil, bundle: nil) }
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	open override func viewDidLoad() {
		super.viewDidLoad()
		self.interactivePopGestureRecognizer?.delegate = self
	}
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
	
	public typealias DestinationCreator = @MainActor (
		_ initialState: State,
		_ destinationStore: Store<State, Action>
	) -> UIViewController
	
	@MainActor
	public func navigation(
		_ store: Store<StackState<State>, StackAction<State, Action>>,
		rootViewController: UIViewController,
		destination: @escaping DestinationCreator
	) -> AnyCancellable {
		self.store = store
		self.rootDestination = rootViewController
		self.delegate = self
		return store.publisher
			.removeDuplicates(by: { areOrderedSetsDuplicates($0.ids, $1.ids) })
			.receive(on: RunLoop.main)
			.sink { [weak self] stackState in
				guard let self else { return }
				let newDestinations = stackState.ids
					.reduce(into: Destinations(), { partialResult, id in
						if let originalViewController = self.destinations[id] {
							partialResult[id] = originalViewController
						} else if let state = store.currentState[id: id] {
							partialResult[id] = destination(state, store.scope(
								id: store.id(state: \.[id:id]!, action: \.[id:id]),
								state: ToState(returningLastNonNilValue({ _ in store.currentState[id: id] }, defaultValue: state)),
								action: { .element(id: id, action: $0) },
								isInvalid: { !$0.ids.contains(id) }
							))
						}
					})
				self.destinations = newDestinations
				self.setViewControllers(
					Array([self.rootDestination] + self.destinations.values),
					animated: self.viewIfLoaded?.window != nil
				)
			}
	}
	
	open func navigationController(
		_ navigationController: UINavigationController,
		willShow viewController: UIViewController,
		animated: Bool
	) {
		// if current pop/push isn't intractively, just check directively
		guard self.transitionCoordinator?.isInteractive ?? false else {
			self.checkPath()
			return
		}

		// NOTE: monitor transition status or the path will change if user cancelled the pop back intraction
		self.transitionCoordinator?.notifyWhenInteractionChanges({ [weak self] context in
			guard !context.isCancelled else { return }
			self?.checkPath()
		})
	}
	
	fileprivate func checkPath() {
		// only handle pop, push always triggerred programatically
		// which means the number always same
		let viewControllersFromNavigation = self.viewControllers
		let viewControllersFromState = [self.rootDestination] + self.destinations.values
		
		// calculate the real viewControllers
		// the order will change when pop multiple view controllers by long press back button
		// like: [1, 2, 3, 4] when pop to 2, the order will be [4, 1, 2]
		guard viewControllersFromNavigation.count < viewControllersFromState.count,
					viewControllersFromNavigation != viewControllersFromState,
					let rootIndex = viewControllersFromNavigation.firstIndex(of: self.rootDestination)
		else { return }
		
		let realViewControllers = viewControllersFromNavigation.suffix(from: rootIndex)
		let poppedCount = viewControllersFromState.count - realViewControllers.count
		let popped = viewControllersFromState.suffix(poppedCount)
		
		// pop from the first id
		guard let id = self.destinations.filter({ popped.contains($0.value) }).keys.first
		else { return }
		
		self.store.send(.popFrom(id: id))
	}
	
	open func navigationController(
		_ navigationController: UINavigationController,
		interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
	) -> UIViewControllerInteractiveTransitioning? {
		nil
	}
	
	open func navigationController(
		_ navigationController: UINavigationController,
		animationControllerFor operation: UINavigationController.Operation,
		from fromVC: UIViewController,
		to toVC: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		nil
	}
	
	open func navigationController(
		_ navigationController: UINavigationController,
		didShow viewController: UIViewController,
		animated: Bool
	) {}
	
	open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		// NOTE: this is required or the pop gesture back will be disabled
		// because the delegate method for `UIViewControllerInteractiveTransitioning` is set to nil
		viewControllers.count > 1
	}
}

fileprivate func returningLastNonNilValue<A, B>(_ f: @escaping (A) -> B?, defaultValue: B) -> (A) -> B {
	var lastWrapped: B = defaultValue
	return { wrapped in
		lastWrapped = f(wrapped) ?? lastWrapped
		return lastWrapped
	}
}
