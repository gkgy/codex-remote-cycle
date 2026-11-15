import Foundation

@main struct Tests {
    static func main() {
        let five = ["a", "b", "c", "d", "e"]
        var s = nextState(recent: five, previous: nil, backwards: false)!
        assert(s.current == "a")
        for expected in ["b", "c", "d", "e", "a"] {
            s = nextState(recent: five, previous: s, backwards: false)!
            assert(s.current == expected)
        }
        s = nextState(recent: ["b", "a", "c", "d", "e"], previous: s, backwards: true)!
        assert(s.current == "e" && s.ids == five)
        s = nextState(recent: ["new", "a", "b", "c", "d"], previous: s, backwards: false)!
        assert(s.current == "new" && !s.ids.contains("e"))
        assert(nextState(recent: [], previous: s, backwards: false) == nil)
        assert(nextState(recent: ["a"], previous: nil, backwards: true)?.current == "a")
        print("PASS: initial position, forward wrap, reverse wrap, stable ordering, new membership, empty/single list")
    }
}
