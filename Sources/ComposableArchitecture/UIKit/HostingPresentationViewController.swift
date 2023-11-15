//
//  HostingPresentationViewController.swift
//  
//
//  Created by Andy Wen on 2023/7/31.
//

#if canImport(UIKit) && !os(watchOS)
import SwiftUI

open class HostingPresentationViewController<Content: View>: UIHostingController<Content>, ViewControllerPresentable {
	public var onDismiss: (() -> Void)?
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
#endif
