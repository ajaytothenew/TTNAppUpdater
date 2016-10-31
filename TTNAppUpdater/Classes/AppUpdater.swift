//
//  ViewController.swift
//  TTNAppUpdater
//
//  Created by Ajay Sharma on 10/19/2016.
//  Copyright (c) 2016 Ajay Sharma. All rights reserved.
//

import UIKit

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}



// MARK: - AppUpdaterDelegate Protocol

public protocol AppUpdaterDelegate: class {
    func appUpdaterDidShowUpdateDialog(_ alertType: AppUpdaterAlertType)   // User presented with update dialog
    func appUpdaterUserDidLaunchAppStore()                          // User did click on button that launched App Store.app
    func appUpdaterUserDidSkipVersion()                             // User did click on button that skips version update
    func appUpdaterUserDidCancel()                                  // User did click on button that cancels update dialog
    func appUpdaterDidFailVersionCheck(_ error: NSError)              // Appupdater failed to perform version check (may return system-level error)
    func appUpdaterDidDetectNewVersionWithoutAlert(_ message: String) // Appupdater performed version check and did not display alert
    func appUpdaterDidCompleteVersionCheckWithConfigData (_ message : NSDictionary) // Appupdater performed version check and pass data of Config API
}


/**
    Determines the type of alert to present after a successful version check has been performed.
    
    There are four options:

    - .Force: Forces user to update your app (1 button alert)
    - .Option: (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    - .Skip: Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    - .None: Doesn't show the alert, but instead returns a localized message for use in a custom UI within the appUpdaterDidDetectNewVersionWithoutAlert() delegate method

*/
public enum AppUpdaterAlertType {
    case force        // Forces user to update your app (1 button alert)
    case option       // (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    case skip         // Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    case none         // Doesn't show the alert, but instead returns a localized message for use in a custom UI within the appUpdaterDidDetectNewVersionWithoutAlert() delegate method
}

/**
    Determines the frequency in which the the version check is performed
    
    - .Immediately: Version check performed every time the app is launched
    - .Daily: Version check performedonce a day
    - .Weekly: Version check performed once a week

*/
public enum AppUpdaterVersionCheckType: Int {
    case immediately = 0    // Version check performed every time the app is launched
    case daily = 1          // Version check performed once a day
    case weekly = 7         // Version check performed once a week
}

/**
    Determines the available languages in which the update message and alert button titles should appear.
    
    By default, the operating system's default lanuage setting is used. However, you can force a specific language
    by setting the forceLanguageLocalization property before calling checkVersion()

*/
public enum AppUpdaterLanguageType: String {
    case Arabic = "ar"
    case Armenian = "hy"
    case Basque = "eu"
    case ChineseSimplified = "zh-Hans"
    case ChineseTraditional = "zh-Hant"
    case Croatian = "hr"
    case Danish = "da"
    case Dutch = "nl"
    case English = "en"
    case Estonian = "et"
    case French = "fr"
    case Hebrew = "he"
    case Hungarian = "hu"
    case German = "de"
    case Italian = "it"
    case Japanese = "ja"
    case Korean = "ko"
    case Latvian = "lv"
    case Lithuanian = "lt"
    case Malay = "ms"
    case Polish = "pl"
    case PortugueseBrazil = "pt"
    case PortuguesePortugal = "pt-PT"
    case Russian = "ru"
    case Slovenian = "sl"
    case Spanish = "es"
    case Swedish = "sv"
    case Thai = "th"
    case Turkish = "tr"
}

/**
 AppUpdater-specific Error Codes
 */
private enum AppUpdaterErrorCode: Int {
    case malformedURL = 1000
    case recentlyCheckedAlready
    case noUpdateAvailable
    case appStoreDataRetrievalFailure
    case appStoreJSONParsingFailure
    case appStoreOSVersionNumberFailure
    case appStoreOSVersionUnsupported
    case appStoreVersionNumberFailure
    case appStoreVersionArrayFailure
    case appStoreAppIDFailure
}

/**
 AppUpdater-specific Error Throwable Errors
 */
private enum AppUpdaterErrorType: Error {
    case malformedURL
    case missingBundleIdOrAppId
}

