@testable import Purnote
import XCTest

/// Splitting a note into blocks is what lets a tap on the rendered page find
/// its way back to a line in the file -- MarkdownUI itself keeps no source
/// positions. If the line ranges here drift, a tap ticks the wrong checkbox, so
/// these are pinned tightly.
final class MarkdownBlocksTests: XCTestCase {

    // MARK: - splitting

    func testSplitsOnBlankLines() {
        let blocks = MarkdownBlocks.split("# Title\n\nA paragraph.\n\nAnother one.")
        XCTAssertEqual(blocks.map(\.text), ["# Title", "A paragraph.", "Another one."])
        XCTAssertEqual(blocks.map(\.lines), [0..<1, 2..<3, 4..<5])
    }

    func testConsecutiveLinesStayInOneBlock() {
        let blocks = MarkdownBlocks.split("- one\n- two\n- three")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].lines, 0..<3)
    }

    func testRunsOfBlankLinesDoNotMakeEmptyBlocks() {
        let blocks = MarkdownBlocks.split("a\n\n\n\nb")
        XCTAssertEqual(blocks.map(\.text), ["a", "b"])
    }

    func testBlankLineInsideAFenceDoesNotSplitTheCodeBlock() {
        let source = "```swift\nlet a = 1\n\nlet b = 2\n```\n\nAfter."
        let blocks = MarkdownBlocks.split(source)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "```swift\nlet a = 1\n\nlet b = 2\n```")
        XCTAssertEqual(blocks[1].text, "After.")
    }

    func testOffsetPointsAtTheBlocksFirstCharacter() {
        let source = "# Title\n\nA paragraph.\n\nAnother one."
        let blocks = MarkdownBlocks.split(source)
        for block in blocks {
            let start = source.index(source.startIndex, offsetBy: block.offset)
            XCTAssertTrue(source[start...].hasPrefix(block.text),
                          "block \(block.id) offset \(block.offset) does not land on its own text")
        }
    }

    func testEmptySourceHasNoBlocks() {
        XCTAssertTrue(MarkdownBlocks.split("").isEmpty)
        XCTAssertTrue(MarkdownBlocks.split("\n\n\n").isEmpty)
    }

    // MARK: - task items

    func testRecognisesTaskItems() {
        let blocks = MarkdownBlocks.split("- [ ] milk\n- [x] bread")
        XCTAssertTrue(blocks[0].isTaskList)
        XCTAssertEqual(blocks[0].tasks.map(\.id), [0, 1])
        XCTAssertEqual(blocks[0].tasks.map(\.isCompleted), [false, true])
        XCTAssertEqual(blocks[0].tasks.map(\.content), ["milk", "bread"])
    }

    func testTaskItemIdIsTheLineInTheWholeSourceNotInTheBlock() {
        let blocks = MarkdownBlocks.split("# Shopping\n\nintro\n\n- [ ] milk\n- [ ] bread")
        let tasks = blocks.last!.tasks
        XCTAssertEqual(tasks.map(\.id), [4, 5])
    }

    func testIndentedTaskItemsKeepTheirIndentation() {
        let item = MarkdownBlocks.taskItem("    - [ ] nested", line: 0)
        XCTAssertEqual(item?.indent, "    ")
        XCTAssertEqual(item?.content, "nested")
    }

    func testCapitalXCountsAsCompleted() {
        XCTAssertEqual(MarkdownBlocks.taskItem("- [X] done", line: 0)?.isCompleted, true)
    }

    func testStarAndPlusBulletsAreTaskItemsToo() {
        XCTAssertNotNil(MarkdownBlocks.taskItem("* [ ] star", line: 0))
        XCTAssertNotNil(MarkdownBlocks.taskItem("+ [ ] plus", line: 0))
    }

    func testAPlainBulletIsNotATaskItem() {
        XCTAssertNil(MarkdownBlocks.taskItem("- just a bullet", line: 0))
        XCTAssertNil(MarkdownBlocks.taskItem("a paragraph mentioning - [ ] a box", line: 0))
    }

    func testAMixedListSplitsIntoACheckboxPartAndAPlainPart() {
        // the checkbox half stays tappable rather than the whole list going
        // inert because one line is an ordinary bullet
        let blocks = MarkdownBlocks.split("- [ ] milk\n- bread")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue(blocks[0].isTaskList)
        XCTAssertEqual(blocks[0].tasks.map(\.content), ["milk"])
        XCTAssertFalse(blocks[1].isTaskList)
        XCTAssertEqual(blocks[1].text, "- bread")
    }

    /// Markdown lets a list follow a heading with no blank line, and the sample
    /// notes do. The heading used to swallow the checklist and stop the boxes
    /// being tappable.
    func testAChecklistDirectlyUnderAHeadingIsStillAChecklist() {
        let blocks = MarkdownBlocks.split("## This week\n- [x] Mon\n- [ ] Fri")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "## This week")
        XCTAssertTrue(blocks[1].isTaskList)
        XCTAssertEqual(blocks[1].tasks.map(\.id), [1, 2])
        XCTAssertEqual(blocks[1].tasks.map(\.isCompleted), [true, false])
    }

    // MARK: - toggling

    func testToggleTicksAnUncheckedBox() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "- [ ] milk", line: 0), "- [x] milk")
    }

    func testToggleUnticksACheckedBox() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "- [x] milk", line: 0), "- [ ] milk")
    }

    func testToggleChangesOnlyTheTappedLine() {
        let source = "# List\n\n- [ ] milk\n- [ ] bread\n- [ ] jam"
        let out = MarkdownBlocks.toggleTask(in: source, line: 3)
        XCTAssertEqual(out, "# List\n\n- [ ] milk\n- [x] bread\n- [ ] jam")
    }

    func testTogglePreservesIndentationAndBulletCharacter() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "    * [ ] nested", line: 0),
                       "    * [x] nested")
    }

    func testToggleLeavesTrailingContentAlone() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "- [ ] buy **milk** today", line: 0),
                       "- [x] buy **milk** today")
    }

    func testTogglingANonTaskLineIsANoOp() {
        let source = "# Title\n\njust text"
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: source, line: 2), source)
    }

    func testTogglingOutOfRangeIsANoOp() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "- [ ] milk", line: 99), "- [ ] milk")
    }

    func testToggleTwiceReturnsTheOriginalBytes() {
        let source = "notes\n\n- [ ] a\n  - [x] b\n"
        let once = MarkdownBlocks.toggleTask(in: source, line: 2)
        let twice = MarkdownBlocks.toggleTask(in: once, line: 2)
        XCTAssertEqual(twice, source, "a note must round trip through a tap unchanged")
    }
}
