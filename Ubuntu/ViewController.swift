//
//  ViewController.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 08/01/21.
//

import Cocoa

class ViewController: NSViewController {

    var app: AppDelegate!
    
    @IBOutlet weak var ipAddressField: NSTextField!
    @IBOutlet weak var cpuSlider: NSSlider!
    @IBOutlet weak var cpuLabel: NSTextField!
    @IBOutlet weak var memorySlider: NSSlider!
    @IBOutlet weak var memoryLabel: NSTextField!
    @IBOutlet weak var bootButton: NSButton!
    @IBOutlet weak var terminalButton: NSButton!
    
    lazy var progressSheet: ProgressSheetController = {
        var sheet = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("progress")) as! ProgressSheetController
        sheet.mainViewController = self
        return sheet
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func setApp(appDel: AppDelegate) {
        app = appDel
        cpuSlider.integerValue = app.vCPU
        cpuLabel.integerValue = app.vCPU
        memorySlider.integerValue = app.memory
        memoryLabel.stringValue = "\(memorySlider.integerValue)G"
    }

    @IBAction func onCPUChange(_ sender: Any) {
        cpuLabel.integerValue = cpuSlider.integerValue
        app.updateCPU(cpuSlider.integerValue)
    }
    
    @IBAction func onMemoryChange(_ sender: Any) {
        memoryLabel.stringValue = "\(memorySlider.integerValue)G"
        app.updateMemory(memorySlider.integerValue)
    }
    
    func setControls(val: Bool) {
        cpuSlider.isEnabled = val
        memorySlider.isEnabled = val
        terminalButton.isEnabled = !val
    }
    
    @IBAction func bootUbuntu(_ sender: Any) {
        app.bootUbuntu()
    }
    
    @IBAction func openTerminal(_ sender: Any) {
//        let terminalTask = Process()
//        terminalTask.launchPath = "/usr/bin/open"
//        terminalTask.arguments = [
//            "-a", "Terminal", "ssh kanav@\(app.ipAddress)"
//        ]
//        terminalTask.launch()
        
        let script = NSAppleScript.init(source: "tell application \"Terminal\" to do script \"cd ~/Desktop\"")
        script?.executeAndReturnError(nil)
        
    }
    
    func showProgressSheet() {
        presentAsSheet(progressSheet)
    }
}

