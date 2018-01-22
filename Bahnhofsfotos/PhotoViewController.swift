//
//  PhotoViewController.swift
//  Bahnhofsfotos
//
//  Created by Miguel Dönicke on 17.12.16.
//  Copyright © 2016 MrHaitec. All rights reserved.
//

import AAShareBubbles
import Imaginary
import ImagePicker
import Lightbox
import MessageUI
import Social
import SwiftyUserDefaults
import UIKit

class PhotoViewController: UIViewController {

  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var shareBarButton: UIBarButtonItem!
  @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
  
  override func viewDidLoad() {
    super.viewDidLoad()

    title = StationStorage.currentStation?.name
    shareBarButton.isEnabled = false
    
    guard let station = StationStorage.currentStation else { return }
    
    if station.hasPhoto {
      if let photoUrl = station.photoUrl, let imageUrl = URL(string: photoUrl) {
        imageView.image = nil
        activityIndicatorView.startAnimating()
        imageView.setImage(url: imageUrl) { result in
          self.activityIndicatorView.stopAnimating()
        }
      }
    } else {
      do {
        if let photo = try PhotoStorage.fetch(id: station.id) {
          imageView.image = UIImage(data: photo.data)
        }
      } catch {
        debugPrint(error.localizedDescription)
      }
    }
  }

  @IBAction func pickImage(_ sender: Any) {
    guard let station = StationStorage.currentStation else { return }
    if station.hasPhoto && imageView.image != nil {
      LightboxConfig.PageIndicator.enabled = false
      let lightboxController = LightboxController(images: [LightboxImage(image: imageView.image!)], startIndex: 0)
      present(lightboxController, animated: true, completion: nil)
      return
    }
    
    let configuration = Configuration()
    configuration.allowMultiplePhotoSelection = false
    configuration.allowedOrientations = .landscape
    configuration.cancelButtonTitle = "Abbruch"
    configuration.doneButtonTitle = "Fertig"

    let imagePicker =  ImagePickerController(configuration: configuration)
    imagePicker.delegate = self
    present(imagePicker, animated: true, completion: nil)
  }

  @IBAction func shareTouched(_ sender: Any) {
    let shareBubbles = AAShareBubbles(centeredInWindowWithRadius: 100)
    shareBubbles?.delegate = self
    shareBubbles?.showMailBubble = true
    shareBubbles?.showTwitterBubble = true
    shareBubbles?.showFacebookBubble = true
    shareBubbles?.show()
  }

  @IBAction func closeTouched(_ sender: Any) {
    navigationController?.popViewController(animated: true)
  }

  @IBAction func openNavigation(_ sender: Any) {
    if let station = StationStorage.currentStation {
      Helper.openNavigation(to: station)
    }
  }

  // show error message
  func showError(_ error: String) {
    let alert = UIAlertController(title: nil, message: error, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }

  // show mail controller
  func showMailController() {
    guard let image = imageView.image else { return }
    guard let id = StationStorage.currentStation?.id else { return }
    guard let name = StationStorage.currentStation?.title else { return }
    guard let email = CountryStorage.currentCountry?.email else { return }
    guard let country = CountryStorage.currentCountry?.code.lowercased() else { return }

    if MFMailComposeViewController.canSendMail() {
      guard let username = Defaults[.accountName] else {
        showError("Kein Accountname hinterlegt. Bitte unter \"Meine Daten\" angeben.")
        return
      }

      var text = "Bahnhof: \(name)\n"
      text += "Lizenz: \(Defaults[.license] == .cc40 ? "CC4.0" : "CC0")\n"
      text += "Accountname: \(username)\n"
      text += "Verlinkung: \(Defaults[.accountLinking] == true ? "Ja" : "Nein")\n"
      text += "Accounttyp: \(Defaults[.accountType])"

      let mailController = MFMailComposeViewController()
      mailController.mailComposeDelegate = self
      mailController.setToRecipients([email])
      mailController.setSubject("Neues Bahnhofsfoto: \(name)")
      mailController.setMessageBody(text, isHTML: false)
      if let data = UIImageJPEGRepresentation(image, 1) {
        mailController.addAttachmentData(data, mimeType: "image/jpeg", fileName: "\(username)-\(country)-\(id).jpg")
      }
      present(mailController, animated: true, completion: nil)
    } else {
      showError("Es können keine E-Mail verschickt werden.")
    }
  }

  // show twitter controller
  func showTwitterController() {
    guard let name = StationStorage.currentStation?.title,
      let tags = CountryStorage.currentCountry?.twitterTags else { return }
    guard let image = imageView.image else {
      showError("Kein Bild ausgewählt.")
      return
    }
    guard SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter) else {
      showError("Twitter nicht im System gefunden.")
      return
    }

    if let twitterController = SLComposeViewController(forServiceType: SLServiceTypeTwitter) {
      twitterController.setInitialText("\(name) \(tags)")
      twitterController.add(image)
      twitterController.completionHandler = { result in
        if result == .done {
          self.dismiss(animated: true, completion: nil)
        }
      }
      present(twitterController, animated: true, completion: nil)
    } else {
      showError("Es können keine Tweets verschickt werden.")
    }
  }

}

// MARK: - ImagePickerDelegate
extension PhotoViewController: ImagePickerDelegate {

  func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
    imagePicker.showGalleryView()
  }

  func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
    if !images.isEmpty {
      imageView.image = images[0]
      shareBarButton.isEnabled = true
      if let station = StationStorage.currentStation, let imageData = UIImageJPEGRepresentation(images[0], 1) {
        let photo = Photo(data: imageData, withId: station.id)
        try? PhotoStorage.save(photo)
      }
    }
    imagePicker.dismiss(animated: true, completion: nil)
  }

  func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
    imagePicker.dismiss(animated: true, completion: nil)
  }

}

// MARK: - AAShareBubblesDelegate
extension PhotoViewController: AAShareBubblesDelegate {

  func aaShareBubbles(_ shareBubbles: AAShareBubbles!, tappedBubbleWith bubbleType: AAShareBubbleType) {
    switch bubbleType {
    case .mail:
      showMailController()
    case .twitter:
      showTwitterController()
    default:
      break
    }
  }

}

// MARK: - MFMailComposeViewControllerDelegate
extension PhotoViewController: MFMailComposeViewControllerDelegate {

  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true, completion: nil)
  }

}
