//
//  DemoViewController.swift
//  Example
//
//  Created by Andy Wen on 2023/7/30.
//

import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

@Reducer
struct PresentationCounter {
	@Reducer(state: .equatable)
	enum Presentation {
		case sheetCounter(PresentationCounter)
		case fullScreenCounter(PresentationCounter)
	}

	@ObservableState
	struct State: Equatable {
		@Presents var presentation: Presentation.State?
		var count: Int = 0
	}
	
	enum Action {
		enum ViewAction {
			case dismissButtonDidTap
			case incrementButtonDidTap
			case decrementButtonDidTap
			case presentAnotherDidTap
			case selfPresentButtonDidTap
			case pushButtonDidTap
			case popButtonDidTap
			case pushMultipleButtonDidTap
			case popMultipleButtonDidTap
			case popToRootButtonDidTap
		}
		
		enum InternalAction {}
		enum DelegateAction {
			case shouldPop
			case shouldPopMultiple
			case shouldPush
			case shouldPushMultiple
			case shouldPresentAnother
			case shouldDismiss
			case shouldPopToRoot
		}
		
		case view(ViewAction)
		case `internal`(InternalAction)
		case delegate(DelegateAction)
		case presentation(PresentationAction<Presentation.Action>)
	}
	
	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .view(.dismissButtonDidTap):
				return .send(.delegate(.shouldDismiss))

			case .view(.incrementButtonDidTap):
				state.count += 1
				return .none

			case .view(.decrementButtonDidTap):
				state.count -= 1
				return .none

			case .view(.presentAnotherDidTap):
				return .send(.delegate(.shouldPresentAnother))

			case .view(.selfPresentButtonDidTap):
				state.presentation = .sheetCounter(.init(count: state.count + 1))
				return .none

			case .view(.pushButtonDidTap):
				return .send(.delegate(.shouldPush))

			case .view(.popButtonDidTap):
				return .send(.delegate(.shouldPop))

			case .view(.pushMultipleButtonDidTap):
				return .send(.delegate(.shouldPushMultiple))

			case .view(.popMultipleButtonDidTap):
				return .send(.delegate(.shouldPopMultiple))

			case .view(.popToRootButtonDidTap):
				return .send(.delegate(.shouldPopToRoot))
				
			case .view:
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldDismiss)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldDismiss)))):
				state.presentation = nil
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldPresentAnother)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldPresentAnother)))):
				guard let currPresent = state.presentation else {
					state.presentation = .sheetCounter(.init(count: 0))
					return .none
				}
				
				switch currPresent {
				case let .sheetCounter(counterState):
					state.presentation = .fullScreenCounter(counterState)
				case let .fullScreenCounter(counterState):
					state.presentation = .sheetCounter(counterState)
				}
				return .none
				
			case .presentation:
				return .none
				
			case .internal:
				return .none
				
			case .delegate:
				return .none
			}
		}
		.ifLet(\.$presentation, action: \.presentation)
	}
}

final class PresentationCounterViewController: HostingPresentationViewController<CounterView> {
	private let store: StoreOf<PresentationCounter>
	private var subscriptions: Set<AnyCancellable> = .init()
	
	init(store: StoreOf<PresentationCounter>) {
		self.store = store
		super.init(rootView: CounterView(store: store))
		self.title = "\(ViewStore(store, observe: { $0 }).count)"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			systemItem: .close,
			primaryAction: .init(handler: { [weak self] _ in
				self?.dismiss(animated: self?.viewIfLoaded?.window != nil)
			})
		)
		
		store.publisher
			.map({ "\($0.count)" })
			.sink { [weak self] in self?.title = $0 }
			.store(in: &subscriptions)
		
		self.presentation(store.scope(
			state: \.$presentation,
			action: \.presentation
		)) { store in
			switch store.case {
			case let .sheetCounter(childStore):
				PresentationCounterViewController(store: childStore)
					.wrapInNavigationController()
					.modalPresentationStyle(.pageSheet)
			case let .fullScreenCounter(childStore):
				PresentationCounterViewController(store: childStore)
					.wrapInNavigationController()
					.modalPresentationStyle(.overFullScreen)
			}
		}
		.store(in: &subscriptions)
	}
}

extension UIViewController {
	@inlinable
	@discardableResult
	func modalPresentationStyle(_ style: UIModalPresentationStyle) -> Self {
		modalPresentationStyle = style
		return self
	}
}

extension PresentationCounterViewController {
	@inlinable
	func wrapInNavigationController() -> NavigationPresentationViewController {
		return .init(rootViewController: self)
	}
}

struct CounterView: View {
	@Environment(\.dismiss) var dismiss
	let store: StoreOf<PresentationCounter>
	@ObservedObject var viewStore: ViewStoreOf<PresentationCounter>
	
	init(store: StoreOf<PresentationCounter>) {
		self.store = store
		self.viewStore = ViewStore(store, observe: { $0 })
	}
	
