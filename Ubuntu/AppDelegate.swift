//
//  AppDelegate.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 08/01/21.
//

import Cocoa
import SwiftyJSON

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem : NSStatusItem? = nil
    var isInstalled: Bool = true
    var isRunning : Bool = false
    var osThread : DispatchWorkItem? = nil
    var startStopMenuItem : NSMenuItem? = nil
    var preferencesViewController: ViewController?
    var mainWindow: NSWindow!
    var osTask: Process? = nil
    var macAddress: String = ""
    var ipAddress: String = ""
    
    var memory: Int = 1
    var vCPU: Int = 2
    var diskImagePath: URL!
    var configPath: URL!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        initializeStatusItem()
        initializeConfiguration()
        initializePreferencesWindow()
    }
    
    func initializeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.image = NSImage(named: "ubuntu-white")

        let statusMenu = NSMenu()
        startStopMenuItem = NSMenuItem(title: "Boot Ubuntu", action: #selector(AppDelegate.bootUbuntu), keyEquivalent: "")
        statusMenu.addItem(startStopMenuItem!)
        statusMenu.addItem(NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPreferencesWindow), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitApplication), keyEquivalent: ""))
        statusItem?.menu = statusMenu
    }
    
    func initializePreferencesWindow() {
        mainWindow = NSApplication.shared.windows.first
        mainWindow.close()
        preferencesViewController = mainWindow.contentViewController as! ViewController
        preferencesViewController?.setApp(appDel: self)
    }
    
    func initializeConfiguration() {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sdslabsPath = appSupportDirectory.appendingPathComponent("SDSLabs")
        configPath = sdslabsPath.appendingPathComponent("config.json")
        diskImagePath = sdslabsPath.appendingPathComponent("hdd.img")
        
        do
        {
            // Check if `~/Library/Application Support/SDSLabs` exist
            var isDirectory = ObjCBool(true)
            if FileManager.default.fileExists(atPath: sdslabsPath.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    print("File with same path exists")
                    quitApplication()
                }
            }
            else {
                try FileManager.default.createDirectory(at: sdslabsPath, withIntermediateDirectories: false, attributes: nil)
            }
            
            // Check if config.json exists
            if FileManager.default.fileExists(atPath: configPath.path) {
                let configData = try String(contentsOf: configPath, encoding: .utf8)
                let config = JSON(parseJSON: configData)
                if let jsonCPU = config["cpu"].int {
                    vCPU = jsonCPU
                }
                if let jsonMem = config["memory"].int {
                    memory = jsonMem
                }
            }
            else {
                let config = JSON(dictionaryLiteral: ("cpu", vCPU), ("memory", memory))
                print(config.description)
                print(configPath.path)
                try config.description.write(to: configPath, atomically: false, encoding: .utf8)
            }
            
            // Check if hdd.img exists
            if !FileManager.default.fileExists(atPath: diskImagePath.path) {
                startStopMenuItem?.title = "Download Ubuntu"
                isInstalled = false
            }
        }
        catch { quitApplication() }
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
            preferencesViewController?.ipAddressField.stringValue = ""
            return
        }
    }
    
    @objc func showPreferencesWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }
    
    func downloadUbuntuImage() {
        let imageDownloadURL = "https://s3.ap-south-1.amazonaws.com/ubuntu-server-16.04.5-preinstalled/base.img"
        showPreferencesWindow()
        preferencesViewController?.showProgressSheet()
        preferencesViewController?.progressSheet
            .download(from: URL(string: imageDownloadURL)!, to: diskImagePath.path)
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
            preferencesViewController?.ipAddressField.stringValue = ""
            return
        }
        
        vCPU = (preferencesViewController?.cpuSlider.integerValue)!
        memory = (preferencesViewController?.memorySlider.integerValue)!
        
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
                            self.preferencesViewController?.bootButton.title = "Boot"
                            self.preferencesViewController?.setControls(val: true)
                            self.preferencesViewController?.ipAddressField.stringValue = ""
                        }
                    }
                    isRunning = true
                    startStopMenuItem?.title = "Kill Ubuntu"
                    preferencesViewController?.bootButton.title = "Kill"
                    preferencesViewController?.setControls(val: false)
                    
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
                                    preferencesViewController?.ipAddressField.stringValue = ipAddress
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
    
    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }

    /*
     Update Configuration
     */
    func updateCPU(_ c: Int) {
        vCPU = c
        let config = JSON(dictionaryLiteral: ("cpu", vCPU), ("memory", memory))
        do { try config.description.write(to: configPath, atomically: false, encoding: .utf8) }
        catch {}
    }
    
    func updateMemory(_ m: Int) {
        memory = m
        let config = JSON(dictionaryLiteral: ("cpu", vCPU), ("memory", memory))
        do { try config.description.write(to: configPath, atomically: false, encoding: .utf8) }
        catch {}
    }
}

