//
//  AddDiskSheetController.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 14/01/21.
//

import Cocoa

enum DiskFormat {
    case qcow2, raw
}

enum StorageUnit {
    case gb, mb
}

struct DiskImage {
    var name: String
    var format: DiskFormat
    var storage: Int32
    var storageUnit: StorageUnit
    var mounted: Bool
}

func formatDescription(_ format: DiskFormat) -> String {
    switch format {
    case .qcow2:
        return "QCoW2 Image"
    case .raw:
        return "Raw Image"
    }
}

func unitDescription(_ unit: StorageUnit) -> String {
    switch unit {
    case .gb:
        return "GB"
    case .mb:
        return "MB"
    }
}

class AddDiskSheetController: NSViewController {
    @IBOutlet weak var formatPopUpButton: NSPopUpButton!
    @IBOutlet weak var spaceSuffixPopUpButton: NSPopUpButton!
    @IBOutlet weak var spaceTextField: NSTextField!
    @IBOutlet weak var nameTextField: NSTextField!
    
    var parentController: DiskManagerViewController!
    
    override func viewDidAppear() {
        nameTextField.stringValue = ""
        spaceTextField.integerValue = 1
        formatPopUpButton.selectItem(at: 0)
        spaceSuffixPopUpButton.selectItem(at: 1)
    }
    
    @IBAction func onCreateClicked(_ sender: Any) {
        let format = formatPopUpButton.indexOfSelectedItem == 1 ? DiskFormat.raw : .qcow2
        let storageUnit = spaceSuffixPopUpButton.indexOfSelectedItem == 1 ? StorageUnit.gb : .mb
        let disk = DiskImage(name: nameTextField.stringValue, format: format, storage: spaceTextField.intValue, storageUnit: storageUnit, mounted: true)
        do {
            try DiskTools.createDisk(d: disk)
        }
        catch { print("err") }
        parentController.addDisk(disk)
        self.dismiss(nil)
    }
    
    @IBAction func onCancelClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
}
