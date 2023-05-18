import UIKit
import MobileCoreServices
import AVFoundation
import Photos

protocol AttachmentManagerProtocol {
    
    func showDocumentsPickerView()
    func selected(urls: [URL], completion: @escaping([ODMFile]?, String?) -> ())
    
}

@available(iOS 14.0, *)
class AttachmentManager {
    
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
    
    private var currentVC: UIViewController?
    typealias PickingViewController = UIViewController & UIDocumentPickerDelegate
    private let controller: PickingViewController
    private let serverManager = ODMServerManager.shared()
    private let fileManager = FileManager.default
    private var documentsDirectory : URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("uploadingFiles")
    }
    let supportedExtensions: [String] = MymeType.allCases
        .map ({ $0.extensions })
        .flatMap({ (element: [String]) -> [String] in
            return element
        })
    
    init(controller: PickingViewController) {
        self.controller = controller
    }
    
    //MARK: Private methods:
    private func createTempDirectory() {
        guard let documentsDirectory else { return }
        do {
            try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch {
            print(error)
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
                                completion: @escaping (([ODMAttachment]?, String?) -> Void)) {
        let newUrls = urls.compactMap { copySelectedFileFrom(url: $0) }
        let urlsWithJPG = saveImagesAsJPG(for: newUrls)
        var attachments: [ODMAttachment] = []
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
                               completion: @escaping ((ODMAttachment?, String?) -> Void)) {
        let fileExtension = url.pathExtension
        guard let mimeType = MymeType(rawValue: fileExtension) else { return }
        let fileName = url.deletingPathExtension().lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            let attachment = ODMAttachment(data: data,
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
                try fileManager.removeItem(atPath: newPath.path)
            }
            try fileManager.copyItem(at: url, to: newPath)
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
    
}

//MARK: AttachmentManagerProtocol
@available(iOS 14.0, *)
extension AttachmentManager: AttachmentManagerProtocol {
    
    func showDocumentsPickerView() {
        var types = supportedExtensions.compactMap {
            UTType(tag: $0, tagClass: .filenameExtension, conformingTo: nil)
        }
        types.append(.image)
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        documentPicker.delegate = controller
        documentPicker.allowsMultipleSelection = true
        controller.present(documentPicker, animated: true)
    }
    
    func selected(urls: [URL], completion: @escaping([ODMFile]?, String?) -> ()) {
        createTempDirectory()
        getAttachments(for: urls) { [weak self] attachments, errorResponse in
            if let errorResponse {
                completion(nil, errorResponse)
            } else if let attachments {
                let group = DispatchGroup()
                var files: [ODMFile] = []
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
    
}
