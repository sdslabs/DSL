//
//  ProgressSheetController.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 12/01/21.
//

import Cocoa


class ProgressSheetController: NSViewController, URLSessionDownloadDelegate {

    var mainViewController: ViewController?
    
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var progressLabel: NSTextField!

    var task: URLSessionDownloadTask!
    var destPath: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func onCancel(_ sender: Any) {
        task.cancel()
        mainViewController?.dismiss(self)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        if downloadTask == task {
            let percentDownloaded = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let totalGigabytesWritten = String(format: "%.2f", Double(totalBytesWritten) / Double(1024 * 1024 * 1024))
            let totalGigabytesExpected = String(format: "%.2f", Double(totalBytesExpectedToWrite) / Double(1024 * 1024 * 1024))
            DispatchQueue.main.async {
                self.progressBar.doubleValue = percentDownloaded * 100
                self.progressLabel.stringValue = "\(totalGigabytesWritten) / \(totalGigabytesExpected) GB"
            }
            print(percentDownloaded * 100)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        do {
            try FileManager.default.moveItem(atPath: location.path, toPath: destPath)
            mainViewController?.app.setStateTurnedOff()
        }
        catch {}
        
        DispatchQueue.main.async {
            self.progressBar.stopAnimation(nil)
            self.mainViewController?.app.setStateTurnedOff()
            self.mainViewController?.dismiss(self)
        }
    }
    
    func download(from url: URL, to path: String) {
        progressBar.startAnimation(nil)
        let configuration = URLSessionConfiguration.default
        let operationQueue = OperationQueue()
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
            
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
        task = downloadTask
        destPath = path
    }

}
