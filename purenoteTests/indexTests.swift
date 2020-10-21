//
//  purenoteTests.swift
//  purenoteTests
//
//  Created by Saša Mitrović on 20.10.20.
//
@testable import purenote
import XCTest

class indexTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAdd() throws {
        let index: SearchIndex = SearchIndex()
        var data: [TestNote]=[]
        data.append(TestNote(path: "/trips/france.txt", content: "Hello World"))
        data.append(TestNote(path: "/meetings/france.txt", content: "Hello my beatiful"))
        
        
        
        for item in data {
            index.indexContent(content: item.content, path: item.path)
        }
        
//        print ("should be indexed now")
        XCTAssertTrue(index.dict.count == 4)
        let HelloHash = "Hello".hash
        XCTAssertTrue( (index.dict[HelloHash]!).count  == 2 )
        
        let WorldHash = "World".hash
        XCTAssertTrue( (index.dict[WorldHash]!).count  == 1 )
        
        let AppleHash = "Apple".hash
        XCTAssertFalse( index.dict.keys.contains(AppleHash) )
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testIndex() throws {
        let index: SearchIndex = SearchIndex()
        let data = DataManager()
        
        index.indexFolder(currentUrl: data.getRootPath())
        
        print("indexing should be done here")
        
        let WorldHash = "World".lowercased().hash
        XCTAssertTrue( index.dict.keys.contains(WorldHash))
        
        let BeautifulHash = "Beautiful".lowercased().hash
        XCTAssertTrue( (index.dict[BeautifulHash]!).count  == 3 )
    }
    
    func testSearchPhrase() throws {
        let phrase = "beautiful day"
        
        let index: SearchIndex = SearchIndex()
        let data = DataManager()
        
        index.indexFolder(currentUrl: data.getRootPath())
        
        _ = index.searchPhrase(phrase: phrase)
        
        print("did it find anything?")
    }
        
    func testSearchWord() throws {
        let word = "Beautiful"
        
        let index: SearchIndex = SearchIndex()
        let data = DataManager()
        
        index.indexFolder(currentUrl: data.getRootPath())
        
        let paths = index.searchWord(word: word)
        
        XCTAssertTrue(paths.count == 3)
        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
