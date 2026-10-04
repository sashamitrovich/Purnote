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
    
    /// Term -> the paths of every note that contains it. Keyed by the term
    /// itself (not its hash) so we can match on a prefix: typing "mark" has to
    /// find "markdown", the way search-as-you-type is expected to work.
    public var dict: [String: Set<String>] = [:]

    public var idHash: [String : String] = [:]

    /// Tag (lowercased) -> the paths of every note that contains it.
    public var tagDict: [String: Set<String>] = [:]

    public func searchPhrase(phrase: String) -> Set<String> {
        let tokens = phrase.lowercased()
            .removePuncuation()
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        // an empty or all-punctuation query matches nothing rather than
        // everything -- and stops an empty token from wiping the intersection
        guard !tokens.isEmpty else { return [] }

        var urls: Set<String> = []
        for (index, token) in tokens.enumerated() {
            let searchResult = searchWord(word: token)
            if index == 0 {
                urls = searchResult
            } else {
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
    
    
    /// Every note that has a word *beginning with* `word`. Prefix rather than
    /// exact match, so a partial word entered while typing still finds notes.
    public func searchWord(word: String) -> Set<String> {
        let prefix = word.lowercased()
        guard !prefix.isEmpty else { return [] }

        var paths: Set<String> = []
        for (term, termPaths) in dict where term.hasPrefix(prefix) {
            paths.formUnion(termPaths)
        }
        return paths
    }

    /// Every tag present across the library, sorted.
    public func allTags() -> [String] {
        tagDict.keys.sorted()
    }

    /// The notes containing every one of the given tags.
    public func searchByTags(_ tags: [String]) -> [Note] {
        let lowered = tags.map { $0.lowercased() }
        guard !lowered.isEmpty else { return [] }

        var paths: Set<String> = []
        for (index, tag) in lowered.enumerated() {
            let hits = tagDict[tag] ?? []
            paths = index == 0 ? hits : paths.intersection(hits)
        }

        var notes: [Note] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            do {
                try notes.append(Note(content: CoordinatedFile.read(url),
                                      date: (FileManager.default.attributesOfItem(atPath: path)[.creationDate] as? Date) ?? Date(),
                                      path: url.lastPathComponent, isLocal: true, url: url, type: .Note))
            }
            catch {
                print("Unexpected error adding note to tag results: \(error).")
            }
        }
        notes.sort { $0.date > $1.date }
        return notes
    }

    func addTerm(term: String, path: String) {
        dict[term.lowercased(), default: []].insert(path)
    }
    

    
    public func indexContent(content: String, path: String) {

        // https://medium.com/@jacqschweiger/using-character-sets-in-swift-945b99ba17e
        let tokens = content.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(CharacterSet.whitespacesAndNewlines))
        
        for token in tokens {
            if token != "" {
                addTerm(term: token, path: path)
            }
            
        }

        // index the #tag tokens too, so notes can be filtered by tag
        for tag in TagScanner.tags(in: content) {
            tagDict[tag.lowercased(), default: []].insert(path)
        }
    }
    public func indexall() {
        dict = [:]
        tagDict = [:]
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
                    content =  try CoordinatedFile.read(url)
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
                try notes.append(Note(content: CoordinatedFile.read(url), date: (FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date(), path: url.lastPathComponent, isLocal: true, url: url, type: .Note))
            }
            catch {
                /* error handling here */
                print("Unexpected error adding note to search results: \(error).")
            }
        }
        
        notes.sort(by: { lhs, rhs in
            return lhs.date > rhs.date
        })
        return notes
        
    }
    
}