/** 
    AppUpdater-specific NSUserDefault Keys
*/
private enum AppUpdaterUserDefaults: String {
    case StoredVersionCheckDate     // NSUserDefault key that stores the timestamp of the last version check
    case StoredSkippedVersion       // NSUserDefault key that stores the version that a user decided to skip
}


// MARK: - AppUpdater

/**
    The AppUpdater Class.
    
    A singleton that is initialized using the sharedInstance() method.
*/
public final class AppUpdater: NSObject ,SwiftAlertViewDelegate{

    /**
        Current installed version of your app
     */
    fileprivate var currentInstalledVersion: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }()

    /**
        The error domain for all errors created by AppUpdater
     */
    public let AppUpdaterErrorDomain = "AppUpdater Error Domain"

    /**
        The AppUpdaterDelegate variable, which should be set if you'd like to be notified:
    
            - When a user views or interacts with the alert
                - appUpdaterDidShowUpdateDialog(alertType: appUpdaterAlertType)
                - appUpdaterUserDidLaunchAppStore()
                - appUpdaterUserDidSkipVersion()
                - appUpdaterUserDidCancel()
            - When a new version has been detected, and you would like to present a localized message in a custom UI
                - appUpdaterDidDetectNewVersionWithoutAlert(message: String)
    
    */
    public weak var delegate: AppUpdaterDelegate?

    /**
        The debug flag, which is disabled by default.
    
        When enabled, a stream of println() statements are logged to your console when a version check is performed.
    */
    public lazy var debugEnabled = false

    /**
        Determines the type of alert that should be shown.
    
        See the AppUpdaterAlertType enum for full details.
    */
    public var alertType = AppUpdaterAlertType.option
        {
        didSet {
            majorUpdateAlertType = alertType
            minorUpdateAlertType = alertType
            patchUpdateAlertType = alertType
            revisionUpdateAlertType = alertType
        }
    }
    
    /**
    Determines the type of alert that should be shown for major version updates: A.b.c
    
    Defaults to AppUpdaterAlertType.Option.
    
    See the AppUpdaterAlertType enum for full details.
    */
    public lazy var majorUpdateAlertType = AppUpdaterAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor version updates: a.B.c
    
    Defaults to AppUpdaterAlertType.Option.
    
    See the AppUpdaterAlertType enum for full details.
    */
    public lazy var minorUpdateAlertType  = AppUpdaterAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor patch updates: a.b.C
    
    Defaults to AppUpdaterAlertType.Option.
    
    See the AppUpdaterAlertType enum for full details.
    */
    public lazy var patchUpdateAlertType = AppUpdaterAlertType.option
    
    /**
    Determines the type of alert that should be shown for revision updates: a.b.c.D
    
    Defaults to AppUpdaterAlertType.Option.
    
    See the AppUpdaterAlertType enum for full details.
    */
    public lazy var revisionUpdateAlertType = AppUpdaterAlertType.option

    // Optional Vars
    /**
        The name of your app. 
    
        By default, it's set to the name of the app that's stored in your plist.
    */
    public lazy var appName: String = (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ""
    
    /**
        The region or country of an App Store in which your app is available.
        
        By default, all version checks are performed against the US App Store.
        If your app is not available in the US App Store, you should set it to the identifier 
        of at least one App Store within which it is available.
    */
    public var countryCode: String?
    
    /**
        Overrides the default localization of a user's device when presenting the update message and button titles in the alert.
    
        See the AppUpdaterLanguageType enum for more details.
    */
    public var forceLanguageLocalization: AppUpdaterLanguageType?
    
    /**
        Overrides the tint color for UIAlertController.
    */
    public var alertControllerTintColor: UIColor?

//    /**
//     The current version of your app that is available for download on the App Store
//     */
    public fileprivate(set) var currentAppStoreVersion: String?

    // Private
    fileprivate var appID: Int?
    fileprivate var lastVersionCheckPerformedOnDate: Date?
    fileprivate var updaterWindow: UIWindow?

    // Initialization
    public static let sharedInstance = AppUpdater()
    
    /**
     Get all the HTTP Request Headers in Dictionary
     Iterate & Set Header in URLRequest
     */
    public var headerDictionary = [String: String]()
    

    override init() {
        lastVersionCheckPerformedOnDate = UserDefaults.standard.object(forKey: AppUpdaterUserDefaults.StoredVersionCheckDate.rawValue) as? Date
    }

    /**
        Checks the currently installed version of your app against the App Store.
        The default check is against the US App Store, but if your app is not listed in the US,
        you should set the `countryCode` property before calling this method. Please refer to the countryCode property for more information.
    
        - parameter checkType: The frequency in days in which you want a check to be performed. Please refer to the AppUpdaterVersionCheckType enum for more details.
    */
    public func checkVersion(_ checkType: AppUpdaterVersionCheckType) {

        guard let _ = Bundle.bundleID() else {
            printMessage("Please make sure that you have set a `Bundle Identifier` in your project.")
            return
        }

        guard let _ = Bundle.httpProtocol() else {
            printMessage("Please make sure that you have set a `Protocol` in your project plist.")
            return
        }

        guard let _ = Bundle.baseURL() else {
            printMessage("Please make sure that you have set a `BASEURL` in your project plist.")
            return
        }

        guard let _ = Bundle.configURLPath() else {
            printMessage("Please make sure that you have set a `configPath` in your project plist.")
            return
        }

        
        if checkType == .immediately {
            performVersionCheck()
        }
    }

    fileprivate func performVersionCheck() {
        
        // Create Request
        do {

            let url = try iTunesURLFromString()
            let request = MutableURLRequest(url: url)

            // Iterate through the dictionary, create
            for (key,value) in headerDictionary {
                request.addValue(value, forHTTPHeaderField: key)
            }
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // POST
            request.httpMethod = "POST"
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)

            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) in
                
                // check for fundamental networking error
                guard let data = data, error == nil else {
                    print("error=\(error)")
                    return
                }
                
                // check for http errors
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(response)")
                    
                    self.postError(.appStoreJSONParsingFailure, underlyingError: nil)
                    return
                }
                
                // Convert JSON data to Swift Dictionary of type [String: AnyObject]
                do {
                    
                    let jsonData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    
                    let appData = jsonData as? [String: AnyObject]
                    
                    DispatchQueue.main.async {
                        
                        // Print results from appData
                        self.printMessage("JSON results: \(appData)")
                        
                        // Process Results (e.g., extract ForceUpgrade & Recommended version that is available in the API Response)
                        self.processVersionCheckResults(appData!)
                        
                    }
                    
                } catch let error as NSError {
                    self.postError(.appStoreDataRetrievalFailure, underlyingError: error)
                }
          
            });
            
            // do whatever you need with the task e.g. run
            task.resume()
        }
        catch let error as NSError {
            postError(.malformedURL, underlyingError: error)
        }

    }
    
    fileprivate func processVersionCheckResults(_ lookupResults: [String: AnyObject]) {
        
        // Store version comparison date
        guard let image = lookupResults["status"]!["code"] as? Int else {
            return self.postError(.appStoreOSVersionNumberFailure, underlyingError: nil)
        }

        let lookupResultsDic = lookupResults["data"] as! NSDictionary
        
        
        let iOSDataDic = (((lookupResultsDic["app"] as? NSDictionary)?.value(forKey: "appUpgrade") as? NSDictionary)?.value(forKey: "iOS") as? NSDictionary)
        
        if iOSDataDic != nil  {

            let forceUpgradeVersion = iOSDataDic?["forceUpgradeVersion"]
            let recommededVersion = iOSDataDic?["recommendedVersion"]
            
            // Check for Key in response & show alert
            if let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = forceUpgradeVersion
                , (currentInstalledVersion.compare(currentAppStoreVersion as! String, options: .numeric) == .orderedAscending) {
                print("Force Upgrade Available")
                alertType = .force
            }
            else if let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = recommededVersion
                , (currentInstalledVersion.compare(currentAppStoreVersion as! String, options: .numeric) == .orderedAscending) {
                print("Recommended Upgrade Available")
                alertType = .skip
            }
            else {
                alertType = .none
                postError(.noUpdateAvailable, underlyingError: nil)
                return
            }
            showAlert()
            
        }
    }
}


