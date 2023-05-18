import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import Photos

//MARK: Use it in your VC:
//    attachmentHandler?.showAttachmentActionSheet(controller: self)
//    attachmentHandler?.isLoading = {
//        show progress
//    }
//    attachmentHandler?.filePickedBlock = {[weak self] attachedFiles, errorResponse in
//          guard let self else { return }
//          hide progress
//          use files and handle error
//    }

@objc public enum SupportedByServerFileType : Int, RawRepresentable, CaseIterable {
    
    case imageJP2
    case imagePNG
    case imageJPEG
    case imageGIF
    case spreadSheet
    case excel
    case applicationRTF
    case wordprocessingml
    case pdf
    case msword
    case csv
    case openDocumentText
    case zip
    case videoMP4
    case videoQuickTime
    case videoWebm
    
    public typealias RawValue = String
    
    public var rawValue: RawValue {
        switch self {
        case .imageJP2:
            return "image/jp2"
        case .imagePNG:
            return "image/png"
        case .imageJPEG:
            return "image/jpeg"
        case .imageGIF:
            return "image/gif"
        case .spreadSheet:
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .excel:
            return "application/vnd.ms-excel"
        case .applicationRTF:
            return "application/rtf"
        case .wordprocessingml:
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .pdf:
            return "application/pdf"
        case .msword:
            return "application/msword"
        case .csv:
            return "text/csv"
        case .openDocumentText:
            return "application/vnd.oasis.opendocument.text"
        case .zip:
            return "application/zip"
        case .videoMP4:
            return "video/mp4"
        case .videoQuickTime:
            return "video/quicktime"
        case .videoWebm:
            return "video/webm"
        }
    }
    
    public init?(rawValue: RawValue) {
        switch rawValue {
        case "jp2":
            self = .imageJP2
        case "png":
            self = .imagePNG
        case "jpeg", "jpg":
            self = .imageJPEG
        case "gif":
            self = .imageGIF
        case "xlsx":
            self = .spreadSheet
        case "xls":
            self = .excel
        case "rtf":
            self = .applicationRTF
        case "docx":
            self = .wordprocessingml
        case "pdf":
            self = .pdf
        case "doc":
            self = .msword
        case "csv":
            self = .csv
        case "odt":
            self = .openDocumentText
        case "zip":
            self = .zip
        case "mp4":
            self = .videoMP4
        case "mov":
            self = .videoQuickTime
        case "webm":
            self = .videoWebm
        default:
            return nil
        }
    }
    
    //MARK: Computed properties:
    var extensions: [String] {
        switch self {
        case .imageJP2:
            return ["jp2"]
        case .imagePNG:
            return ["png"]
        case .imageJPEG:
            return ["jpeg", "jpg"]
        case .imageGIF:
            return ["gif"]
        case .spreadSheet:
            return ["xlsx"]
        case .excel:
            return ["xls"]
        case .applicationRTF:
            return ["rtf"]
        case .wordprocessingml:
            return ["docx"]
        case .pdf:
            return ["pdf"]
        case .msword:
            return ["doc"]
        case .csv:
            return ["csv"]
        case .openDocumentText:
            return ["odt"]
        case .zip:
            return ["zip"]
        case .videoMP4:
            return ["mp4"]
        case .videoQuickTime:
            return ["mov"] // convert -> mp4
        case .videoWebm:
            return ["webm"]
        }
    }
    
}

protocol AttachmentManagerProtocol {
    
    func showAttachmentActionSheet(controller: UIViewController)
    var isLoading: (() -> Void)? { get set }
    var filePickedBlock: (([FileTypeReceivedFromServer]?, String?) -> Void)? { get set }
}

@available(iOS 14.0, *)
class AttachmentManager: NSObject, AttachmentHandlerProtocol {
    static let shared = AttachmentManager()
    fileprivate var currentVC: UIViewController?
    
