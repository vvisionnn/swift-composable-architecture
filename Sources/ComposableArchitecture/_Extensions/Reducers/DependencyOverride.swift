import Dependencies

extension Reducer {
	/// Places a value in the reducer's dependencies.
	///
	/// - Parameter key: The key for the value to set in the dependencies.
	/// - Parameter value: The value to set for this value's type in the dependencies.
	/// - Returns: A reducer that has the given value set in its dependencies.
	func dependency<Key: TestDependencyKey>(
		_ key: Key.Type,
		_ value: Key.Value
	) -> _DependencyKeyWritingReducer<Self> {
		_DependencyKeyWritingReducer(base: self) { $0[key] = value }
	}
}
