import WatchKit
import FlickTypeKit

// only here for flicktype set up
class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        FlickType.returnURL = URL(string: "https://apps.pixlwave.uk/flicktype/")
    }
    
    func handle(_ userActivity: NSUserActivity) {
        if FlickType.handle(userActivity) { return }
    }
}
