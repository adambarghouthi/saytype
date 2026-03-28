"""SayType — macOS menu bar voice-to-text app using PyObjC."""

import queue
import threading

from AppKit import (
    NSApplication,
    NSStatusBar,
    NSVariableStatusItemLength,
    NSMenu,
    NSMenuItem,
    NSObject,
    NSTimer,
    NSRunLoop,
    NSDefaultRunLoopMode,
    NSImage,
)
import objc

from saytype.keys import (
    type_text, press_enter, press_ctrl_c, type_y_enter, type_n_enter,
    is_accessibility_trusted,
)
from saytype.engine import VoiceEngine

__version__ = "0.1.0"


class AppDelegate(NSObject):
    def initWithModelSize_(self, model_size):
        self = objc.super(AppDelegate, self).init()
        if self is None:
            return None
        self._model_size = model_size
        self._event_queue = queue.Queue()
        self._voice = None
        self._listening = False
        return self

    def applicationDidFinishLaunching_(self, notification):
        self._status_bar = NSStatusBar.systemStatusBar()
        self._status_item = self._status_bar.statusItemWithLength_(
            NSVariableStatusItemLength
        )
        self._status_item.setTitle_("ST")
        self._status_item.setHighlightMode_(True)

        self._green_dot = self._makeCircleImage(7.5, (0.18, 0.80, 0.34, 1.0))

        self._menu = NSMenu.alloc().init()

        self._status_menu_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Idle", None, ""
        )
        self._status_menu_item.setEnabled_(False)
        self._menu.addItem_(self._status_menu_item)

        version_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            f"SayType v{__version__}", None, ""
        )
        version_item.setEnabled_(False)
        self._menu.addItem_(version_item)

        self._menu.addItem_(NSMenuItem.separatorItem())

        self._toggle_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Start Listening", "toggleListening:", ""
        )
        self._toggle_item.setTarget_(self)
        self._menu.addItem_(self._toggle_item)

        self._menu.addItem_(NSMenuItem.separatorItem())

        quit_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Quit", "quitApp:", ""
        )
        quit_item.setTarget_(self)
        self._menu.addItem_(quit_item)

        self._status_item.setMenu_(self._menu)

        self._timer = NSTimer.timerWithTimeInterval_target_selector_userInfo_repeats_(
            0.1, self, "pollEvents:", None, True
        )
        NSRunLoop.currentRunLoop().addTimer_forMode_(self._timer, NSDefaultRunLoopMode)

        ax = is_accessibility_trusted()
        print(f"[saytype] Accessibility: {ax}", flush=True)
        print("[saytype] Ready. Click ST in menu bar.", flush=True)

    @staticmethod
    def _makeCircleImage(size, rgba):
        from AppKit import NSBezierPath, NSColor
        img = NSImage.alloc().initWithSize_((size, size))
        img.lockFocus()
        NSColor.colorWithCalibratedRed_green_blue_alpha_(*rgba).setFill()
        NSBezierPath.bezierPathWithOvalInRect_(((0, 0), (size, size))).fill()
        img.unlockFocus()
        img.setTemplate_(False)
        return img

    @objc.IBAction
    def toggleListening_(self, sender):
        if self._listening:
            self.doStopListening()
        else:
            self.doStartListening()

    def doStartListening(self):
        if self._voice and self._voice.is_alive():
            return
        self._voice = VoiceEngine(self._event_queue, model_size=self._model_size)
        self._voice.start()
        self._listening = True
        button = self._status_item.button()
        if button:
            button.setImage_(self._green_dot)
            button.setImagePosition_(3)
        self._status_item.setTitle_("ST ")
        self._toggle_item.setTitle_("Stop Listening")
        self._status_menu_item.setTitle_("Listening")
        print("[saytype] Started listening.", flush=True)

    def doStopListening(self):
        if self._voice:
            self._voice.stop()
            self._voice = None
        self._listening = False
        button = self._status_item.button()
        if button:
            button.setImage_(None)
        self._status_item.setTitle_("ST")
        self._toggle_item.setTitle_("Start Listening")
        self._status_menu_item.setTitle_("Idle")
        print("[saytype] Stopped listening.", flush=True)

    @objc.IBAction
    def quitApp_(self, sender):
        if self._voice:
            self._voice.stop()
        NSApplication.sharedApplication().terminate_(None)

    def pollEvents_(self, timer):
        for _ in range(20):
            try:
                event = self._event_queue.get_nowait()
            except queue.Empty:
                break
            self.processEvent_(event)

    def processEvent_(self, event):
        kind = event.get("type")

        if kind == "voice_text":
            text = event["text"]
            short = text[:40] if len(text) > 40 else text
            self._status_menu_item.setTitle_(f"Typed: {short}")
            type_text(text)
            print(f"[saytype] Injecting: {text!r}", flush=True)

        elif kind == "voice_command":
            cmd = event["command"]
            self._status_menu_item.setTitle_(f"Cmd: {cmd}")
            print(f"[saytype] Voice command: {cmd}", flush=True)

            if cmd == "submit":
                press_enter()
            elif cmd == "cancel":
                press_ctrl_c()
            elif cmd == "accept":
                type_y_enter()
            elif cmd == "reject":
                type_n_enter()

        elif kind == "hud_voice":
            state = event.get("state", "idle")
            if state == "listening":
                self._status_menu_item.setTitle_("Hearing speech...")
            elif state == "transcribing":
                self._status_menu_item.setTitle_("Transcribing...")
            elif state == "idle":
                self._status_menu_item.setTitle_("Listening")


def main(model_size="tiny.en"):
    app = NSApplication.sharedApplication()
    delegate = AppDelegate.alloc().initWithModelSize_(model_size)
    app.setDelegate_(delegate)
    app.setActivationPolicy_(1)
    print("[saytype] SayType starting...", flush=True)
    app.run()