    //MARK: - Internal Properties
    var filePickedBlock: (([FileTypeReceivedFromServer]?, String?) -> Void)?
    var isLoading: (() -> Void)?
    private let serverManager = YourServerManager()
    private let fileManager = FileManager.default
    private var documentsDirectory : URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("uploadingFiles")
    }
    
    enum AttachmentType: String{
        case camera, video, photoLibrary
    }
    
    
    //MARK: - Constants
    struct Constants {
        static let actionFileTypeHeading = "Add a File"
        static let actionFileTypeDescription = "Choose a filetype to add..."
        static let camera = "Camera"
        static let phoneLibrary = "Phone Library"
        static let video = "Video"
        static let file = "File"
        static let alertForPhotoLibraryMessage = "App does not have access to your photos. To enable access, tap settings and turn on Photo Library Access."
        static let alertForCameraAccessMessage = "App does not have access to your camera. To enable access, tap settings and turn on Camera."
        static let alertForVideoLibraryMessage = "App does not have access to your video. To enable access, tap settings and turn on Video Library Access."
        static let settingsBtnTitle = "Settings"
        static let cancelBtnTitle = "Cancel"
    }
    
    //MARK: - showAttachmentActionSheet
    // This function is used to show the attachment sheet for image, video, photo and file.
    func showAttachmentActionSheet(controller: UIViewController) {
        currentVC = controller
        let actionSheet = UIAlertController(title: Constants.actionFileTypeHeading, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: Constants.camera, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(attachmentTypeEnum: .camera, vc: self.currentVC!)
        }))
        
        actionSheet.addAction(UIAlertAction(title: Constants.phoneLibrary, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(attachmentTypeEnum: .photoLibrary, vc: self.currentVC!)
        }))
        
        actionSheet.addAction(UIAlertAction(title: Constants.video, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(attachmentTypeEnum: .video, vc: self.currentVC!)
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: Constants.file, style: .default, handler: { (action) -> Void in
            self.documentPicker()
        }))
        
        actionSheet.addAction(UIAlertAction(title: Constants.cancelBtnTitle, style: .cancel, handler: nil))
        
        controller.present(actionSheet, animated: true, completion: nil)
    }
    
    //MARK: - Send files to server
    private func selected(urls: [URL], completion: @escaping([FileTypeReceivedFromServer]?, String?) -> ()) {
        isLoading?()
        getAttachments(for: urls) { [weak self] attachments, errorResponse in
            if let errorResponse {
                completion(nil, errorResponse)
            } else if let attachments {
                let group = DispatchGroup()
                var files: [FileTypeReceivedFromServer] = []
                var errorResponse: String?
                attachments.forEach { attachment in
                    group.enter()
                    self?.serverManager?.uploadFile(with: attachment.data,
                                                    mimeType: attachment.mimeType,
                                                    fileName: attachment.fileName,
                                                    with: .comment,
                                                    completionBlock: { file, error in
                        if let error {
                            errorResponse = error
                        } else if let file {
                            files.append(file)
                        }
                        group.leave()
                    })
                }
                group.notify(queue: DispatchQueue.main) { [weak self] in
                    guard let self else { return }
                    self.deleteTempDirectory()
                    completion(files, errorResponse)
                }
            }
        }
    }
    
    //MARK: Private methods:
    private func createTempDirectory() {
        guard let documentsDirectory else { return }
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            do {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print(error)
            }
        }
    }
    
    private func deleteTempDirectory() {
        guard let documentsDirectory else { return }
        do {
            try fileManager.removeItem(at: documentsDirectory)
        } catch {
            print(error)
        }
    }
    
    private func getAttachments(for urls: [URL],
                                completion: @escaping (([FilTypeToDownloadToServer]?, String?) -> Void)) {
        let newUrls = urls.compactMap { copySelectedFileFrom(url: $0) }
        let urlsWithJPG = saveImagesAsJPG(for: newUrls)
        var attachments: [FilTypeToDownloadToServer] = []
        let group = DispatchGroup()
        var errorResponse: String?
        urlsWithJPG.forEach { newUrl in
            group.enter()
            getAttachment(from: newUrl) { attachment, error in
                if let error {
                    errorResponse = error
                } else if let attachment {
                    attachments.append(attachment)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            completion(attachments, errorResponse)
        }
    }
    
    private func getAttachment(from url: URL,
                               completion: @escaping ((FilTypeToDownloadToServer?, String?) -> Void)) {
        let fileExtension = url.pathExtension.lowercased()
        guard let fileType = SupportedByServerFileType(rawValue: fileExtension) else {
            return
        }
        let fileName = url.deletingPathExtension().lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            let attachment = FilTypeToDownloadToServer(data: data,
                                           fileName: fileName,
                                           mimeType: mimeType.rawValue)
            completion(attachment, nil)
        } catch {
            completion(nil, error.localizedDescription)
        }
    }
    
    private func copySelectedFileFrom(url: URL) -> URL? {
        let lastComponent = url.lastPathComponent
        guard let newPath = documentsDirectory?
            .appendingPathComponent(lastComponent) else {
            return nil
        }
        do {
            if fileManager.fileExists(atPath: newPath.path) {
                return newPath
            } else {
                try fileManager.copyItem(at: url, to: newPath)
            }
        } catch {
            print(error)
        }
        return newPath
    }
    
    private func saveImagesAsJPG(for urls: [URL]) -> [URL] {
        var result:[URL] = []
        urls.forEach { url in
            let fileName = url.deletingPathExtension().lastPathComponent
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        try fileManager.removeItem(atPath: url.path)
                    } catch let removeError {
                        print("couldn't remove file at path", removeError)
                    }
                }
                guard let jpgURL = documentsDirectory?
                    .appendingPathComponent(fileName + ".jpg") else {
                    return
                }
                if fileManager.fileExists(atPath: jpgURL.path) {
                    do {
                        try fileManager.removeItem(atPath: url.path)
                    } catch let removeError {
                        print("couldn't remove file at path", removeError)
                    }
                }
                let normalizedImage = image.normalizedOrientation()
                guard let data = normalizedImage?.jpegData(compressionQuality: 1) else {
                    return
                }
                do {
                    try data.write(to: jpgURL)
                } catch let error {
                    print("error saving file with error", error)
                }
                result.append(jpgURL)
            } else {
                result.append(url)
            }
        }
        return result
    }
    
    func convertVideoToMP4(inputURL: URL, completion: @escaping ((URL?, String?) -> Void)) {
        let avAsset = AVURLAsset(url: inputURL, options: nil)
        //Create Export session
        let exportSession = AVAssetExportSession(asset: avAsset,
                                                 presetName: AVAssetExportPresetPassthrough)
        let fileName = inputURL
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "trim.", with: "")
        let newURL = URL(fileURLWithPath:  NSTemporaryDirectory())
            .appendingPathComponent(fileName + ".mp4")
        if fileManager.fileExists(atPath: newURL.path) {
            do {
                try fileManager.removeItem(atPath: newURL.path)
            } catch let removeError {
                print("couldn't remove file at path", removeError)
            }
        }
        exportSession!.outputURL = newURL
        exportSession!.outputFileType = AVFileType.mp4
        exportSession!.shouldOptimizeForNetworkUse = true
        let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 0)
        let range = CMTimeRangeMake(start: start,
                                    duration: avAsset.duration)
        exportSession!.timeRange = range
        exportSession!.exportAsynchronously(completionHandler: {() -> Void in
            switch exportSession!.status {
            case .failed:
                let error = exportSession!.error?.localizedDescription ?? "attachment_loading_error".localized
                print(error)
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            case .cancelled:
                print("Export canceled")
            case .completed:
                //Video conversion finished
                DispatchQueue.main.async {
                    completion(newURL, nil)
                }
            default:
                break
            }
        })
    }
    
    //MARK: - Authorisation Status
    // This is used to check the authorisation status whether user gives access to import the image, photo library, video.
    // if the user gives access, then we can import the data safely
    // if not show them alert to access from settings.
    func authorisationStatus(attachmentTypeEnum: AttachmentType, vc: UIViewController) {
        currentVC = vc
        
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            if attachmentTypeEnum == AttachmentType.camera {
                openCamera()
            }
            if attachmentTypeEnum == AttachmentType.photoLibrary {
                photoLibrary()
            }
            if attachmentTypeEnum == AttachmentType.video {
                videoLibrary()
            }
        case .denied:
            print("permission denied")
            self.addAlertForSettings(attachmentTypeEnum)
        case .notDetermined:
            print("Permission Not Determined")
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == PHAuthorizationStatus.authorized {
                    // photo library access given
                    print("access given")
                    if attachmentTypeEnum == AttachmentType.camera{
                        self.openCamera()
                    }
                    if attachmentTypeEnum == AttachmentType.photoLibrary{
                        self.photoLibrary()
                    }
                    if attachmentTypeEnum == AttachmentType.video{
                        self.videoLibrary()
                    }
                } else {
                    print("restriced manually")
                    self.addAlertForSettings(attachmentTypeEnum)
                }
            })
        case .restricted:
            print("permission restricted")
            self.addAlertForSettings(attachmentTypeEnum)
        default:
            break
        }
    }
    
    //MARK: - CAMERA PICKER
    //This function is used to open camera from the iphone and
    func openCamera(){
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .camera
            currentVC?.present(myPickerController,
                               animated: true,
                               completion: nil)
        }
    }
    
    //MARK: - PHOTO PICKER
    func photoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary){
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .photoLibrary
            currentVC?.present(myPickerController,
                               animated: true,
                               completion: nil)
        }
    }
    
    //MARK: - VIDEO PICKER
    func videoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary){
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .photoLibrary
            myPickerController.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
            currentVC?.present(myPickerController, animated: true, completion: nil)
        }
    }
    
    //MARK: - FILE PICKER
    func documentPicker() {
        let supportedExtensions: [String] = SupportedByServerFileType
            .allCases
            .map ({ $0.extensions })
            .flatMap({ (element: [String]) -> [String] in
                return element
            })
        var types = supportedExtensions.compactMap {
            UTType(tag: $0, tagClass: .filenameExtension, conformingTo: nil)
        }
        types.append(.image)
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        documentPicker.modalPresentationStyle = .formSheet
        currentVC?.present(documentPicker, animated: true)
    }
    
    //MARK: - SETTINGS ALERT
    func addAlertForSettings(_ attachmentTypeEnum: AttachmentType) {
        var alertTitle: String = ""
        if attachmentTypeEnum == AttachmentType.camera {
            alertTitle = Constants.alertForCameraAccessMessage
        }
        if attachmentTypeEnum == AttachmentType.photoLibrary {
            alertTitle = Constants.alertForPhotoLibraryMessage
        }
        if attachmentTypeEnum == AttachmentType.video {
            alertTitle = Constants.alertForVideoLibraryMessage
        }
        
        let cameraUnavailableAlertController = UIAlertController (title: alertTitle ,
                                                                  message: nil,
                                                                  preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: Constants.settingsBtnTitle,
                                           style: .destructive) { (_) -> Void in
            let settingsUrl = NSURL(string:UIApplication.openSettingsURLString)
            if let url = settingsUrl {
                UIApplication.shared.open(url as URL,
                                          options: [:],
                                          completionHandler: nil)
            }
        }
        let cancelAction = UIAlertAction(title: Constants.cancelBtnTitle,
                                         style: .default,
                                         handler: nil)
        cameraUnavailableAlertController .addAction(cancelAction)
        cameraUnavailableAlertController .addAction(settingsAction)
        currentVC?.present(cameraUnavailableAlertController ,
                           animated: true,
                           completion: nil)
    }
}

