//
//  Index.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import Foundation


class SearchIndex : ObservableObject {
    var rootUrl: URL
    var notes: [Note]
    
    init(rootUrl: URL) {
        self.rootUrl = rootUrl
        notes = []
        indexall()
    }
    
    public var dict: [Int: Set<String>] = [:]
    
    public var idHash: [String : String] = [:]
    
    public func searchPhrase(phrase: String) -> Set<String> {
        let tokens = phrase.lowercased().removePuncuation().components(separatedBy: " ")
        var urls : Set<String> = []
                
        for (index,token) in tokens.enumerated() {
            let searchResult = searchWord(word: String(token))
            if index == 0 {
                urls = searchResult
            }
            else {
                urls = urls.intersection(searchResult)
            }
        }
        
        return urls
    }
    public func getSearchResultsAsUrls(phrase: String) -> [URL] {
        if phrase == "" {
            return []
        }
        let results = searchPhrase(phrase: phrase)
        var urls: [URL] = []
        for result in results
        {
            urls.append(URL(fileURLWithPath: result))
        }
        
        return urls
    }
    
    
    public func searchWord(word:String) -> Set<String> {
        var paths: Set<String> = []
        let wordHash = word.lowercased().hash
        
        if !(dict[wordHash] == nil) && !dict[wordHash]!.isEmpty {
            paths = dict[wordHash]!
        }
        
        return paths
        
    }
    
    func addTerm(term: String, path: String) {
        let termHash = term.lowercased().hash
        if !dict.keys.contains(termHash) {
            dict[termHash] = [path]
        }
        else {
            var idSet : Set<String> = dict[termHash]!
            idSet.insert(path)
            dict[termHash] = idSet
        }
    }
    

    
    public func indexContent(content: String, path: String) {

        // https://medium.com/@jacqschweiger/using-character-sets-in-swift-945b99ba17e
        let tokens = content.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(CharacterSet.whitespacesAndNewlines))
        

   
        
        for token in tokens {
            if token != "" {
                addTerm(term: token, path: path)
            }
            
        }
    }
    public func indexall() {
        indexFolder(currentUrl: rootUrl)
    }
    
    public func indexFolder(currentUrl: URL ) {
        var urls: [URL] = []
        
        do {
            try urls=FileManager.default.contentsOfDirectory(at: currentUrl, includingPropertiesForKeys:nil)
        }
        catch {
            // failed
            print("Error getting directory content while indexing: \(error).")
        }
        
        for url in urls {
            
            // it's not a directory or an icloud item, can index
            // it will index only .md files
            if !url.hasDirectoryPath && !url.absoluteString.contains(".icloud") && url.absoluteString.contains(".md"){
                
                var content = ""
                do {
                    content =  try String(contentsOf: url, encoding: String.Encoding.utf8)
                }
                catch {
                    /* error handling here */
                    print("Filed to get file content while indexing: \(error).")
                }
                
                // finally we can index
                indexContent(content: content, path: url.path)
            }
            
            else if url.hasDirectoryPath && url.lastPathComponent != ".Trash" {
                indexFolder(currentUrl: url)                
            }
            
        }
        
    }
    
    public func search(phrase: String) -> [Note] {
        var notes: [Note] = []
        let urls = getSearchResultsAsUrls(phrase: phrase)
        
        for url in urls {
            do {
                try notes.append(Note(content: String(contentsOf: url, encoding: String.Encoding.utf8), date: FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as! Date, path: url.lastPathComponent, isLocal: true, url: url, type: .Note))
            }
            catch {
                /* error handling here */
                print("Unexpected error adding note to search results: \(error).")
            }
        }
        
        return notes
        
    }
    
}
