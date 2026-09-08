import Foundation
import Testing

@testable import Turnstile

struct BrowserCollectionTests {
  @Test
  func keepsChromeAndItsProfilesDistinctThroughReorderingAndRemoval() throws {
    let chrome = makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
    let personal = chrome.withProfile(ChromeProfile(directory: "Default", name: "Personal"))
    let work = chrome.withProfile(ChromeProfile(directory: "Profile 1", name: "Work"))
    var collection = try BrowserCollection([chrome, personal])

    try collection.add(work)
    collection.move(id: work.id, direction: .towardStart)
    #expect(collection.elements == [chrome, work, personal])

    collection.remove(id: personal.id)
    #expect(collection.elements == [chrome, work])
  }

  @Test
  func rejectsTheSameProfileAfterItIsRenamed() throws {
    let chrome = makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
    let original = chrome.withProfile(ChromeProfile(directory: "Profile 1", name: "Work"))
    let renamed = chrome.withProfile(ChromeProfile(directory: "Profile 1", name: "Office"))
    var collection = try BrowserCollection([original])

    #expect(throws: BrowserCollectionError.duplicateBrowser(renamed.destinationName)) {
      try collection.add(renamed)
    }
  }

  @Test(arguments: [
    "", ".", "..", "../Default", "/tmp/profile", "a\\b", "bad\0name", "Guest Profile",
    "System Profile",
  ])
  func rejectsInvalidProfileDirectories(directory: String) throws {
    let chrome = makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
      .withProfile(ChromeProfile(directory: directory, name: "Work"))
    var collection = try BrowserCollection()

    #expect(throws: BrowserCollectionError.invalidBrowser) { try collection.add(chrome) }
    #expect(throws: BrowserCollectionError.invalidBrowser) { try BrowserCollection([chrome]) }
  }

  @Test
  func rejectsChromeProfilesAttachedToOtherBrowsers() {
    let safari = makeBrowser(name: "Safari")
      .withProfile(ChromeProfile(directory: "Default", name: "Personal"))

    #expect(throws: BrowserCollectionError.invalidBrowser) { try BrowserCollection([safari]) }
  }

  @Test
  func rejectsDuplicateBundleIdentifiersIgnoringCase() throws {
    let safari = makeBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
    let duplicate = makeBrowser(name: "Safari Copy", bundleIdentifier: "COM.APPLE.SAFARI")
    var collection = try BrowserCollection([safari])

    #expect(throws: BrowserCollectionError.duplicateBrowser("Safari Copy")) {
      try collection.add(duplicate)
    }
  }

  @Test
  func movesBrowsersOnePositionAtATime() throws {
    let safari = makeBrowser(name: "Safari")
    let firefox = makeBrowser(name: "Firefox")
    let chrome = makeBrowser(name: "Chrome")
    var collection = try BrowserCollection([safari, firefox, chrome])

    collection.move(id: firefox.id, direction: .towardStart)
    #expect(collection.elements == [firefox, safari, chrome])

    collection.move(id: firefox.id, direction: .towardStart)
    #expect(collection.elements == [firefox, safari, chrome])

    collection.move(id: safari.id, direction: .towardEnd)
    #expect(collection.elements == [firefox, chrome, safari])
  }

  @Test
  func movesMultipleDraggedRowsWithoutChangingTheirRelativeOrder() throws {
    let browsers = ["A", "B", "C", "D"].map { makeBrowser(name: $0) }
    var collection = try BrowserCollection(browsers)

    collection.move(fromOffsets: IndexSet([1, 3]), toOffset: 0)

    #expect(collection.elements == [browsers[1], browsers[3], browsers[0], browsers[2]])
  }

  @Test
  func reportsOnlyValidMoveDirections() throws {
    let safari = makeBrowser(name: "Safari")
    let firefox = makeBrowser(name: "Firefox")
    let collection = try BrowserCollection([safari, firefox])

    #expect(!collection.canMove(id: safari.id, direction: .towardStart))
    #expect(collection.canMove(id: safari.id, direction: .towardEnd))
    #expect(collection.canMove(id: firefox.id, direction: .towardStart))
    #expect(!collection.canMove(id: firefox.id, direction: .towardEnd))
  }
}