//MARK: - IMAGE PICKER DELEGATE
// This is responsible for image picker interface to access image, video and then responsibel for canceling the picker
@available(iOS 14.0, *)
extension AttachmentManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        currentVC?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        createTempDirectory()
        //File from library
        if let imageURL = info[.imageURL] as? URL {
            selected(urls: [imageURL]) {[weak self] files, errorMessage in
                self?.filePickedBlock?(files, errorMessage)
            }
        }
        //File from camera
        if let image = info[.originalImage] as? UIImage,
           let imageURL = saveImage(image: image) {
            selected(urls: [imageURL]) {[weak self] files, errorMessage in
                self?.filePickedBlock?(files, errorMessage)
            }
        }
        //Video file
        if let videoUrl = info[.mediaURL] as? URL,
           let copy = copySelectedFileFrom(url: videoUrl) {
            convertVideoToMP4(inputURL: copy) {[weak self] mp4URL, errorResponse in
                if let errorResponse {
                    self?.filePickedBlock?(nil, errorResponse)
                } else if let mp4URL {
                    DispatchQueue.main.async {
                        self?.selected(urls: [mp4URL]) {[weak self] files, errorMessage in
                            self?.filePickedBlock?(files, errorMessage)
                        }
                    }
                }
            }
        }
        currentVC?.dismiss(animated: true, completion: nil)
    }
    
    private func saveImage(image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 1) else {
            return nil
        }
        do {
            let fileName = UUID().uuidString + ".jpg"
            guard let url = documentsDirectory?.appendingPathComponent(fileName) else {
                return nil
            }
            try data.write(to: url)
            return url
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
}

//MARK: UIDocumentPickerDelegate
@available(iOS 14.0, *)
extension AttachmentManager: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        createTempDirectory()
        urls.forEach {
            guard $0.startAccessingSecurityScopedResource() else { return }
        }
        defer {
            urls.forEach { $0.stopAccessingSecurityScopedResource() }
        }
        selected(urls: urls) {[weak self] files, errorMessage in
            self?.filePickedBlock?(files, errorMessage)
        }
    }
    
    //    Method to handle cancel action.
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
    
}
