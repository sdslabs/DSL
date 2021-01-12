//
//  MainWindowController.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 13/01/21.
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {
    required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return true
    }
}