// MARK: - Alert Helpers

private extension AppUpdater {

    func showAlertIfCurrentAppStoreVersionNotSkipped() {
        alertType = setAlertType()
        
        guard let previouslySkippedVersion = UserDefaults.standard.object(forKey: AppUpdaterUserDefaults.StoredSkippedVersion.rawValue) as? String else {
            showAlert()
            return
        }
        
        if let currentAppStoreVersion = currentAppStoreVersion
            , currentAppStoreVersion != previouslySkippedVersion {
                showAlert()
        }
    }
    
    
    func showAlert() {
        let updateAvailableMessage = "Update Available"
        
        var alertController = UIAlertController()

        if let alertControllerTintColor = alertControllerTintColor {
            alertController.view.tintColor = UIColor.black
        }
        
        switch alertType {
            case .force:
                let alertView = SwiftAlertView(title: "Lorem ipsum ", message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "OK")
                
                alertView.backgroundColor = UIColor ( red: 0.9852, green: 0.9827, blue: 0.92, alpha: 1.0 )
                
                alertView.titleLabel.textColor = UIColor ( red: 0.0, green: 0.7253, blue: 0.6017, alpha: 1.0 )
                alertView.messageLabel.textColor = UIColor.orange
                alertView.titleLabel.font = UIFont(name: "Marker Felt", size: 30)
                alertView.messageLabel.font = UIFont(name: "Marker Felt", size: 20)
                alertView.buttonAtIndex(0)?.setTitleColor(UIColor.purple, for: UIControlState())
                alertView.buttonAtIndex(1)?.setTitleColor(UIColor.purple, for: UIControlState())
                alertView.buttonAtIndex(0)?.titleLabel?.font = UIFont(name: "Marker Felt", size: 20)
                alertView.buttonAtIndex(1)?.titleLabel?.font = UIFont(name: "Marker Felt", size: 20)
                
                alertView.show()
            
            case .skip:
                alertController = UIAlertController(title: updateAvailableMessage, message: "A new version of this app is available. Please update", preferredStyle: .alert)
                alertController.addAction(updateAlertAction())
                alertController.addAction(skipAlertAction())
                delegate?.appUpdaterDidCompleteVersionCheckWithConfigData([:])
            case .option:
                // TODO: - Localization Helpers
                break
            case .none:
                delegate?.appUpdaterDidDetectNewVersionWithoutAlert("No Update available")
            }
        
        if alertType != .none {
            alertController.show()
            delegate?.appUpdaterDidShowUpdateDialog(alertType)
        }
    }
    
