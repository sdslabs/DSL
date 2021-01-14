//
//  DiskManager.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 14/01/21.
//

import Cocoa

class MountCell: NSTableCellView {
    @IBOutlet weak var checkBox: NSButton!
}

class DiskManagerViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var app: AppDelegate!
    
    @IBOutlet weak var addImageButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    var disks: [DiskImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.dataSource = self
        outlineView.delegate = self
    }
    
    override func viewDidAppear() {
        outlineView.reloadData()
    }
    
    lazy var addDiskSheet: AddDiskSheetController = {
        var sheet = NSStoryboard.main!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("add-disk")) as! AddDiskSheetController
        sheet.parentController = self
        return sheet
    }()
    
    @IBAction func addImageButtonClicked(_ sender: Any) {
        self.presentAsSheet(addDiskSheet)
    }
    
    @IBAction func saveAndClose(_ sender: Any) {
        for i in 0..<disks.count {
            let view = outlineView.view(atColumn: 2, row: i, makeIfNecessary: false) as! MountCell
            disks[i].mounted = view.checkBox.state == .on ? true : false
        }
        app.updateDisks(disks)
        self.dismiss(nil)
    }
    
    // DataSource Methods
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return disks.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return disks[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    // Delegate Methods
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        var cellIdentifier: NSUserInterfaceItemIdentifier
        var val: String = ""
        
        if let disk = item as? DiskImage {
            switch colIdentifier {
            case NSUserInterfaceItemIdentifier(rawValue: "imageColumn"):
                cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "imageCell")
                val = disk.name
            case NSUserInterfaceItemIdentifier(rawValue: "summaryColumn"):
                cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "summaryCell")
                val = "\(disk.storage) \(unitDescription(disk.storageUnit)) \(formatDescription(disk.format))"
            case NSUserInterfaceItemIdentifier(rawValue: "mountColumn"):
                cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "mountCell")
                guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? MountCell else { return nil }
                cell.checkBox.state = disk.mounted ? .on : .off
                return cell
            default:
                return nil
            }

            guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }
            cell.textField?.stringValue = val
            return cell
        }
        return nil
    }
    
    func addDisk(_ disk: DiskImage) {
        disks.append(disk)
        app.updateDisks(disks)
        outlineView.reloadData()
    }
}
