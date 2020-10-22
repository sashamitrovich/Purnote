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

    func testExample() throws {
        let index: Index = Index()
        var data: [TestNote]=[]
        data.append(TestNote(path: "/trips/france.txt", content: "Hello World"))
        data.append(TestNote(path: "/meetings/france.txt", content: "Hello my beatiful"))
        
        
        
        for item in data {
            let tokens = item.content.components(separatedBy: " ")
            for token in tokens {
                index.addTerm(term: token, path: item.path)
            }
            
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

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
