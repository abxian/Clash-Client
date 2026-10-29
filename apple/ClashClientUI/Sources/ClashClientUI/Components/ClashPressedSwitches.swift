import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
public struct ClashPressedSwitches<Key: Hashable>: Equatable {
    private struct Press: Equatable {
        let value: Bool
        let number: Int
    }

    private var pressed: [Key: Press] = [:]
    private var presses = 0

    public init() {}

     
    public func shown(_ key: Key, else read: Bool) -> Bool {
        pressed[key]?.value ?? read
    }

     
    @discardableResult
    public mutating func press(_ key: Key, _ value: Bool) -> Int {
        presses &+= 1
        pressed[key] = Press(value: value, number: presses)
        return presses
    }

     
     
    public mutating func settle(_ key: Key, press number: Int) {
        guard pressed[key]?.number == number else { return }
        pressed[key] = nil
        writtenPresses[key] = nil
    }

     
     
     
     
     
    public mutating func written(_ key: Key, press number: Int) {
        guard pressed[key]?.number == number else { return }
        writtenPresses[key] = number
    }

     
    public mutating func read(_ key: Key) {
        guard let number = writtenPresses.removeValue(forKey: key) else { return }
        settle(key, press: number)
    }

    private var writtenPresses: [Key: Int] = [:]

    public var isEmpty: Bool { pressed.isEmpty }
}
