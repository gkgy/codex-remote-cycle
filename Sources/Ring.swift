import Foundation

struct CycleState: Codable, Equatable {
    var ids: [String]
    var current: String
}

func nextState(recent: [String], previous: CycleState?, backwards: Bool) -> CycleState? {
    guard !recent.isEmpty else { return nil }
    let ring = previous.map { Set($0.ids) == Set(recent) ? $0.ids : recent } ?? recent
    guard let current = previous?.current, let index = ring.firstIndex(of: current) else {
        return CycleState(ids: ring, current: backwards ? ring.last! : ring.first!)
    }
    let targetIndex = (index + (backwards ? -1 : 1) + ring.count) % ring.count
    return CycleState(ids: ring, current: ring[targetIndex])
}