	var body: some View {
		VStack {
			HStack {
				Button("+")  { viewStore.send(.view(.incrementButtonDidTap)) }
				Text("\(viewStore.count)")
				Button("-") { viewStore.send(.view(.decrementButtonDidTap)) }
			}
			
			Button("Push") { viewStore.send(.view(.pushButtonDidTap)) }
			Button("Pop") { viewStore.send(.view(.popButtonDidTap)) }
			Button("Push Multiple") { viewStore.send(.view(.pushMultipleButtonDidTap)) }
			Button("Pop Multiple") { viewStore.send(.view(.popMultipleButtonDidTap)) }
			Button("Pop to Root") { viewStore.send(.view(.popToRootButtonDidTap)) }
			Button("Present Another") { viewStore.send(.view(.presentAnotherDidTap)) }
			Button("Present By Self") { viewStore.send(.view(.selfPresentButtonDidTap)) }
			Button("action dismiss") { viewStore.send(.view(.dismissButtonDidTap)) }
			Button("native dismiss") { self.dismiss() }
		}
		.buttonStyle(.borderedProminent)
	}
}

@Reducer
struct PresentationStack {
	@Reducer(state: .equatable)
	enum StackDestination {
		case counter(PresentationCounter)
	}
	
	@Reducer(state: .equatable)
	enum Presentation {
		case sheetCounter(PresentationCounter)
		case fullScreenCounter(PresentationCounter)
	}
	
	@ObservableState
	struct State {
		@Presents var presentation: Presentation.State?
		var path: StackState<StackDestination.State> = .init()
		var rootPath: PresentationCounter.State = .init()
	}
	
	enum Action {
		case presentation(PresentationAction<Presentation.Action>)
		case path(StackAction<StackDestination.State, StackDestination.Action>)
		case rootPath(PresentationCounter.Action)
	}
	
	var body: some ReducerOf<Self> {
		Scope(state: \.rootPath, action: \.rootPath) { PresentationCounter() }
		
		Reduce({ state, action in
			switch action {
			case .rootPath(.delegate(.shouldPush)),
					.path(.element(id: _, action: .counter(.delegate(.shouldPush)))):
				state.path.append(.counter(.init()))
				return .none
				
			case .rootPath(.delegate(.shouldPop)),
					.path(.element(id: _, action: .counter(.delegate(.shouldPop)))):
				guard !state.path.isEmpty else { return .none }
				state.path.removeLast()
				return .none
				
			case .rootPath(.delegate(.shouldPushMultiple)),
					.path(.element(id: _, action: .counter(.delegate(.shouldPushMultiple)))):
				let newPaths = Array(repeating: StackDestination.State.counter(.init()), count: Int.random(in: 1...10))
				state.path.append(contentsOf: newPaths)
				return .none
				
			case .rootPath(.delegate(.shouldPopMultiple)),
					.path(.element(id: _, action: .counter(.delegate(.shouldPopMultiple)))):
				state.path.removeLast(min(state.path.count, Int.random(in: 1...10)))
				return .none
				
			case .rootPath(.delegate(.shouldPopToRoot)),
					.path(.element(id: _, action: .counter(.delegate(.shouldPopToRoot)))):
				state.path.removeAll()
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldDismiss)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldDismiss)))):
				state.presentation = nil
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldPresentAnother)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldPresentAnother)))):
				guard let currPresent = state.presentation else {
					state.presentation = .sheetCounter(.init(count: 0))
					return .none
				}
				
				switch currPresent {
				case let .sheetCounter(counterState):
					state.presentation = .fullScreenCounter(counterState)
				case let .fullScreenCounter(counterState):
					state.presentation = .sheetCounter(counterState)
				}
				return .none
				
			case .path:
				return .none
				
			case .presentation:
				return .none
				
			case .rootPath:
				return .none
			}
		})
		.ifLet(\.$presentation, action: \.presentation)
		.forEach(\.path, action: \.path)
	}
}

final class PresentationStackViewController: NavigationStackViewController<
	PresentationStack.StackDestination.State,
	PresentationStack.StackDestination.Action
> {
	let store: StoreOf<PresentationStack>
	var subscriptions: Set<AnyCancellable> = .init()
	
	init(store: StoreOf<PresentationStack>) {
		self.store = store
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.navigation(
			store.scope(state: \.path, action: \.path),
			rootViewController: PresentationCounterViewController(
				store: store.scope(
					state: \.rootPath,
					action: \.rootPath
				)
			)
		) { @MainActor store in
			switch store.case {
			case let .counter(_store):
				return PresentationCounterViewController(store: _store)
			}
		}
		.store(in: &subscriptions)
		
		self.presentation(store.scope(
			state: \.$presentation,
			action: \.presentation
		)) { state, childStore in
			switch state {
			case .sheetCounter:
				guard let viewController = childStore.scope(
					state: \.sheetCounter,
					action: \.sheetCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .pageSheet
				return _viewController
			case .fullScreenCounter:
				guard let viewController = childStore.scope(
					state: \.fullScreenCounter,
					action: \.fullScreenCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .overFullScreen
				return _viewController
			}
		}
		.store(in: &subscriptions)
	}
}
