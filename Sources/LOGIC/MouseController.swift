import CoreGraphics

class MouseController {
    func moveMouse(by displacement: CGPoint) {
        guard let currentPos = CGEvent(source: nil)?.location else { return }

        let newPos = CGPoint(x: currentPos.x + displacement.x * 0.1, y: currentPos.y + displacement.y * 0.1)

        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newPos, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    func clickMouse() {
        guard let currentPos = CGEvent(source: nil)?.location else { return }

        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPos, mouseButton: .left)
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentPos, mouseButton: .left)

        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
}