    func updateAlertAction() -> UIAlertAction {
        let title = "Update"
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) in
            self.hideWindow()
            self.launchAppStore()
            self.delegate?.appUpdaterUserDidLaunchAppStore()
            return
        }
        
        return action
    }
    
    func skipAlertAction() -> UIAlertAction {
        let title = "Skip"
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) in
            self.hideWindow()
            self.delegate?.appUpdaterUserDidSkipVersion()
            return
        }
        
        return action
    }
}


// MARK: - Localization Helpers

extension AppUpdater {

    func localizedNewVersionMessage() -> String {

        let newVersionMessageToLocalize = "A new version of %@ is available. Please update to version %@ now."
        let newVersionMessage = Bundle().localizedString(newVersionMessageToLocalize, forceLanguageLocalization: forceLanguageLocalization)

        guard let currentAppStoreVersion = currentAppStoreVersion else {
            return String(format: newVersionMessage, appName, "Unknown")
        }

        return String(format: newVersionMessage, appName, currentAppStoreVersion)
    }

    func localizedUpdateButtonTitle() -> String {
        return Bundle().localizedString("Update", forceLanguageLocalization: forceLanguageLocalization)
    }

    func localizedSkipButtonTitle() -> String {
        return Bundle().localizedString("Skip this version", forceLanguageLocalization: forceLanguageLocalization)
    }
}


// MARK: - Misc. Helpers

