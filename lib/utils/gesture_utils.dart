import 'package:flutter/gestures.dart';

/// A ScaleGestureRecognizer that only recognizes the gesture when at least
/// two pointers are involved. This allows single-pointer gestures (like scrolling
/// or selection) to pass through to the child widget.
class TwoFingerScaleGestureRecognizer extends ScaleGestureRecognizer {
  int _pointerCount = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointerCount++;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerCount--;
    }
    super.handleEvent(event);
  }

  @override
  void acceptGesture(int pointer) {
    if (_pointerCount >= 2) {
      super.acceptGesture(pointer);
    } else {
      // Reject single-finger gestures so the child (TerminalView) can handle them
      rejectGesture(pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
  }
}
