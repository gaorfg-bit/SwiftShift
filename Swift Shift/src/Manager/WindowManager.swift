import Foundation
import ApplicationServices
import Cocoa

class WindowManager {
    // MARK: - Core Methods
    
    static func getPosition(for window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        if result == .success, let axValue = value as! AXValue? {
            var position = CGPoint.zero
            AXValueGetValue(axValue, .cgPoint, &position)
            return position
        }
        return nil
    }

    static func getSize(for window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        if result == .success, let axValue = value as! AXValue? {
            var size = CGSize.zero
            AXValueGetValue(axValue, .cgSize, &size)
            return size
        }
        return nil
    }

    static func setPosition(for window: AXUIElement, to position: CGPoint) {
        var position = position
        if let value = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    static func setSize(for window: AXUIElement, to size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    static func getWindowBounds(windowLocation: CGPoint, windowSize: CGSize) -> CGRect {
        return CGRect(origin: windowLocation, size: windowSize)
    }

    static func getNSApplication(from element: AXUIElement) -> NSRunningApplication? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return NSRunningApplication(processIdentifier: pid)
    }

    // MARK: - App logic methods
    
    static func getCurrentWindow() -> AXUIElement? {
        return getWindowUnderCursor()
    }

    static func focus(window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        let app = getNSApplication(from: window)
        app?.activate(options: .activateIgnoringOtherApps)
    }

    static func move(window: AXUIElement, to origin: CGPoint) {
        setPosition(for: window, to: origin)
    }

    static func resize(window: AXUIElement, to size: CGSize, from origin: CGPoint? = nil, shouldMoveOrigin: Bool = false) {
        setSize(for: window, to: size)
        if shouldMoveOrigin, let origin = origin {
            setPosition(for: window, to: origin)
        }
    }

    // MARK: - Helper Methods (Including Pablo's Fix)

    private static func getWindow(from element: AXUIElement) -> AXUIElement? {
        var r: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &r)
        
        if let role = r as? String, role == kAXWindowRole {
            return element
        }
        
        var p: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &p)
        
        // --- PR #109 Fix ---
        if let parent = p, CFGetTypeID(parent) == AXUIElementGetTypeID() {
            return getWindow(from: parent as! AXUIElement)
        }
        // -------------------
        
        return nil
    }

    static func getWindowUnderCursor() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        var cursorPosition = CGPoint.zero
        if let ev = CGEvent(source: nil) {
            cursorPosition = ev.location
        }
        let error = AXUIElementCopyElementAtPosition(systemWideElement, Float(cursorPosition.x), Float(cursorPosition.y), &element)
        guard error == .success, let foundElement = element else { return nil }
        return getWindow(from: foundElement)
    }
}