private extension AppUpdater {

    func iTunesURLFromString() throws -> URL {

        var components = URLComponents()
        components.scheme = Bundle.httpProtocol()
        components.host = Bundle.baseURL()
        components.path = Bundle.configURLPath()!
        
        guard let url = components.url , !url.absoluteString.isEmpty else {
            throw AppUpdaterErrorType.malformedURL
        }
//        print("Force Upgrade URL : %@",url)
        
        return url
    }

    func daysSinceLastVersionCheckDate(_ lastVersionCheckPerformedOnDate: Date) -> Int {
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.day, from: lastVersionCheckPerformedOnDate, to: Date(), options: [])
        return components.day!
    }

    func isUpdateCompatibleWithDeviceOS(_ appData: [String: AnyObject]) -> Bool {

        guard let results = appData["status"] as? [[String: AnyObject]],
            let requiredOSVersion = results.first?["minimumOsVersion"] as? String else {
                postError(.appStoreOSVersionNumberFailure, underlyingError: nil)
            return false
        }

        let systemVersion = UIDevice.current.systemVersion

        if systemVersion.compare(requiredOSVersion, options: .numeric) == .orderedDescending ||
            systemVersion.compare(requiredOSVersion, options: .numeric) == .orderedSame {
            return true
        } else {
            postError(.appStoreOSVersionUnsupported, underlyingError: nil)
            return false
        }

    }

    func isAppStoreVersionNewer() -> Bool {

        var newVersionExists = false

        if let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = currentAppStoreVersion
            , (currentInstalledVersion.compare(currentAppStoreVersion, options: .numeric) == .orderedAscending) {

            newVersionExists = true
        }

        return newVersionExists
    }

    func storeVersionCheckDate() {
        lastVersionCheckPerformedOnDate = Date()
        if let lastVersionCheckPerformedOnDate = lastVersionCheckPerformedOnDate {
            UserDefaults.standard.set(lastVersionCheckPerformedOnDate, forKey: AppUpdaterUserDefaults.StoredVersionCheckDate.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    func setAlertType() -> AppUpdaterAlertType {

        guard let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = currentAppStoreVersion else {
            return .option
        }

        let oldVersion = (currentInstalledVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        let newVersion = (currentAppStoreVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}

        if newVersion.first! > oldVersion.first! { // A.b.c.d
            alertType = majorUpdateAlertType
        } else if newVersion.count > 1 && (oldVersion.count <= 1 || newVersion[1] > oldVersion[1]) { // a.B.c.d
            alertType = minorUpdateAlertType
        } else if newVersion.count > 2 && (oldVersion.count <= 2 || newVersion[2] > oldVersion[2]) { // a.b.C.d
            alertType = patchUpdateAlertType
        } else if newVersion.count > 3 && (oldVersion.count <= 3 || newVersion[3] > oldVersion[3]) { // a.b.c.D
            alertType = revisionUpdateAlertType
        }

        return alertType
    }

    func hideWindow() {
        if let updaterWindow = updaterWindow {
            updaterWindow.isHidden = true
            self.updaterWindow = nil
        }
    }

    func launchAppStore() {
        
        appID = Bundle.appstoreID()
        guard let appID = appID else {
            return
        }

        let iTunesString =  "https://itunes.apple.com/app/id\(appID)"
        let iTunesURL = URL(string: iTunesString)
        UIApplication.shared.openURL(iTunesURL!)

    }

    func printMessage(_ message: String) {
        if debugEnabled {
            print("[AppUpdater] \(message)")
        }
    }

}


// MARK: - UIAlertController Extensions

private extension UIAlertController {

    func show() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.windowLevel = UIWindowLevelAlert + 1
        
        AppUpdater.sharedInstance.updaterWindow = window
        
        window.makeKeyAndVisible()
        window.rootViewController!.present(self, animated: true, completion: nil)
    }

}


// MARK: - NSBundle Extension

private extension Bundle {

    class func bundleID() -> String? {
        return Bundle.main.bundleIdentifier
    }
   
    class func httpProtocol() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "Protocol") as? String
    }
    
    class func baseURL() -> String? {
           return Bundle.main.object(forInfoDictionaryKey: "BaseUrl") as? String
    }
    
    class func appstoreID() -> Int? {
        return Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? Int
    }

    
    class func configURLPath() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "ConfigUrlPath") as? String
    }

    

    func appUpdaterBundlePath() -> String {
        return Bundle(for: AppUpdater.self).path(forResource: "Siren", ofType: "bundle") as String!
    }

    func appUpdaterForcedBundlePath(_ forceLanguageLocalization: AppUpdaterLanguageType) -> String {
        let path = appUpdaterBundlePath()
        let name = forceLanguageLocalization.rawValue
        return Bundle(path: path)!.path(forResource: name, ofType: "lproj")!
    }

    func localizedString(_ stringKey: String, forceLanguageLocalization: AppUpdaterLanguageType?) -> String {
        var path: String
        let table = "SirenLocalizable"
        if let forceLanguageLocalization = forceLanguageLocalization {
            path = appUpdaterForcedBundlePath(forceLanguageLocalization)
        } else {
            path = appUpdaterBundlePath()
        }
        
        return Bundle(path: path)!.localizedString(forKey: stringKey, value: stringKey, table: table)
    }

}


