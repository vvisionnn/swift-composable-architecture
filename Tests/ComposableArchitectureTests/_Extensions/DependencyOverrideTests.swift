#if swift(>=5.9)
import XCTest
@testable import ComposableArchitecture

final class DependencyOverrideTests: BaseTCATestCase {
	func testOverride() async {
		let reducer: _DependencyKeyWritingReducer<Feature> = Feature()
			.dependency(MyValue.self, 1024)

		XCTAssertTrue((reducer as Any) is _DependencyKeyWritingReducer<Feature>)
	}
	
	@MainActor
	func testAccessOverride() async {
		let store = TestStore(initialState: Feature.State()) {
			Feature()
				.dependency(MyValue.self, 1024)
		}
		
		await store.send(.tap) { $0.value = 1024 }
	}
}

@Reducer
private struct Feature {
	@Dependency(\.anotherMyValue) var myValue
	
	struct State: Equatable { var value = 0 }
	enum Action { case tap }
	var body: some Reducer<State, Action> {
		Reduce({ state, action in
			switch action {
			case .tap:
				state.value = self.myValue
				return .none
			}
		})
	}
}

private enum MyValue: DependencyKey {
	static let liveValue = 0
	static let testValue = 0
}

extension DependencyValues {
	var anotherMyValue: Int {
		get { self[MyValue.self] }
		set { self[MyValue.self] = newValue }
	}
}
#endif
