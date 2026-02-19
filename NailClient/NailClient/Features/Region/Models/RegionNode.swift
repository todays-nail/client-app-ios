import Foundation

struct RegionNode: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let level: Int?
    let parentID: UUID?
    let serviceScopeID: UUID
    let children: [RegionNode]

    var isLeaf: Bool {
        children.isEmpty
    }
}

extension RegionNode {
    func contains(regionID: UUID) -> Bool {
        if id == regionID {
            return true
        }
        return children.contains { $0.contains(regionID: regionID) }
    }

    func path(to regionID: UUID) -> [RegionNode]? {
        if id == regionID {
            return [self]
        }

        for child in children {
            if let childPath = child.path(to: regionID) {
                return [self] + childPath
            }
        }

        return nil
    }
}
