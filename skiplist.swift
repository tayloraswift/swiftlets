struct UnmanagedBuffer<Header, Element>:Equatable
{
    // just like roundUp(_:toAlignment) in stdlib/public/core/BuiltIn.swift
    @inline(__always)
    private static
    func round_up(_ offset:UInt, to_alignment alignment:Int) -> UInt
    {
        let x = offset + UInt(bitPattern: alignment) &- 1
        return x & ~(UInt(bitPattern: alignment) &- 1)
    }

    private static
    var buffer_offset:Int
    {
        return Int(bitPattern: UnmanagedBuffer.round_up(UInt(MemoryLayout<Header>.size),
                                                        to_alignment: MemoryLayout<Element>.alignment))
    }

    private
    let core:UnsafeMutablePointer<Header>

    private
    var buffer:UnsafeMutablePointer<Element>
    {
        let raw_ptr = UnsafeMutableRawPointer(mutating: self.core) +
                      UnmanagedBuffer<Header, Element>.buffer_offset
        return raw_ptr.assumingMemoryBound(to: Element.self)
    }

    var base:UnsafePointer<Header>
    {
        return UnsafePointer<Header>(self.core)
    }

    var header:Header
    {
        get
        {
            return self.core.pointee
        }
        set(v)
        {
            self.core.pointee = v
        }
    }

    subscript(index:Int) -> Element
    {
        get
        {
            return self.buffer[index]
        }
        set(v)
        {
            // do not use storeBytes because it only works on trivial types
            self.buffer[index] = v
        }
    }

    private
    init(core:UnsafeMutablePointer<Header>)
    {
        self.core = core
    }

    static
    func allocate(capacity:Int) -> UnmanagedBuffer<Header, Element>
    {
        let align1:Int = MemoryLayout<Header>.alignment,
            align2:Int = MemoryLayout<Element>.alignment,
            padded_size:Int = UnmanagedBuffer<Header, Element>.buffer_offset +
                              capacity * MemoryLayout<Element>.stride

        let memory = UnsafeMutableRawPointer.allocate(bytes: padded_size, alignedTo: max(align1, align2))
        return UnmanagedBuffer<Header, Element>(core: memory.assumingMemoryBound(to: Header.self))
    }

    func initialize_header(to header:Header)
    {
        self.core.initialize(to: header, count: 1)
    }
    func initialize_elements(from buffer:UnsafePointer<Element>, count:Int)
    {
        self.buffer.initialize(from: buffer, count: count)
    }

    func move_initialize_elements(from unmanaged:UnmanagedBuffer<Header, Element>, count:Int)
    {
        self.buffer.moveInitialize(from: unmanaged.buffer, count: count)
    }

    func deinitialize_header()
    {
        self.core.deinitialize(count: 1)
    }
    func deinitialize_elements(count:Int)
    {
        self.buffer.deinitialize(count: count)
    }

    func deallocate()
    {
        self.core.deallocate(capacity: -1) // free the entire block
    }

    static
    func == (a:UnmanagedBuffer<Header, Element>, b:UnmanagedBuffer<Header, Element>) -> Bool
    {
        return a.core == b.core
    }
}
extension UnmanagedBuffer:CustomStringConvertible
{
    var description:String
    {
        return String(describing: self.core)
    }
}

struct UnsafeConicalList<Element> where Element:Comparable
{
    private
    typealias NodePointer = UnmanagedBuffer<Element, Link>

    private // *must* be a trivial type
    struct Link
    {
        // yes, the Element is the Header, and the Link is the Element.
        // it’s confusing.
        var prev:NodePointer,
            next:NodePointer
    }

    private
    struct HeadVector
    {
        private(set)
        var count:Int = 0,
            capacity:Int

        private(set)
        var storage:NodePointer

        subscript(index:Int) -> Link
        {
            get
            {
                return self.storage[index]
            }
            set(v)
            {
                self.storage[index] = v
            }
        }

        private
        init(storage:NodePointer, capacity:Int)
        {
            self.storage  = storage
            self.capacity = capacity
        }

