//
//  AppDelegate.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 08/01/21.
//

import Cocoa
import SwiftyJSON

enum State {
    case notInstalled, installing, off, on
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem : NSStatusItem? = nil

    var state: State = .off

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
    var disks: [DiskImage] = []
    
    var hypervisor: String = "hyperkit"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        initializeStatusItem()
        initializeConfiguration()
        initializePreferencesWindow() // Preferences window should always be initialized after config
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
                if let jsonDisks = config["disks"].array {
                    for j in jsonDisks {
                        disks.append(DiskImage(name: j["name"].string!, format: j["format"].string! == "qcow2" ? .qcow2 : .raw, storage: j["storage"].int32!, storageUnit: j["unit"].string! == "gb" ? .gb : .mb, mounted: j["mount"].bool!))
                    }
                }
            }
            else {
                let config = JSON(dictionaryLiteral: ("cpu", vCPU), ("memory", memory), ("disks", JSON([])))
                print(config.description)
                print(configPath.path)
                try config.description.write(to: configPath, atomically: false, encoding: .utf8)
            }
            
            // Check if hdd.img exists
            if !FileManager.default.fileExists(atPath: diskImagePath.path) {
                setStateNotInstalled()
            }
            else {
                setStateTurnedOff()
            }
        }
        catch { quitApplication() }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        if state == .on {
            stopUbuntu()
        }
    }
    
    @objc func showPreferencesWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func downloadUbuntuImage() {
        let imageDownloadURL = "https://s3.ap-south-1.amazonaws.com/ubuntu-server-16.04.5-preinstalled/base.img"
        showPreferencesWindow()
        preferencesViewController?.showProgressSheet()
        preferencesViewController?.progressSheet
            .download(from: URL(string: imageDownloadURL)!, to: diskImagePath.path)
        setStateInstalling()
    }
    
    func diskArgs() -> [String] {
        var i = 5
        let basePath: URL
        do {
            basePath = try DiskTools.getDisksDirectory()
        }
        catch {
            return []
        }
        var args: [String] = []
        for disk in disks {
            if disk.mounted {
                args.append("-s")
                var arg = "\(i),virtio-blk,"
                i += 1
                if disk.format == .qcow2 {
                    let diskPath = basePath.appendingPathComponent("\(disk.name).qcow2")
                    arg += "file://\(diskPath.path),format=qcow"
                }
                else if disk.format == .raw {
                    let diskPath = basePath.appendingPathComponent("\(disk.name).img")
                    arg += diskPath.path
                }
                args.append(arg)
            }
        }
        return args
    }
    
    @objc func bootUbuntu() {
        
        if let hypervisorExecutableURL = Bundle.main.url(forResource: hypervisor, withExtension: "") {
            if let vmlinuzURL = Bundle.main.url(forResource: "vmlinuz-4.4.0-131-generic", withExtension: "") {
                if let initrdURL = Bundle.main.url(forResource: "initrd.img-4.4.0-131-generic", withExtension: "") {
                    // Step 1: Set setuid bit for xhyve
                    setuid_file(hypervisorExecutableURL.path)
                    
                    let arguments = [
                        "-c", String(vCPU),
                        "-U", "8e7af180-c54d-4aa2-9bef-59d94a1ac572",
                        "-m", "\(memory)G",
                        "-s", "0:0,hostbridge",
                        "-s", "31,lpc",
                        "-s", "2:0,virtio-net",
                        "-s", "4,virtio-blk,\(diskImagePath.path)",
                        "-f", "kexec,\(vmlinuzURL.path),\(initrdURL.path),\"acpi=off root=/dev/vda1 ro quiet\""
                    ] + diskArgs()
                    
                    // Step 2: Get MAC Address for the VM
                    let macAddressPipe = Pipe()
                    let macAddressTask = Process()
                    macAddressTask.launchPath = hypervisorExecutableURL.path
                    macAddressTask.standardOutput = macAddressPipe
                    macAddressTask.arguments = arguments + ["-M"]
                    macAddressTask.launch()
                    macAddressTask.waitUntilExit()
                    let macAddressHandle = macAddressPipe.fileHandleForReading
                    macAddressHandle.readData(ofLength: 5) // Read out "MAC: "
                    // Next 17 bytes contain the mac address
                    macAddress = String(data: macAddressHandle.readData(ofLength: 17), encoding: String.Encoding.utf8)!
                    print("Got MAC Address: \(macAddress)")
                    preferencesViewController?.macAddressField.stringValue = macAddress

                    // Step 3: Run OS
                    let outputData = Pipe()
                    osTask = Process()
                    osTask!.launchPath = hypervisorExecutableURL.path
                    osTask!.arguments = arguments
                    osTask!.standardOutput = outputData
                    osTask!.launch()
                    DispatchQueue.global().async {
                        self.osTask!.waitUntilExit()
                        DispatchQueue.main.async {
                            self.setStateTurnedOff()
                        }
                    }
                    setStateTurnedOn()
                    
                    // Step 4: Get IP address from /var/db/dhcpd_leases
                    fetchIP()
                }
            }
        }
    }
    
    func fetchIP() {
        do {
            let data = try String(contentsOfFile: "/var/db/dhcpd_leases", encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            var currIPAddress = ""
            var currHWAddress = ""
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine == "{" {
                    currIPAddress = ""
                    currHWAddress = ""
                }
                else if trimmedLine == "}" {
                    if currHWAddress == macAddress {
                        ipAddress = currIPAddress
                        preferencesViewController?.ipAddressField.stringValue = ipAddress
                        print("found IP address \(ipAddress)")
                        break
                    }
                 }
                else {
                    if trimmedLine.starts(with: "hw_address=") {
                        currHWAddress = String(trimmedLine.split(separator: "=")[1].split(separator: ",")[1])
                    }
                    else if trimmedLine.starts(with: "ip_address=") {
                        currIPAddress = String(trimmedLine.split(separator: "=")[1])
                    }
                }
            }
        }
        catch {
            print("couldn't find leases file")
        }
    }
    
    @objc func stopUbuntu() {
//        let killer = Process()
//        killer.launchPath = "/usr/bin/ssh"
//        killer.arguments = [
//            "default@" + ipAddress,
//            "-C", "sudo poweroff"
//        ]
//        killer.launch()
        // TODO: This is not a graceful way to shut down,
        // TODO: Simulate ACPI shutdown
        osTask?.terminate()
        setStateTurnedOff()
    }
    
    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }

    /*
     Update Configuration
     */
    func updateCPU(_ c: Int) {
        vCPU = c
        updateJSON()
    }
    
    func updateMemory(_ m: Int) {
        memory = m
        updateJSON()
    }
    
    func updateDisks(_ d: [DiskImage]) {
        disks = d
        updateJSON()
    }
    
    func updateJSON() {
        var jsonDiskArray: [JSON] = []
        for d in disks {
            jsonDiskArray.append(JSON(dictionaryLiteral: ("name", d.name), ("format", d.format == .qcow2 ? "qcow2" : "raw"), ("storage", d.storage), ("unit", d.storageUnit == .gb ? "gb" : "mb"), ("mount", d.mounted)))
        }
        let disksJSON = JSON(jsonDiskArray)
        let config = JSON(dictionaryLiteral: ("cpu", vCPU), ("memory", memory), ("disks", disksJSON))
        do { try config.description.write(to: configPath, atomically: false, encoding: .utf8) }
        catch {}
    }
    
    /*
     Set states of UI
     */
    func setStateNotInstalled() {
        DispatchQueue.main.async {
            self.state = .notInstalled
            self.startStopMenuItem?.title = "Download Ubuntu.."
            self.startStopMenuItem?.isEnabled = true
            self.startStopMenuItem?.action = #selector(AppDelegate.downloadUbuntuImage)
            self.preferencesViewController?.bootButton.title = "Download"
            self.preferencesViewController?.bootButton.isEnabled = true
            self.preferencesViewController?.terminalButton.isEnabled = false
            self.preferencesViewController?.manageDisksButton.isEnabled = false
            self.preferencesViewController?.cpuSlider.isEnabled = false
            self.preferencesViewController?.memorySlider.isEnabled = false
        }
    }
    
    func setStateInstalling() {
        DispatchQueue.main.async {
            self.state = .installing
            self.startStopMenuItem?.title = "Downloading..."
            self.startStopMenuItem?.isEnabled = false
            self.startStopMenuItem?.action = nil
            self.preferencesViewController?.bootButton.title = "Download"
            self.preferencesViewController?.bootButton.isEnabled = false
            self.preferencesViewController?.terminalButton.isEnabled = false
            self.preferencesViewController?.manageDisksButton.isEnabled = false
            self.preferencesViewController?.cpuSlider.isEnabled = false
            self.preferencesViewController?.memorySlider.isEnabled = false
        }
    }
    
    func setStateTurnedOff() {
        DispatchQueue.main.async {
            self.state = .off
            self.startStopMenuItem?.title = "Boot-up"
            self.startStopMenuItem?.isEnabled = true
            self.startStopMenuItem?.action = #selector(AppDelegate.bootUbuntu)
            self.preferencesViewController?.bootButton.title = "Boot"
            self.preferencesViewController?.bootButton.isEnabled = true
            self.preferencesViewController?.terminalButton.isEnabled = false
            self.preferencesViewController?.manageDisksButton.isEnabled = true
            self.preferencesViewController?.cpuSlider.isEnabled = true
            self.preferencesViewController?.memorySlider.isEnabled = true
            self.preferencesViewController?.ipAddressField.stringValue = ""
            self.preferencesViewController?.macAddressField.stringValue = ""
        }
    }
    
    func setStateTurnedOn() {
        DispatchQueue.main.async {
            self.state = .on
            self.startStopMenuItem?.title = "Shut Down"
            self.startStopMenuItem?.isEnabled = true
            self.startStopMenuItem?.action = #selector(AppDelegate.stopUbuntu)
            self.preferencesViewController?.bootButton.title = "Shut down"
            self.preferencesViewController?.bootButton.isEnabled = true
            self.preferencesViewController?.terminalButton.isEnabled = true
            self.preferencesViewController?.manageDisksButton.isEnabled = false
            self.preferencesViewController?.cpuSlider.isEnabled = false
            self.preferencesViewController?.memorySlider.isEnabled = false
        }
    }
}

