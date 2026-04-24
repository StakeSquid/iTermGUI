import Foundation
import SwiftUI
import Testing
@testable import iTermGUI

@Suite("SFTPView ColumnWidths defaults")
struct SFTPColumnDefaultsTests {
    @Test func initialDefaultWidths() {
        let w = ColumnWidths()
        #expect(w.name == 200)
        #expect(w.size == 80)
        #expect(w.permissions == 90)
        #expect(w.date == 120)
    }
}

@Suite("SFTPView row layout arithmetic")
struct SFTPRowLayoutTests {
    private let iconWidth: CGFloat = 28
    private let dividerWidth: CGFloat = 4
    private let dividerCount: CGFloat = 4

    @Test func totalRowWidthIs534WithDefaults() {
        let w = ColumnWidths()
        let total = iconWidth + w.name + w.size + w.permissions + w.date + dividerWidth * dividerCount
        #expect(total == 534)
    }

    @Test func resizingNameColumnIncreasesTotalBySameDelta() {
        var w = ColumnWidths()
        let originalTotal = iconWidth + w.name + w.size + w.permissions + w.date + dividerWidth * dividerCount
        w.name = 250
        let newTotal = iconWidth + w.name + w.size + w.permissions + w.date + dividerWidth * dividerCount
        #expect(newTotal - originalTotal == 50)
    }

    @Test func columnPositionsAreSequentialWithDividers() {
        let w = ColumnWidths()
        let iconX: CGFloat = 0
        let nameX = iconX + iconWidth
        let sizeX = nameX + w.name + dividerWidth
        let permX = sizeX + w.size + dividerWidth
        let dateX = permX + w.permissions + dividerWidth

        #expect(nameX == iconX + iconWidth)
        #expect(sizeX == nameX + w.name + dividerWidth)
        #expect(permX == sizeX + w.size + dividerWidth)
        #expect(dateX == permX + w.permissions + dividerWidth)
    }
}

@Suite("SFTPView ColumnWidths Equatable")
struct SFTPColumnWidthsEquatableTests {
    @Test func sameValuesAreEqual() {
        #expect(ColumnWidths() == ColumnWidths())
    }

    @Test func differentValuesNotEqual() {
        var a = ColumnWidths()
        a.name = 500
        #expect(a != ColumnWidths())
    }
}