        static
        func create(capacity:Int = 0) -> HeadVector
        {
            // we don’t bother initializing or deinitializing the header;
            // we never use it anyway
            return HeadVector(  storage: NodePointer.allocate(capacity: capacity),
                                capacity: capacity)
        }

        func deinitialize()
        {
            self.storage.deallocate()
        }

        private mutating
        func extend_storage()
        {
            self.capacity   = self.capacity << 1 - self.capacity >> 1 + 8
            let new_storage = NodePointer.allocate(capacity: self.capacity)
                new_storage.move_initialize_elements(from: self.storage, count: self.count)
            self.storage.deallocate()
            self.storage    = new_storage
        }

        mutating
        func grow(to height:Int, linking new:inout NodePointer)
        {
            if height > self.capacity
            {
                // storage will increase by at least 8
                self.extend_storage()
            }
            assert(height <= self.capacity)
            assert(height >  self.count)

            let link:Link = Link(prev: new, next: new)
            for level in self.count ..< height
            {
                new[level]          = link
                self.storage[level] = link
            }
            self.count = height
        }

        mutating
        func shrink(to height:Int)
        {
            assert(height < self.count)
            self.count = height
        }
    }

    private
    struct RandomNumberGenerator
    {
        private
        var state:UInt64

        init(seed:Int)
        {
            self.state = UInt64(extendingOrTruncating: seed)
        }

        mutating
        func generate() -> UInt64
        {
            self.state = self.state &* 2862933555777941757 + 3037000493
            return self.state
        }
    }

    // head_vector is an unstable buffer. *never* store a pointer to it
    private
    var random:RandomNumberGenerator = RandomNumberGenerator(seed: 24),
        head_vector:HeadVector

    private
    init(head_vector:HeadVector)
    {
        self.head_vector = head_vector
    }

    static
    func create() -> UnsafeConicalList<Element>
    {
        let head_vector:HeadVector = HeadVector.create(capacity: 8)
        return UnsafeConicalList<Element>(head_vector: head_vector)
    }

    func deinitialize()
    {
        if self.head_vector.count > 0
        {
            let head:NodePointer    = self.head_vector.storage
            var current:NodePointer = head[0].next
            repeat
            {
                let old:NodePointer = current
                current = current[0].next
                old.deinitialize_header()
                old.deallocate()
            } while current != head[0].next
        }

        self.head_vector.deinitialize()
    }

    @discardableResult
    mutating
    func insert(_ element:Element) -> UnsafePointer<Element>
    {
        return self.insert(element, height: self.random.generate().trailingZeroBitCount + 1).base
    }

    private mutating
    func insert(_ element:Element, height:Int) -> NodePointer
    {
        var level:Int       = self.head_vector.count,
            new:NodePointer = NodePointer.allocate(capacity: height)
            new.initialize_header(to: element)

        if height > level
        {
            self.head_vector.grow(to: height, linking: &new)

            // height will always be > 0, so if level <= 0, then height > level
            guard level > 0
            else
            {
                return new
            }
        }
        level -= 1
        // from here on out, all of our linked lists contain at least one node

        var head:NodePointer    = self.head_vector.storage,
            current:NodePointer = head
        while true
        {
            if  current[level].next.header < element,
                current[level].next != head[level].next || current == head
                // account for the discontinuity to prevent infinite traversal
            {
                current = current[level].next
                continue
            }
            else if level < height
            {
                new[level].next             = current[level].next
                if current == head
                {
                    new[level].prev             = head[level].next[level].prev
                    new[level].prev[level].next = new
                    new[level].next[level].prev = new

                    head[level].prev            = new
                    head[level].next            = new
                }
                else
                {
                    new[level].prev             = current
                    new[level].next[level].prev = new
                    current[level].next         = new
                }

                // height will always be > 0, so if level == 0 then level < height
                if level == 0
                {
                    break
                }
            }

            level -= 1
        }

        return new
    }
}
extension UnsafeConicalList:CustomStringConvertible
{
    var description:String
    {
        var output:String = ""
        for level in (0 ..< self.head_vector.count).reversed()
        {
            let head:NodePointer    = self.head_vector.storage
            output += "[\(head[level].prev.header) ← HEAD → \(head[level].next.header)]"

            var current:NodePointer = head[level].next
            repeat
            {
                output += " (\(current[level].prev.header) ← \(current.header) → \(current[level].next.header))"
                current = current[level].next
            } while current != head[level].next

            if level > 0
            {
                output += "\n"
            }
        }

        return output
    }
}