// MARK: - Error Handling

private extension AppUpdater {

    func postError(_ code: AppUpdaterErrorCode, underlyingError: NSError?) {

        let description: String

        switch code {
        case .malformedURL:
            description = "The iTunes URL is malformed. Please leave an issue on http://github.com/ArtSabintsev/AppUpdater with as many details as possible."
        case .recentlyCheckedAlready:
            description = "Not checking the version, because it already checked recently."
        case .noUpdateAvailable:
            description = "No new update available."
        case .appStoreDataRetrievalFailure:
            description = "Error retrieving App Store data as an error was returned."
        case .appStoreJSONParsingFailure:
            description = "Error parsing App Store JSON data."
        case .appStoreOSVersionNumberFailure:
            description = "Error retrieving iOS version number as there was no data returned."
        case .appStoreOSVersionUnsupported:
            description = "The version of iOS on the device is lower than that of the one required by the app verison update."
        case .appStoreVersionNumberFailure:
            description = "Error retrieving App Store version number as there was no data returned."
        case .appStoreVersionArrayFailure:
            description = "Error retrieving App Store verson number as results.first does not contain a 'version' key."
        case .appStoreAppIDFailure:
            description = "Error retrieving trackId as results.first does not contain a 'trackId' key."
        }

        var userInfo: [String: AnyObject] = [NSLocalizedDescriptionKey: description as AnyObject]
        
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }

        let error = NSError(domain: AppUpdaterErrorDomain, code: code.rawValue, userInfo: userInfo)

        delegate?.appUpdaterDidFailVersionCheck(error)

        printMessage(error.localizedDescription)
    }

}


// MARK: - AppUpdaterDelegate

public extension AppUpdaterDelegate {

    func appUpdaterDidShowUpdateDialog(_ alertType: AppUpdaterAlertType) {}
    func appUpdaterUserDidLaunchAppStore() {}
    func appUpdaterUserDidSkipVersion() {}
    func appUpdaterUserDidCancel() {}
    func appUpdaterDidFailVersionCheck(_ error: NSError) {}
    func appUpdaterDidDetectNewVersionWithoutAlert(_ message: String) {}
    func appUpdaterDidCompleteVersionCheckWithConfigData(_ message: NSDictionary) {}

}


// MARK: - Testing Helpers 

extension AppUpdater {

    func testSetCurrentInstalledVersion(_ version: String) {
        currentInstalledVersion = version
    }

    func testSetAppStoreVersion(_ version: String) {
        currentAppStoreVersion = version
    }

    func testIsAppStoreVersionNewer() -> Bool {
        return isAppStoreVersionNewer()
    }
    
}

extension Bundle {

    func testLocalizedString(_ stringKey: String, forceLanguageLocalization: AppUpdaterLanguageType?) -> String {
        return Bundle().localizedString(stringKey, forceLanguageLocalization: forceLanguageLocalization)
    }

}
