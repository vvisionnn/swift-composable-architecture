import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { "\($0) is a good number." }
    }
    
    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(\.factResponse) {
      $0.isLoading = false
      $0.fact = "0 is a good number."
    }
  }
}