class _TestHeader
{
    let name:String

    init(name:String)
    {
        self.name = name
    }

    deinit
    {
        print("deinitialized _TestHeader('\(self.name)')")
    }
}

/*
class _TestElement:Comparable
{
    let value:Int

    init(value:Int)
    {
        self.value = value
    }

    deinit
    {
        print("deinitialized _TestElement(\(self.value))")
    }

    static
    func == (a:_TestElement, b:_TestElement) -> Bool
    {
        return a.value == b.value
    }

    static
    func < (a:_TestElement, b:_TestElement) -> Bool
    {
        return a.value < b.value
    }
}
extension _TestElement:CustomStringConvertible
{
    var description:String
    {
        return String(self.value)
    }
}

var cl:UnsafeConicalList = UnsafeConicalList<_TestElement>.create()
for v in [7, 5, 6, 1, 9, 16, 33, 7, -3, 0].map(_TestElement.init(value:))
{
    cl.insert(v)
}
print(cl)
cl.deinitialize()
*/

// random insertion stress test
import func Glibc.clock

extension Array
{
    func insertionIndexOf(_ elem:Element, _ isOrderedBefore:(Element, Element) -> Bool) -> Int
    {
        var lo = 0
        var hi = self.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if isOrderedBefore(self[mid], elem) {
                lo = mid + 1
            } else if isOrderedBefore(elem, self[mid]) {
                hi = mid - 1
            } else {
                return mid // found at position mid
            }
        }
        return lo // not found, would be inserted at position lo
    }
}

do
{
    for n in (1 ... 100).map({ 100 * $0 })
    {
        let time1:Int = clock()

        var state:UInt64 = 13,
            skiplist:UnsafeConicalList<UInt64> = UnsafeConicalList<UInt64>.create(),
            handle:UnsafePointer<UInt64> = UnsafePointer(bitPattern: -1)!
        for _ in 0 ..< n
        {
            state = state &* 2862933555777941757 + 3037000493
            handle = skiplist.insert(state >> 32)
        }
        print(clock() - time1, terminator: " ")
        print("(@ \(handle) → \(handle.pointee))", terminator: " ")
        skiplist.deinitialize()

        let time2:Int = clock()
        state = 13
        var array:[UInt64] = []
        for _ in 0 ..< n
        {
            state = state &* 2862933555777941757 + 3037000493
            array.insert(state >> 32, at: array.insertionIndexOf(state >> 32, <))
        }
        print(clock() - time2, terminator: " ")
        print("[n = \(n)]")
    }
}


/*

var cl = UnsafeConicalList<_TestElement>.create()
for (v, h) in zip([7, 5, 6, 1, 9].map(_TestElement.init(value:)), [4, 1, 2, 3, 2])
{
    print(cl)
    cl.insert(v, height: h)
}
*/

/*
var umb = UnmanagedBuffer<_TestHeader, _TestElement>.allocate(capacity: 5)
umb.initialize_header(to: _TestHeader(name: "unmanaged buffer"))
// umb[0] = _TestElement(value: -1) // should crash due to invalid release
[2, 5, 6, 1, 9].map(_TestElement.init(value:)).withUnsafeBufferPointer
{
    umb.initialize_elements(from: $0.baseAddress!, count: 5)
}

print(umb.header)
for i in 0 ..< 5
{
    print(umb[i])
}
umb.deinitialize_header()
umb.deinitialize_elements(count: 5)
umb.deallocate()
*/

/*
var stack = UnsafeStack<_TestElement>()
for v in [2, 5, 6, 1, 9].map(_TestElement.init(value:))
{
    stack.allocating_push(v)
}
print(stack)
for _ in 0 ..< 5
{
    stack.pop()
}
stack.deinitialize()
*/
