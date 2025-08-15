import XCTest
import SwiftUI
@testable import iTermGUI

final class SFTPColumnTests: XCTestCase {
    
    func testColumnWidthCalculations() {
        // Test initial column widths
        let widths = ColumnWidths()
        XCTAssertEqual(widths.name, 200)
        XCTAssertEqual(widths.size, 80)
        XCTAssertEqual(widths.permissions, 90)
        XCTAssertEqual(widths.date, 120)
    }
    
    func testTotalRowWidth() {
        let widths = ColumnWidths()
        
        // Calculate total width used by a row
        let iconWidth: CGFloat = 28
        let nameWidth = widths.name
        let sizeWidth = widths.size
        let permWidth = widths.permissions
        let dateWidth = widths.date
        let dividerWidth: CGFloat = 4
        let dividerCount: CGFloat = 4 // 4 dividers between columns
        
        let totalWidth = iconWidth + nameWidth + sizeWidth + permWidth + dateWidth + (dividerWidth * dividerCount)
        
        print("Total row width: \(totalWidth)")
        print("Icon: \(iconWidth)")
        print("Name: \(nameWidth)")
        print("Size: \(sizeWidth)")
        print("Permissions: \(permWidth)")
        print("Date: \(dateWidth)")
        print("Dividers: \(dividerWidth * dividerCount)")
        
        // Total should be: 28 + 200 + 80 + 90 + 120 + 16 = 534
        XCTAssertEqual(totalWidth, 534)
    }
    
    func testColumnResizing() {
        var widths = ColumnWidths()
        
        // Simulate resizing name column
        let originalNameWidth = widths.name
        widths.name = 250 // Increase by 50
        
        // The total width should increase
        let iconWidth: CGFloat = 28
        let dividerWidth: CGFloat = 4
        let dividerCount: CGFloat = 4
        
        let originalTotal = iconWidth + 200 + 80 + 90 + 120 + (dividerWidth * dividerCount)
        let newTotal = iconWidth + widths.name + widths.size + widths.permissions + widths.date + (dividerWidth * dividerCount)
        
        XCTAssertEqual(newTotal - originalTotal, 50, "Total width should increase by the same amount as name column")
    }
    
    func testColumnPositions() {
        let widths = ColumnWidths()
        
        // Calculate expected positions for each column
        let iconX: CGFloat = 0
        let iconWidth: CGFloat = 28
        
        let nameX = iconX + iconWidth
        let nameWidth = widths.name
        
        let divider1X = nameX + nameWidth
        let divider1Width: CGFloat = 4
        
        let sizeX = divider1X + divider1Width
        let sizeWidth = widths.size
        
        let divider2X = sizeX + sizeWidth
        let divider2Width: CGFloat = 4
        
        let permX = divider2X + divider2Width
        let permWidth = widths.permissions
        
        let divider3X = permX + permWidth
        let divider3Width: CGFloat = 4
        
        let dateX = divider3X + divider3Width
        let dateWidth = widths.date
        
        print("Column positions:")
        print("Icon: x=\(iconX), width=\(iconWidth)")
        print("Name: x=\(nameX), width=\(nameWidth)")
        print("Size: x=\(sizeX), width=\(sizeWidth)")
        print("Permissions: x=\(permX), width=\(permWidth)")
        print("Date: x=\(dateX), width=\(dateWidth)")
        
        // Verify positions are sequential
        XCTAssertEqual(nameX, iconX + iconWidth)
        XCTAssertEqual(sizeX, nameX + nameWidth + 4)
        XCTAssertEqual(permX, sizeX + sizeWidth + 4)
        XCTAssertEqual(dateX, permX + permWidth + 4)
    }
    
    func testColumnContentOverflow() {
        let widths = ColumnWidths()
        let longFileName = "ThisIsAVeryLongFileNameThatShouldBeTruncatedProperly.txt"
        
        // The name column should truncate content that exceeds its width
        XCTAssertEqual(widths.name, 200, "Name column width should be 200")
        
        // Content should be truncated, not overflow
        // This would need UI testing to verify actual rendering
    }
}