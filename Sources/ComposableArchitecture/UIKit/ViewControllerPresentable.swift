import UIKit
import Combine

public protocol ViewControllerPresentable: UIViewController {
	var onDismiss: (@MainActor () -> Void)? { get set }
	var currentPresentedViewController: (any ViewControllerPresentable)? { get set }
}

extension ViewControllerPresentable {
	@MainActor
	public func checkDismissedIfNeeded() {
		guard self.isBeingDismissed, !(self.parent?.isBeingDismissed ?? false) else { return }
		defer { onDismiss = nil }
		onDismiss?()
	}
}

extension ViewControllerPresentable {
	@MainActor
	public func presentation<State: Equatable, Action>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		_ toDestinationControllerInfo: @escaping (State, Store<State, Action>) -> any ViewControllerPresentable,
		shouldAnimatePresentation: ((State) -> Bool)? = nil,
		shouldAnimateDismiss: ((State) -> Bool)? = nil
	) -> AnyCancellable {
		self.presentation(
			store,
			id: { $0.id },
			toDestinationControllerInfo,
			shouldAnimatePresentation: shouldAnimatePresentation,
			shouldAnimateDismiss: shouldAnimateDismiss
		)
	}
	
	@MainActor
	public func presentation<State: Equatable, Action>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		_ toDestinationController: @escaping (State, Store<State, Action>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		self.presentation(store, id: { $0.id }, toDestinationController)
	}
	
	@MainActor
	func presentation<State: Equatable, Action, ID: Hashable>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		id toID: @escaping (PresentationState<State>) -> ID?,
		_ toDestinationController: @escaping (State, Store<State, Action>) -> any ViewControllerPresentable,
		shouldAnimatePresentation: ((State) -> Bool)? = nil,
		shouldAnimateDismiss: ((State) -> Bool)? = nil
	) -> AnyCancellable {
		let queue = FIFOQueue()
		return store.publisher
			.removeDuplicates(by: { toID($0) == toID($1) })
			.withPrevious()
			.receive(on: DispatchQueue.main)
			.sink { [weak self] (prevState, presentationState) in
				guard let self else { return }
				queue.enqueue { @MainActor in
					var shouldDismiss: Bool = false
					var wrappedState: State? = nil
					
					switch (prevState?.wrappedValue, presentationState.wrappedValue) {
					case (.none, .none):
						return
						
					case let (.some(prevState), .none):
						guard self.currentPresentedViewController != nil else { return }
						let isAnimateDismiss = shouldAnimateDismiss?(prevState) ?? true
						await self.dismissAsync(animated: isAnimateDismiss)
						return
						
					case let (.none, .some(_state)):
						shouldDismiss = false
						wrappedState = _state
						
					case let (.some, .some(_state)):
						shouldDismiss = true
						wrappedState = _state
					}
					
					guard let wrappedState else { return }
					let originalId = toID(presentationState)
					let fallback = PresentationViewController(nibName: nil, bundle: nil)
					let freshViewController = store.scope(
						state: \.wrappedValue,
						action: \.presented
					).map({ toDestinationController(wrappedState, $0) }) ?? fallback
					let isAnimatePresentation = shouldAnimatePresentation?(wrappedState) ?? true
					let isAnimateDismiss = shouldAnimateDismiss?(wrappedState) ?? true
					freshViewController.onDismiss = { @MainActor [weak store, weak freshViewController] in
						_ = freshViewController
						guard let _store = store, toID(_store.currentState) == originalId else { return }
						guard _store.currentState.wrappedValue != nil else { return }
						_store.send(.dismiss)
					}
					if shouldDismiss {
						await self.dismissAsync(animated: isAnimateDismiss)
					}
					
					// after await dismissing, the state may change, double check
					guard store.currentState.wrappedValue != nil,
								toID(store.currentState) == originalId
					else { return }
					await self.presentAsync(
						freshViewController,
						animated: isAnimatePresentation
					)
				}
			}
	}
}

extension ViewControllerPresentable {
	@MainActor
	fileprivate func presentAsync(_ viewControllerToPresent: any ViewControllerPresentable, animated: Bool) async {
		defer { self.currentPresentedViewController = viewControllerToPresent }
		await withCheckedContinuation { continuation in
			self.present(viewControllerToPresent, animated: animated) {
				continuation.resume()
			}
		}
	}
	
	@MainActor
	fileprivate func dismissAsync(animated: Bool) async {
		defer { self.currentPresentedViewController = nil }
		if (self.presentedViewController == nil) != (self.currentPresentedViewController == nil) {
			await withCheckedContinuation { continuation in
				self.currentPresentedViewController?.dismiss(animated: animated) {
					continuation.resume()
				}
			}
		} else {
			await withCheckedContinuation { continuation in
				self.dismiss(animated: animated) {
					continuation.resume()
				}
			}
		}
	}
}

extension Store where State: Equatable {
	@MainActor
	public func map<TargetState, Target>(
		_ transform: @MainActor (Store<TargetState, Action>) -> Target
	) -> Target? where State == Optional<TargetState> {
		guard var state = self.currentState else { return nil }
		return transform(
			self.scope(
				id: self.id(state: \.!, action: \.self),
				state: ToState {
					state = $0 ?? state
					return state
				},
				action: { $0 },
				isInvalid: nil
			)
		)
	}
}

extension Publisher {
	fileprivate func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
		scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
			.compactMap { $0 }
			.eraseToAnyPublisher()
	}
	
	fileprivate func withPrevious(
		_ initialPreviousValue: Output) -> AnyPublisher<(previous: Output,
		current: Output
	), Failure> {
		scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
	}
}
