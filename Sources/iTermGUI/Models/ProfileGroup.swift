import Foundation
import SwiftUI

struct ProfileGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var profileIDs: Set<UUID>
    var isExpanded: Bool
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder",
        color: String = "blue",
        profileIDs: Set<UUID> = [],
        isExpanded: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.profileIDs = profileIDs
        self.isExpanded = isExpanded
        self.sortOrder = sortOrder
    }
    
    static let defaultGroups = [
        ProfileGroup(name: "All Profiles", icon: "square.stack", color: "gray", sortOrder: 0),
        ProfileGroup(name: "Favorites", icon: "star", color: "yellow", sortOrder: 1),
        ProfileGroup(name: "Recent", icon: "clock", color: "blue", sortOrder: 2),
        ProfileGroup(name: "Work", icon: "briefcase", color: "purple", sortOrder: 3),
        ProfileGroup(name: "Personal", icon: "house", color: "green", sortOrder: 4),
        ProfileGroup(name: "Projects", icon: "folder.badge.gearshape", color: "orange", sortOrder: 5)
    ]
}