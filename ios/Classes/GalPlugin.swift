import Flutter
import Photos
import UIKit

public class GalPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gal", binaryMessenger: registrar.messenger())
    let instance = GalPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "putVideo", "putImage":
      let args = call.arguments as! [String: Any]
      self.putMedia(
        path: args["path"] as! String,
        album: args["album"] as? String,
        isImage: call.method == "putImage"
      ) { _, error in
        if let error = error as NSError? {
          result(self.handleError(error: error))
        } else {
          result(nil)
        }
      }
    case "putImageBytes":
      let args = call.arguments as! [String: Any]
      self.putMediaBytes(
        bytes: (args["bytes"] as! FlutterStandardTypedData).data,
        album: args["album"] as? String
      ) { _, error in
        if let error = error as NSError? {
          result(self.handleError(error: error))
        } else {
          result(nil)
        }
      }
    case "open":
      self.open { result(nil) }
    case "hasAccess":
      result(self.hasAccess())
    case "requestAccess":
      self.requestAccess(completion: { granted in
        result(granted)
      })
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func putMedia(
    path: String, album: String?, isImage: Bool, completion: @escaping (Bool, Error?) -> Void
  ) {
    writeContent(
      assetChangeRequest: {
        isImage
          ? PHAssetChangeRequest.creationRequestForAsset(
            from: UIImage(contentsOfFile: path)!)
          : PHAssetChangeRequest.creationRequestForAssetFromVideo(
            atFileURL: URL(fileURLWithPath: path))!
      }, album: album, completion: completion)
  }

  private func putMediaBytes(
    bytes: Data, album: String?, completion: @escaping (Bool, Error?) -> Void
  ) {
    writeContent(
      assetChangeRequest: {
        PHAssetChangeRequest.creationRequestForAsset(from: UIImage(data: bytes)!)
      }, album: album, completion: completion)
  }

  private func writeContent(
    assetChangeRequest: @escaping () -> PHAssetChangeRequest,
    album: String?,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if let album = album {
      getAlbum(album: album) { collection, error in
        if let error = error {
          completion(false, error)
          return
        }
        PHPhotoLibrary.shared().performChanges(
          {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection!)
            albumChangeRequest!.addAssets(
              [assetChangeRequest().placeholderForCreatedAsset] as NSArray)
          },
          completionHandler: completion)
      }
      return
    }
    PHPhotoLibrary.shared().performChanges(
      {
        assetChangeRequest()
      },
      completionHandler: completion)
  }

  private func getAlbum(album: String, completion: @escaping (PHAssetCollection?, Error?) -> Void) {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", album)
    let collections: PHFetchResult = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .any, options: fetchOptions)
    if let collection = collections.firstObject {
      completion(collection, nil)
      return
    }
    PHPhotoLibrary.shared().performChanges(
      {
        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: album)
      },
      completionHandler: { success, error in
        if success {
          self.getAlbum(album: album, completion: completion)
          return
        }
        completion(nil, error)
      }
    )
  }

  private func open(completion: @escaping () -> Void) {
    guard let url = URL(string: "photos-redirect://") else { return }
    UIApplication.shared.open(url, options: [:]) { _ in completion() }
  }

  private func hasAccess() -> Bool {
    if #available(iOS 14, *) {
      return PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized
    } else {
      return PHPhotoLibrary.authorizationStatus() == .authorized
    }
  }

  /// If permissions have already been granted or denied by the user,
  /// returns the result immediately, without displaying a dialog.
  /// See: https://qiita.com/fuziki/items/87a3a1a8e481a1546b38
  private func requestAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in
        completion(PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { _ in
        completion(PHPhotoLibrary.authorizationStatus() == .authorized)
      }
    }
  }

  private func handleError(error: NSError) -> FlutterError {
    let message = error.localizedDescription
    let details = Thread.callStackSymbols

    switch PHErrorCode(rawValue: error.code) {
    case .accessRestricted, .accessUserDenied:
      return FlutterError(code: "ACCESS_DENIED", message: message, details: details)

    case .identifierNotFound, .multipleIdentifiersFound, .requestNotSupportedForAsset,
      .videoConversionFailed, .unsupportedVideoCodec:
      return FlutterError(code: "NOT_SUPPORTED_FORMAT", message: message, details: details)

    case .notEnoughSpace:
      return FlutterError(code: "NOT_ENOUGH_SPACE", message: message, details: details)

    default:
      return FlutterError(code: "UNEXPECTED", message: message, details: details)
    }
  }
}

/// Low iOS versions do not have an enum defined, so [rawValue] must be used.
/// If [rawValue] is not defined either, no handle is possible.
/// You can check Apple's documentation by replacing the [$caseName] of the following URL
/// Some documents are not provided by Apple.
/// https://developer.apple.com/documentation/photokit/phphotoserror/code/$caseName
enum PHErrorCode: Int {

  // [PHPhotosError.identifierNotFound]
  case identifierNotFound = 3201

  // [PHPhotosError.multipleIdentifiersFound]
  case multipleIdentifiersFound = 3202

  // Apple has not released documentation.
  case videoConversionFailed = 3300

  // Apple has not released documentation.
  case unsupportedVideoCodec = 3302

  // [PHPhotosError.notEnoughSpace]
  case notEnoughSpace = 3305

  // [PHPhotosError.requestNotSupportedForAsset]
  case requestNotSupportedForAsset = 3306

  // [PHPhotosError.accessRestricted]
  case accessRestricted = 3310

  // [PHPhotosError.accessUserDenied]
  case accessUserDenied = 3311
}
