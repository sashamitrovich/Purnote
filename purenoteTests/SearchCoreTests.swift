//
//  SearchCoreTests.swift
//  purenoteTests
//
//  The pure matching core: folding, AND-of-prefixes, ranking, scope, snippets,
//  and the incremental upsert/remove/rename on the in-memory index data. No
//  file I/O here.
//
@testable import Purnote
import XCTest

final class SearchCoreTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func day(_ n: Int) -> Date { t0.addingTimeInterval(Double(n) * 86_400) }

    private func data(_ notes: [(String, String, Int)]) -> SearchData {
        var d = SearchData()
        for (path, content, n) in notes { d.upsert(path: path, content: content, date: day(n)) }
        return d
    }
    private func paths(_ hits: [SearchHit]) -> [String] { hits.map(\.path) }

    // MARK: folding and tokens

    func testFoldIgnoresCaseAndDiacritics() {
        XCTAssertEqual(SearchText.fold("Café"), "cafe")
        XCTAssertEqual(SearchText.fold("CAFÉ"), "cafe")
        XCTAssertEqual(SearchText.fold("Zürich"), "zurich")
    }

    func testTokensAreFoldedAndSplitOnPunctuation() {
        XCTAssertEqual(SearchText.tokens("Hello, Wörld-wide!  Ok"), ["hello", "world", "wide", "ok"])
        XCTAssertEqual(SearchText.tokens("  !!! "), [])
    }

    func testCafeFindsCafeWithAccent() {
        let d = data([("/n/a.md", "Trip\nA Café au lait in Lisbon", 1)])
        XCTAssertEqual(paths(d.search(query: "cafe")), ["/n/a.md"])
        XCTAssertEqual(paths(d.search(query: "CAFÉ")), ["/n/a.md"])
        XCTAssertEqual(paths(d.search(query: "caf")), ["/n/a.md"])
    }

    func testAccentedQueryFindsPlainText() {
        let d = data([("/n/a.md", "Trip\nCafe in Lisbon", 1)])
        XCTAssertEqual(paths(d.search(query: "café")), ["/n/a.md"])
    }

    // MARK: AND of word prefixes

    func testEveryQueryWordMustMatchAWordPrefix() {
        let d = data([
            ("/n/a.md", "Weeknight pasta", 1),
            ("/n/b.md", "Pasta bake", 2),
        ])
        XCTAssertEqual(paths(d.search(query: "week pasta")), ["/n/a.md"])
        XCTAssertEqual(Set(paths(d.search(query: "pasta"))), ["/n/a.md", "/n/b.md"])
        // in any order
        XCTAssertEqual(paths(d.search(query: "pasta week")), ["/n/a.md"])
    }

    func testMatchesWordStartsNotMiddles() {
        let d = data([("/n/a.md", "Weeknight pasta", 1)])
        XCTAssertTrue(d.search(query: "ast").isEmpty, "'ast' is inside 'pasta', not the start of a word")
        XCTAssertEqual(paths(d.search(query: "pas")), ["/n/a.md"])
    }

    func testWordsMayBeInDifferentLines() {
        let d = data([("/n/a.md", "Plans\nbuy milk\nsecond line has bread", 1)])
        XCTAssertEqual(paths(d.search(query: "milk bread")), ["/n/a.md"])
    }

    func testEmptyAndPunctuationQueriesMatchNothing() {
        let d = data([("/n/a.md", "something", 1)])
        XCTAssertTrue(d.search(query: "").isEmpty)
        XCTAssertTrue(d.search(query: "   ").isEmpty)
        XCTAssertTrue(d.search(query: "!!!").isEmpty)
    }

    func testTrailingSpaceDoesNotChangeResults() {
        let d = data([("/n/a.md", "pasta", 1)])
        XCTAssertEqual(paths(d.search(query: "pasta ")), ["/n/a.md"])
    }

    // MARK: ranking

    func testTitleMatchBeatsBodyMatchEvenWhenBodyIsNewer() {
        let d = data([
            ("/n/body-newer.md", "Shopping\nremember the lemon", 9),
            ("/n/title-older.md", "Lemon tart\nbutter and sugar", 1),
        ])
        let hits = d.search(query: "lemon")
        XCTAssertEqual(paths(hits), ["/n/title-older.md", "/n/body-newer.md"])
        XCTAssertEqual(hits.map(\.tier), [.titlePrefix, .body])
    }

    func testWholeTitlePrefixBeatsOtherTitleMatches() {
        let d = data([
            ("/n/mid.md", "Tart with lemon\nx", 9),
            ("/n/prefix.md", "Lemon curd\nx", 1),
        ])
        let hits = d.search(query: "lemon")
        XCTAssertEqual(paths(hits), ["/n/prefix.md", "/n/mid.md"])
        XCTAssertEqual(hits.map(\.tier), [.titlePrefix, .title])
    }

    func testMultiWordWholeTitlePrefix() {
        let d = data([
            ("/n/a.md", "Weeknight pasta bake\nx", 1),
            ("/n/b.md", "Bake the pasta weeknight\nx", 2),
        ])
        let hits = d.search(query: "weeknight pas")
        XCTAssertEqual(paths(hits), ["/n/a.md", "/n/b.md"])
        XCTAssertEqual(hits.map(\.tier), [.titlePrefix, .title])
    }

    func testTitleIsTheFirstLineWithMarkdownStripped() {
        let d = data([("/n/a.md", "\n\n## **Lemon** curd\nbody", 1)])
        XCTAssertEqual(d.search(query: "lemon").first?.tier, .titlePrefix)
    }

    func testTiesAreNewestFirst() {
        let d = data([
            ("/n/old.md", "Intro\nlemon", 1),
            ("/n/new.md", "Intro\nlemon", 5),
            ("/n/mid.md", "Intro\nlemon", 3),
        ])
        XCTAssertEqual(paths(d.search(query: "lemon")), ["/n/new.md", "/n/mid.md", "/n/old.md"])
    }

    func testTiesWithEqualDatesAreStable() {
        let d = data([("/n/b.md", "x\nlemon", 1), ("/n/a.md", "x\nlemon", 1)])
        XCTAssertEqual(paths(d.search(query: "lemon")), ["/n/a.md", "/n/b.md"])
    }

    // MARK: scope

    func testFolderScopeUsesWholePathComponents() {
        let d = data([
            ("/root/Travel/a.md", "x\nlemon", 1),
            ("/root/Travel/Italy/b.md", "x\nlemon", 2),
            ("/root/Travelogue/c.md", "x\nlemon", 3),
            ("/root/d.md", "x\nlemon", 4),
        ])
        XCTAssertEqual(Set(paths(d.search(query: "lemon", scope: .all))).count, 4)
        XCTAssertEqual(Set(paths(d.search(query: "lemon", scope: .folder("/root/Travel")))),
                       ["/root/Travel/a.md", "/root/Travel/Italy/b.md"])
        XCTAssertEqual(paths(d.search(query: "lemon", scope: .folder("/root/Travelogue"))),
                       ["/root/Travelogue/c.md"])
        XCTAssertEqual(paths(d.search(query: "lemon", scope: .folder("/root/Travel/"))).count, 2,
                       "a trailing slash on the folder must not change the scope")
    }

    func testScopeContains() {
        XCTAssertTrue(SearchScope.all.contains(path: "/anything"))
        XCTAssertTrue(SearchScope.folder("/a/b").contains(path: "/a/b/c.md"))
        XCTAssertFalse(SearchScope.folder("/a/b").contains(path: "/a/bc/c.md"))
        XCTAssertFalse(SearchScope.folder("/a/b").contains(path: "/a/b"))
    }

    // MARK: snippets

    func testSnippetIsTheFirstBodyLineWithAMatch() {
        let s = SearchText.snippet(in: "Title line\nnothing here\nthe lemon is here\nanother lemon", query: "lemon")
        XCTAssertEqual(s?.text, "the lemon is here")
        XCTAssertEqual(s.map { String($0.text[$0.matchRange]) }, "lemon")
    }

    func testSnippetStripsMarkdownMarkers() {
        XCTAssertEqual(SearchText.snippet(in: "T\n## Lemon heading", query: "lemon")?.text, "Lemon heading")
        XCTAssertEqual(SearchText.snippet(in: "T\nbuy **fresh lemon** today", query: "lemon")?.text, "buy fresh lemon today")
        XCTAssertEqual(SearchText.snippet(in: "T\n- [ ] squeeze the lemon", query: "lemon")?.text, "squeeze the lemon")
        XCTAssertEqual(SearchText.snippet(in: "T\n- [x] squeeze the lemon", query: "lemon")?.text, "squeeze the lemon")
        XCTAssertEqual(SearchText.snippet(in: "T\n- a lemon", query: "lemon")?.text, "a lemon")
    }

    func testSnippetRangeCoversTheMatchedWordAfterStripping() {
        let s = SearchText.snippet(in: "T\n- [ ] Squeeze the **Café** now", query: "cafe")
        XCTAssertEqual(s?.text, "Squeeze the Café now")
        XCTAssertEqual(s.map { String($0.text[$0.matchRange]) }, "Café")
    }

    func testSnippetRangeIsAWordPrefixNotAnInfix() {
        let s = SearchText.snippet(in: "T\nthe pasta and a pas de deux", query: "pas")
        XCTAssertEqual(s?.text, "the pasta and a pas de deux")
        // the first *word start* that matches is "pasta" (prefix "pas")
        XCTAssertEqual(s.map { String($0.text[$0.matchRange]) }, "pas")
        XCTAssertEqual(s.map { $0.text.distance(from: $0.text.startIndex, to: $0.matchRange.lowerBound) }, 4)
    }

    func testSnippetSkipsTheTitleLine() {
        // the match is only in the title: there is no matching body line
        XCTAssertNil(SearchText.snippet(in: "Lemon tart\nbutter\nsugar", query: "lemon"))
        // and a leading blank line does not make the first line the "body"
        XCTAssertNil(SearchText.snippet(in: "\n\nLemon tart\nbutter", query: "lemon"))
    }

    func testSnippetUsesAnyQueryWordAndFoldsAccents() {
        let s = SearchText.snippet(in: "T\nfirst\nsecond has the CAFÉ\nthird has milk", query: "milk cafe")
        XCTAssertEqual(s?.text, "second has the CAFÉ")
        XCTAssertEqual(s.map { String($0.text[$0.matchRange]) }, "CAFÉ")
    }

    func testSnippetNilForEmptyQuery() {
        XCTAssertNil(SearchText.snippet(in: "T\nlemon", query: "  "))
    }

    // MARK: incremental updates on the data

    func testUpsertReplacesTheNotesOldTerms() {
        var d = data([("/n/a.md", "Alpha\nold-word", 1)])
        XCTAssertEqual(paths(d.search(query: "old")), ["/n/a.md"])
        d.upsert(path: "/n/a.md", content: "Alpha\nnew-word", date: day(2))
        XCTAssertTrue(d.search(query: "old").isEmpty, "the previous version's terms must be gone")
        XCTAssertEqual(paths(d.search(query: "new")), ["/n/a.md"])
        XCTAssertNil(d.terms["old"], "a term no note has any more must not linger as an empty entry")
    }

    func testUpsertUpdatesTitleAndDate() {
        var d = data([("/n/a.md", "Alpha\nlemon", 1)])
        XCTAssertEqual(d.search(query: "alpha").first?.tier, .titlePrefix)
        d.upsert(path: "/n/a.md", content: "Beta\nalpha lemon", date: day(7))
        let hit = d.search(query: "alpha").first
        XCTAssertEqual(hit?.tier, .body)
        XCTAssertEqual(hit?.date, day(7))
    }

    func testRemove() {
        var d = data([("/n/a.md", "Alpha\n#tag one", 1), ("/n/b.md", "Beta\n#tag two", 1)])
        d.remove(path: "/n/a.md")
        XCTAssertTrue(d.search(query: "alpha").isEmpty)
        XCTAssertEqual(paths(d.search(query: "tag")), ["/n/b.md"])
        XCTAssertEqual(d.paths(taggedWithAll: ["tag"]), ["/n/b.md"])
        d.remove(path: "/n/missing.md") // no-op
        XCTAssertEqual(d.entries.count, 1)
    }

    func testRenameMovesAPathWithoutRereading() {
        var d = data([("/n/a.md", "Alpha\nlemon #tag", 1)])
        d.rename(from: "/n/a.md", to: "/n/Alpha.md")
        XCTAssertEqual(paths(d.search(query: "lemon")), ["/n/Alpha.md"])
        XCTAssertEqual(d.paths(taggedWithAll: ["tag"]), ["/n/Alpha.md"])
        XCTAssertNil(d.entries["/n/a.md"])
    }

    func testRenameOfAFolderMovesEveryNoteInside() {
        var d = data([
            ("/n/Old/a.md", "A\nlemon", 1),
            ("/n/Old/sub/b.md", "B\nlemon", 2),
            ("/n/Older/c.md", "C\nlemon", 3),
        ])
        d.rename(from: "/n/Old", to: "/n/New")
        XCTAssertEqual(Set(paths(d.search(query: "lemon"))),
                       ["/n/New/a.md", "/n/New/sub/b.md", "/n/Older/c.md"])
    }

    func testTagsAreIndexed() {
        let d = data([("/n/a.md", "Alpha\nsome #Plan here", 1)])
        XCTAssertEqual(d.paths(taggedWithAll: ["plan"]), ["/n/a.md"])
        XCTAssertEqual(d.paths(taggedWithAll: ["PLAN"]), ["/n/a.md"])
        XCTAssertTrue(d.paths(taggedWithAll: []).isEmpty)
        XCTAssertTrue(d.paths(taggedWithAll: ["plan", "other"]).isEmpty)
    }

    // MARK: what gets indexed

    func testHiddenFoldersAndAssetsFoldersAreSkipped() {
        XCTAssertFalse(SearchIndexer.shouldDescend(intoDirectoryNamed: ".Trash"))
        XCTAssertFalse(SearchIndexer.shouldDescend(intoDirectoryNamed: ".purnote"))
        XCTAssertFalse(SearchIndexer.shouldDescend(intoDirectoryNamed: "My Note.assets"))
        XCTAssertTrue(SearchIndexer.shouldDescend(intoDirectoryNamed: "Travel"))
        XCTAssertTrue(SearchIndexer.shouldDescend(intoDirectoryNamed: "assets")) // an ordinary folder name
    }

    func testOnlyVisibleMarkdownFilesAreIndexed() {
        XCTAssertTrue(SearchIndexer.isIndexableFile(named: "Note.md"))
        XCTAssertTrue(SearchIndexer.isIndexableFile(named: "Note.MD"))
        XCTAssertFalse(SearchIndexer.isIndexableFile(named: ".hidden.md"))
        XCTAssertFalse(SearchIndexer.isIndexableFile(named: ".Note.md.icloud"))
        XCTAssertFalse(SearchIndexer.isIndexableFile(named: "Note.md.icloud"))
        XCTAssertFalse(SearchIndexer.isIndexableFile(named: "photo.jpg"))
        XCTAssertFalse(SearchIndexer.isIndexableFile(named: "notes.mdx"))
    }

    func testIsIndexablePathLooksAtEveryComponentBelowTheRoot() {
        XCTAssertTrue(SearchIndexer.isIndexable(path: "/r/Travel/a.md", root: "/r"))
        XCTAssertFalse(SearchIndexer.isIndexable(path: "/r/.purnote/a.md", root: "/r"))
        XCTAssertFalse(SearchIndexer.isIndexable(path: "/r/.Trash/a.md", root: "/r"))
        XCTAssertFalse(SearchIndexer.isIndexable(path: "/r/A.assets/a.md", root: "/r"))
        XCTAssertFalse(SearchIndexer.isIndexable(path: "/r/Travel/photo.png", root: "/r"))
        // a hidden folder ABOVE the root (e.g. a temp dir) is not the library's business
        XCTAssertTrue(SearchIndexer.isIndexable(path: "/.x/r/a.md", root: "/.x/r"))
    }
}
