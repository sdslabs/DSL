//
//  AppDelegate.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 08/01/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    
    var statusItem : NSStatusItem? = nil
    var isRunning : Bool = false
    var osThread : DispatchWorkItem? = nil
    var startStopMenuItem : NSMenuItem? = nil

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.image = NSImage(named: "ubuntu-white")
        
        let statusMenu = NSMenu()
        startStopMenuItem = NSMenuItem(title: "Start Ubuntu", action: #selector(AppDelegate.toggleUbuntu), keyEquivalent: "")
        statusMenu.addItem(startStopMenuItem!)
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem(title: "Settings", action: #selector(AppDelegate.settings), keyEquivalent: ""))
        statusItem?.menu = statusMenu
//        statusItem?.action = #selector(AppDelegate.openStatusMenu)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func settings() {
        
    }
    
    @objc func toggleUbuntu() {
        if isRunning {
            isRunning = false
            startStopMenuItem?.title = "Start Ubuntu"
            osThread?.cancel()
            print(osThread?.isCancelled)
        }
        else {
            if let xhyveExecutableURL = Bundle.main.url(forResource: "xhyve", withExtension: "") {
                if let vmlinuzURL = Bundle.main.url(forResource: "vmlinuz-4.4.0-131-generic", withExtension: "") {
                    if let initrdURL = Bundle.main.url(forResource: "initrd.img-4.4.0-131-generic", withExtension: "") {
                        osThread = DispatchWorkItem {
                            auth(xhyveExecutableURL.path, [
                                "-c", "2",
                                "-U", "8e7af180-c54d-4aa2-9bef-59d94a1ac572",
                                "-m", "1G",
                                "-s", "0:0,hostbridge",
                                "-s", "31,lpc",
                                "-l", "com1,stdio",
                                "-s", "2:0,virtio-net",
                                "-s", "4,virtio-blk,/Users/kanav/ubuntu/ubuntu.img",
                                "-f", "kexec,\(vmlinuzURL.path),\(initrdURL.path),\"acpi=off root=/dev/vda1 ro quiet\""
                            ])
                            DispatchQueue.main.async {
                                print("done")
                            }
                        }
                        isRunning = true
                        startStopMenuItem?.title = "Stop Ubuntu"
                        DispatchQueue.global().async(execute: osThread!)
                    }
                }
            }
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }


}

