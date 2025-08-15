import SwiftUI

struct TestColumnWidths {
    var name: CGFloat = 200
    var size: CGFloat = 80
    var permissions: CGFloat = 90
    var date: CGFloat = 120
}

struct TestFileRow: View {
    let fileName: String
    let columnWidths: TestColumnWidths
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Calculate column positions
                let iconWidth: CGFloat = 28
                let dividerWidth: CGFloat = 4
                
                let nameX: CGFloat = iconWidth
                let sizeX: CGFloat = nameX + columnWidths.name + dividerWidth
                let permX: CGFloat = sizeX + columnWidths.size + dividerWidth
                let dateX: CGFloat = permX + columnWidths.permissions + dividerWidth
                
                // Icon
                Image(systemName: "doc.fill")
                    .foregroundColor(.gray)
                    .frame(width: iconWidth, height: 24)
                    .position(x: iconWidth/2, y: 12)
                
                // Name column
                Text(fileName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 4)
                    .frame(width: columnWidths.name, height: 24, alignment: .leading)
                    .position(x: nameX + columnWidths.name/2, y: 12)
                    .background(Color.blue.opacity(0.1))
                
                // Size column
                Text("1.2 MB")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .frame(width: columnWidths.size, height: 24, alignment: .trailing)
                    .position(x: sizeX + columnWidths.size/2, y: 12)
                    .background(Color.green.opacity(0.1))
                
                // Permissions column
                Text("rwxr-xr-x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .frame(width: columnWidths.permissions, height: 24, alignment: .center)
                    .position(x: permX + columnWidths.permissions/2, y: 12)
                    .background(Color.yellow.opacity(0.1))
                
                // Date column
                Text("2024-01-15")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .frame(width: columnWidths.date, height: 24, alignment: .trailing)
                    .position(x: dateX + columnWidths.date/2, y: 12)
                    .background(Color.red.opacity(0.1))
            }
            .frame(width: geometry.size.width, height: 24)
            .clipped()
        }
        .frame(height: 24)
        .background(Color.gray.opacity(0.05))
    }
}

struct ColumnLayoutTestView: View {
    @State private var columnWidths = TestColumnWidths()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Column Layout Test")
                .font(.title)
            
            // Controls to adjust column widths
            VStack(alignment: .leading) {
                HStack {
                    Text("Name Width: \(Int(columnWidths.name))")
                    Slider(value: $columnWidths.name, in: 100...400)
                }
                HStack {
                    Text("Size Width: \(Int(columnWidths.size))")
                    Slider(value: $columnWidths.size, in: 60...150)
                }
                HStack {
                    Text("Permissions Width: \(Int(columnWidths.permissions))")
                    Slider(value: $columnWidths.permissions, in: 70...150)
                }
                HStack {
                    Text("Date Width: \(Int(columnWidths.date))")
                    Slider(value: $columnWidths.date, in: 80...200)
                }
            }
            .padding()
            
            Divider()
            
            // Test rows
            VStack(spacing: 2) {
                TestFileRow(fileName: "Short.txt", columnWidths: columnWidths)
                TestFileRow(fileName: "Medium_length_filename.txt", columnWidths: columnWidths)
                TestFileRow(fileName: "This_is_a_very_long_filename_that_should_be_truncated_properly.txt", columnWidths: columnWidths)
            }
            .frame(width: 600)
            .border(Color.black)
            
            Spacer()
        }
        .frame(width: 700, height: 500)
        .padding()
    }
}

@main
struct ColumnTestApp: App {
    var body: some Scene {
        WindowGroup {
            ColumnLayoutTestView()
        }
    }
}