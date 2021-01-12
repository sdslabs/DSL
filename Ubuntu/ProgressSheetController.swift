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
        mainViewController?.dismiss(self)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        if downloadTask == task {
            let percentDownloaded = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.progressBar.doubleValue = percentDownloaded * 100
            }
            print(percentDownloaded * 100)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        progressBar.stopAnimation(nil)
        do {
            try FileManager.default.moveItem(atPath: location.path, toPath: destPath)
        }
        catch {}
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
