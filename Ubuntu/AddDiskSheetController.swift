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
    
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var errorLabel: NSTextField!
    
    var parentController: DiskManagerViewController!
    
    override func viewDidAppear() {
        nameTextField.stringValue = ""
        spaceTextField.integerValue = 1
        formatPopUpButton.selectItem(at: 0)
        spaceSuffixPopUpButton.selectItem(at: 1)
        errorLabel.isHidden = true
        spinner.isHidden = true
    }
    
    @IBAction func onCreateClicked(_ sender: Any) {
        errorLabel.isHidden = true
        spinner.isHidden = false
        spinner.startAnimation(nil)
        let format = formatPopUpButton.indexOfSelectedItem == 1 ? DiskFormat.raw : .qcow2
        let storageUnit = spaceSuffixPopUpButton.indexOfSelectedItem == 1 ? StorageUnit.gb : .mb
        let disk = DiskImage(name: nameTextField.stringValue, format: format, storage: spaceTextField.intValue, storageUnit: storageUnit, mounted: true)
        // Validation and Creation
        DispatchQueue.global().async {
            for d in self.parentController.disks {
                if d.name == disk.name {
                    // duplicate
                    DispatchQueue.main.async {
                        self.errorLabel.isHidden = false
                        self.spinner.stopAnimation(nil)
                        self.spinner.isHidden = true
                        self.errorLabel.stringValue = "Disk by this name already exists"
                    }
                    return
                }
            }
            
            if DiskTools.diskExistWithName(d: disk.name) {
                DispatchQueue.main.async {
                    self.errorLabel.isHidden = false
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true
                    self.errorLabel.stringValue = "File already exists by same name"
                }
                return
            }
            
            do {
                try DiskTools.createDisk(d: disk)
            }
            catch {
                DispatchQueue.main.async {
                    self.errorLabel.isHidden = false
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true
                    self.errorLabel.stringValue = "Err something went wrong.."
                }
                return
            }
            DispatchQueue.main.async {
                self.parentController.addDisk(disk)
                self.dismiss(nil)
            }
        }
    }
    
    @IBAction func onCancelClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
}
