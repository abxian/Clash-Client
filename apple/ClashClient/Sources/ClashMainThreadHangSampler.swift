import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ClashMainThreadHangSampler {
    static func start() {
#if os(iOS) && arch(arm64)
        guard Thread.isMainThread else { return }


        ClashLongHangWatch.shared.start()
#endif
    }
}

#if os(iOS) && arch(arm64)
 
 
 
 
 
 
 
final class ClashMainThreadStackReader: @unchecked Sendable {
    private let mainThread: thread_act_t
    private let buffer: UnsafeMutablePointer<UInt>
    private let capacity: Int

     
    init(capacity: Int = 64) {
        precondition(Thread.isMainThread)
        mainThread = mach_thread_self()
        self.capacity = max(capacity, 2)
        buffer = .allocate(capacity: self.capacity)
    }

    deinit { buffer.deallocate() }

     
    func read() -> [UInt] {
        let count = walk()
        return (0..<count).map { buffer[$0] }
    }

    private func walk() -> Int {
        let thread = mainThread
        let buffer = buffer
        let capacity = capacity
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )
        let flavor: thread_state_flavor_t = 6   
        var pair: (UInt, UInt) = (0, 0)
        let pairSize = vm_size_t(MemoryLayout<(UInt, UInt)>.size)

        guard thread_suspend(thread) == KERN_SUCCESS else { return 0 }
        defer { thread_resume(thread) }
        let result = withUnsafeMutablePointer(to: &state) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(count)) {
                thread_get_state(thread, flavor, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        buffer[0] = Self.code(UInt(state.__pc))
        buffer[1] = Self.code(UInt(state.__lr))
        var filled = 2
        var fp = UInt(state.__fp)
        while fp != 0, filled < capacity {
            var read: vm_size_t = 0
             
            let ok = withUnsafeMutablePointer(to: &pair) { destination in
                vm_read_overwrite(
                    mach_task_self_, vm_address_t(fp), pairSize,
                    vm_address_t(UInt(bitPattern: destination)), &read
                )
            }
            guard ok == KERN_SUCCESS, read == pairSize else { break }
            let (previous, returnAddress) = pair
            guard returnAddress != 0, previous > fp else { break }
            buffer[filled] = Self.code(returnAddress)
            filled += 1
            fp = previous
        }
        return filled
    }

     
     
     
    private static func code(_ address: UInt) -> UInt { address & 0x0000_000F_FFFF_FFFF }

     
     
     
     
     
     
     
     
    static func describe(_ address: UInt, appPath: String, namesAppFrames: Bool = false) -> String {
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: address), &info) != 0 else {
            return String(format: "0x%lx", address)
        }
        let path = info.dli_fname.map { String(cString: $0) } ?? "?"
        let image = (path as NSString).lastPathComponent
        if namesAppFrames || !path.hasPrefix(appPath),
           let name = info.dli_sname.map({ String(cString: $0) }),
           name != "<redacted>" {
            return "\(image)`\(name)+\(address &- UInt(bitPattern: info.dli_saddr))"
        }
        return image + "+0x" + String(address &- UInt(bitPattern: info.dli_fbase), radix: 16)
    }
}

 
 
 
 
 
 
 
 
 
 
 
final class ClashLongHangWatch: @unchecked Sendable {
    static let shared = ClashLongHangWatch()

    private let threshold: UInt64
    private let sampleAfter: [UInt64]
    private let poll: UInt64
    private let write: @Sendable (String) -> Void
    private let appPath = Bundle.main.bundlePath

    private let lock = NSLock()
    private var asleep = false
    private var awakeSince = DispatchTime.now().uptimeNanoseconds
    private var observer: CFRunLoopObserver?
    private var reader: ClashMainThreadStackReader?
    private var stopped = false

    init(
        threshold: TimeInterval = 2,
        sampleAfter: [TimeInterval] = [2, 5, 10],
        poll: TimeInterval = 0.5,
        write: @escaping @Sendable (String) -> Void = ClashLongHangWatch.writeToLogs
    ) {
        self.threshold = Self.nanoseconds(threshold)
        self.sampleAfter = sampleAfter.map(Self.nanoseconds)
        self.poll = max(Self.nanoseconds(poll), 1_000_000)
        self.write = write
    }

    static let writeToLogs: @Sendable (String) -> Void = { line in
        ClashLogStore.shared.append(line, stream: .app, level: .warning)
        FrameLogFile.append(line)
    }

     
    func start() {
        guard Thread.isMainThread else { return }
        lock.lock()
        let started = observer != nil || stopped
        lock.unlock()
        guard !started else { return }
        reader = ClashMainThreadStackReader()
        let activities: CFRunLoopActivity = [.beforeWaiting, .afterWaiting]
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault, activities.rawValue, true, 0
        ) { [weak self] _, activity in
            self?.note(activity)
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        lock.lock()
        self.observer = observer
        asleep = false
        awakeSince = DispatchTime.now().uptimeNanoseconds
        lock.unlock()
        let thread = Thread { [weak self] in self?.watch() }
        thread.name = "clash.long-hang-watch"
        thread.qualityOfService = .utility
        thread.start()
    }

     
    func stop() {
        lock.lock()
        stopped = true
        let observer = observer
        self.observer = nil
        lock.unlock()
        if let observer { CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes) }
    }

    private func note(_ activity: CFRunLoopActivity) {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        if activity == .beforeWaiting {
            asleep = true
        } else if asleep {
            asleep = false
            awakeSince = now
        }
        lock.unlock()
    }

    private func watch() {
        var lastLook = DispatchTime.now().uptimeNanoseconds
         
         
        var notBefore: UInt64 = 0
        var stall: (since: UInt64, samples: Int)?
        while true {
            usleep(useconds_t(poll / 1_000))
            lock.lock()
            let isAsleep = asleep
            let woke = awakeSince
            let isStopped = stopped
            lock.unlock()
            if isStopped { return }
             
             
             
            let now = DispatchTime.now().uptimeNanoseconds
            if Self.elapsed(from: lastLook, to: now) > poll + Self.nanoseconds(1) { notBefore = now }
            lastLook = now
            let since = max(woke, notBefore)

             
             
             
            if let current = stall, isAsleep || since != current.since {
                write(
                    ["hang", "main", "over", "within",
                     "\(Self.elapsed(from: current.since, to: now) / 1_000_000)ms",
                     "samples=\(current.samples)"]
                        .joined(separator: " ")
                )
                stall = nil
            }
            let awake = Self.elapsed(from: since, to: now)
            guard !isAsleep, awake >= threshold else { continue }
            var current = stall ?? (since, 0)
            if current.samples < sampleAfter.count, awake >= sampleAfter[current.samples],
               let reader {
                current.samples += 1
                let frames = reader.read().map {
                    ClashMainThreadStackReader.describe($0, appPath: appPath)
                }
                write(
                    ["hang", "main", "+\(awake / 1_000_000)ms:", frames.joined(separator: " < ")]
                        .joined(separator: " ")
                )
            }
            stall = current
        }
    }

    private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        UInt64(max(seconds, 0) * 1_000_000_000)
    }

     
     
    static func elapsed(from earlier: UInt64, to later: UInt64) -> UInt64 {
        later >= earlier ? later - earlier : 0
    }
}
#endif


