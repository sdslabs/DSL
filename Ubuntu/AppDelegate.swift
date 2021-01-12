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
    var isInstalled: Bool = true
    var isRunning : Bool = false
    var osThread : DispatchWorkItem? = nil
    var startStopMenuItem : NSMenuItem? = nil
    var settingsWindowController: ViewController?
    var settingsWindow: NSWindow!
    var osTask: Process? = nil
    var macAddress: String = ""
    var ipAddress: String = ""
    
    var memory: Int = 1
    var vCPU: Int = 2

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        settingsWindow = NSApplication.shared.windows.first
        settingsWindow.close()
        settingsWindowController = settingsWindow.contentViewController as! ViewController
        settingsWindowController?.setApp(appDel: self)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.image = NSImage(named: "ubuntu-white")
        
        let statusMenu = NSMenu()
        startStopMenuItem = NSMenuItem(title: "Boot Ubuntu", action: #selector(AppDelegate.bootUbuntu), keyEquivalent: "")
        statusMenu.addItem(startStopMenuItem!)
        statusMenu.addItem(NSMenuItem(title: "Debug", action: #selector(AppDelegate.debug), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem(title: "Settings", action: #selector(AppDelegate.settings), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: ""))
        statusItem?.menu = statusMenu
        
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask)[0]
        let sdslabsPath = appSupportDirectory.appendingPathComponent("SDSLabs")
        let baseImagePath = sdslabsPath.appendingPathComponent("hdd.img")
        var isDirectory = ObjCBool(true)
        if FileManager.default.fileExists(atPath: sdslabsPath.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                print("File with same path exists")
                quit()
            }
        }
        else {
            do {
                try FileManager.default.createDirectory(at: sdslabsPath, withIntermediateDirectories: false, attributes: nil)
            }
            catch {
                print("couldn't make directory")
                quit()
            }
        }
        
        if !FileManager.default.fileExists(atPath: baseImagePath.path) {
            // Todo: Toast notify that file doesn't exist
            // But for now, change the button to "Download"
            startStopMenuItem?.title = "Download Ubuntu"
            isInstalled = false
        }

    }

    @objc func debug() {
        settingsWindowController?.showProgressSheet()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        if isRunning {
            let killer = Process()
            killer.launchPath = "/usr/bin/ssh"
            killer.arguments = [
                "kanav@" + ipAddress,
                "-C", "sudo poweroff"
            ]
            killer.launch()
            settingsWindowController?.ipAddressField.stringValue = ""
            return
        }
    }
    
    @objc func settings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    func downloadUbuntuImage() {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask)[0]
        let sdslabsPath = appSupportDirectory.appendingPathComponent("SDSLabs")
        let baseImagePath = sdslabsPath.appendingPathComponent("hdd.img")
        let imageDownloadURL = "https://s3.ap-south-1.amazonaws.com/ubuntu-server-16.04.5-preinstalled/base.img"
        settings()
        settingsWindowController?.showProgressSheet()
        settingsWindowController?.progressSheet.download(from: URL(string: imageDownloadURL)!, to: baseImagePath.path)
    }
    
    @objc func bootUbuntu() {
        
        if !isInstalled {
            downloadUbuntuImage()
            return
        }
        
        if isRunning {
            let killer = Process()
            killer.launchPath = "/usr/bin/ssh"
            killer.arguments = [
                "kanav@" + ipAddress,
                "-C", "sudo poweroff"
            ]
            killer.launch()
            settingsWindowController?.ipAddressField.stringValue = ""
            return
        }
        
        vCPU = (settingsWindowController?.cpuSlider.integerValue)!
        memory = (settingsWindowController?.memorySlider.integerValue)!
        
        if let xhyveExecutableURL = Bundle.main.url(forResource: "xhyve", withExtension: "") {
            if let vmlinuzURL = Bundle.main.url(forResource: "vmlinuz-4.4.0-131-generic", withExtension: "") {
                if let initrdURL = Bundle.main.url(forResource: "initrd.img-4.4.0-131-generic", withExtension: "") {
                    // Step 1: Set setuid bit for xhyve
                    setuid_file(xhyveExecutableURL.path)
                    
                    let arguments = [
                        "-c", String(vCPU),
                        "-U", "8e7af180-c54d-4aa2-9bef-59d94a1ac572",
                        "-m", "\(memory)G",
                        "-s", "0:0,hostbridge",
                        "-s", "31,lpc",
                        "-l", "com1,stdio",
                        "-s", "2:0,virtio-net",
                        "-s", "4,virtio-blk,/Users/kanav/ubuntu/ubuntu.img",
                        "-f", "kexec,\(vmlinuzURL.path),\(initrdURL.path),\"acpi=off root=/dev/vda1 ro quiet\""
                    ]
                    
                    // Step 2: Get MAC Address for the VM
                    let macAddressPipe = Pipe()
                    let macAddressTask = Process()
                    macAddressTask.launchPath = xhyveExecutableURL.path
                    macAddressTask.standardOutput = macAddressPipe
                    macAddressTask.arguments = arguments + ["-M"]
                    macAddressTask.launch()
                    macAddressTask.waitUntilExit()
                    let macAddressHandle = macAddressPipe.fileHandleForReading
                    macAddressHandle.readData(ofLength: 5) // Read out "MAC: "
                    // Next 17 bytes contain the mac address
                    macAddress = String(data: macAddressHandle.readData(ofLength: 17), encoding: String.Encoding.utf8)!
                    print("Got MAC Address: \(macAddress)")

                    // Step 3: Run OS
                    let outputData = Pipe()
                    osTask = Process()
                    osTask!.launchPath = xhyveExecutableURL.path
                    osTask!.arguments = arguments
                    osTask!.standardOutput = outputData
                    osTask!.launch()
                    DispatchQueue.global().async {
                        self.osTask!.waitUntilExit()
                        DispatchQueue.main.async {
                            self.isRunning = false
//                            self.startStopMenuItem?.isHidden = false
                            self.startStopMenuItem?.title = "Boot Ubuntu"
                            self.settingsWindowController?.bootButton.title = "Boot"
                            self.settingsWindowController?.setControls(val: true)
                            self.settingsWindowController?.ipAddressField.stringValue = ""
                        }
                    }
                    isRunning = true
                    startStopMenuItem?.title = "Kill Ubuntu"
                    settingsWindowController?.bootButton.title = "Kill"
                    settingsWindowController?.setControls(val: false)
                    
                    // Step 4: Get IP address from /var/db/dhcpd_leases
                    do {
                        let data = try String(contentsOfFile: "/var/db/dhcpd_leases", encoding: .utf8)
                        let lines = data.components(separatedBy: .newlines)
                        var ip_address = ""
                        var hw_address = ""
                        for line in lines {
                            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedLine == "{" {
                                ip_address = ""
                                hw_address = ""
                            }
                            else if trimmedLine == "}" {
                                if hw_address == macAddress {
                                    ipAddress = ip_address
                                    settingsWindowController?.ipAddressField.stringValue = ipAddress
                                    print("found IP address \(ipAddress)")
                                    break
                                }
                             }
                            else {
                                if trimmedLine.starts(with: "hw_address=") {
                                    hw_address = String(trimmedLine.split(separator: "=")[1].split(separator: ",")[1])
                                }
                                else if trimmedLine.starts(with: "ip_address=") {
                                    ip_address = String(trimmedLine.split(separator: "=")[1])
                                }
                            }
                        }
                    }
                    catch {
                        print("couldn't find leases file")
                    }
                    
                }
            }
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }


}

