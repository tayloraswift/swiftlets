struct UnsafeVector<Element>:CustomStringConvertible
{
    private
    var buffer = UnsafeMutableBufferPointer<Element>(start: nil, count: 0)

    var count:Int = 0
    var capacity:Int
    {
        return self.buffer.count
    }

    subscript(index:Int) -> Element
    {
        get
        {
            return self.buffer[index]
        }
        set(v)
        {
            self.buffer[index] = v
        }
    }

    var description:String
    {
        return "[\(self.buffer[0 ..< self.count].map(String.init(describing:)).joined(separator: ", "))]"
    }

    func deinitialize()
    {
        self.buffer.baseAddress?.deinitialize(count: self.count)
        self.buffer.baseAddress?.deallocate(capacity: self.capacity)
    }

    mutating
    func reserve_capacity(_ capacity:Int)
    {
        let new_capacity:Int = max(capacity, self.count)

        let new_buffer = UnsafeMutablePointer<Element>.allocate(capacity: new_capacity)
        if let old_buffer:UnsafeMutablePointer<Element> = self.buffer.baseAddress
        {
            new_buffer.moveInitialize(from: old_buffer, count: self.count)
            //print("deallocate", self.capacity)
            old_buffer.deallocate(capacity: self.capacity)
        }

        self.buffer = UnsafeMutableBufferPointer<Element>(start: new_buffer, count: new_capacity)
    }

    mutating
    func allocating_push(_ element:Element)
    {
        if self.count >= self.capacity
        {
            // guaranteed to lengthen the buffer by at least 8
            self.reserve_capacity(self.capacity << 1 - self.capacity >> 1 + 8)
        }
        assert(self.capacity > self.count)

        (self.buffer.baseAddress! + self.count).initialize(to: element, count: 1)
        self.count += 1
    }

    @discardableResult
    mutating
    func pop() -> Element?
    {
        guard self.count > 0
        else
        {
            return nil
        }

        self.count -= 1
        return (self.buffer.baseAddress! + self.count).move()
    }
}

struct UnmanagedBuffer<Header, Element>:Equatable
{
    // just like roundUp(_:toAlignment) in stdlib/public/core/BuiltIn.swift
    @inline(__always)
    private static
    func round_up(_ offset: UInt, to_alignment alignment: Int) -> UInt
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
        // free the entire block
        self.core.deallocate(capacity: -1)
    }

    static
    func == (a:UnmanagedBuffer<Header, Element>, b:UnmanagedBuffer<Header, Element>) -> Bool
    {
        return a.core == b.core
    }
}

struct UnsafeConicalList<Element> where Element:Comparable
{
    private // *must* be a trivial type
    struct Link
    {
        // yes, the Element is the Header, and the Link is the Element.
        // it’s confusing.
        var prev:UnmanagedBuffer<Element, Link>?,
            next:UnmanagedBuffer<Element, Link>?
    }

    private
    struct HeadVector
    {
        private(set)
        var count:Int = 0,
            capacity:Int

        private(set) // don’t bother with the header, we never touch it
        var storage:UnmanagedBuffer<Element, Link>

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
        init(storage:UnmanagedBuffer<Element, Link>, capacity:Int)
        {
            self.storage  = storage
            self.capacity = capacity
        }

        static
        func create(capacity:Int = 0) -> HeadVector
        {
            let storage = UnmanagedBuffer<Element, Link>.allocate(capacity: capacity)
            return HeadVector(storage: storage, capacity: capacity)
        }

        private mutating
        func extend_storage()
        {
            self.capacity = self.capacity << 1 - self.capacity >> 1 + 8
            let new_storage = UnmanagedBuffer<Element, Link>.allocate(capacity: self.capacity)
            new_storage.move_initialize_elements(from: self.storage, count: self.count)
            self.storage.deallocate()
            self.storage = new_storage
        }

        mutating
        func resize(to height:Int, repeating repeated:Link)
        {
            let old_capacity:Int = self.capacity
            if height > self.capacity
            {
                // storage will increase by at least 8
                self.extend_storage()
            }
            assert(height <= self.capacity)

            if height > self.count
            {
                for level in self.count ..< height
                {
                    self.storage[level] = repeated
                }
            }
            self.count = height
        }
    }

    // head is an unstable buffer. *never* store a pointer to it
    private
    var head_vector:HeadVector

    private
    init(head_vector:HeadVector)
    {
        self.head_vector = head_vector
    }

    static
    func create() -> UnsafeConicalList<Element>
    {
        var head_vector:HeadVector = HeadVector.create(capacity: 8)
        head_vector.resize(to: 1, repeating: Link(prev: nil, next: nil))
        return UnsafeConicalList<Element>(head_vector: head_vector)
    }

    /*
    func find(_ value:Element) -> UnsafePointer<Node<Element>>?
    {
        var level:Int = self.top_level
        var current_tower:Vector<UnsafePointer<Node<Element>>?> = self.head
        while true
        {
            if let next:UnsafePointer<Node<Element>> = current_tower[level]
            {
                if next.pointee.value < value
                {
                    current_tower = next.pointee.tower
                }
                else if level == 0
                {
                    return next
                }
                else
                {
                    level -= 1
                }
            }
            else if level == 0
            {
                return nil
            }
            else
            {
                level -= 1
            }
        }
    }
    */

    /*
    @inline(__always)
    func will_overshoot(value:Element, from_tower tower:Vector<UnsafePointer<Node<Element>>?>, level:Int) -> Bool
    {
        guard let next:UnsafePointer<Node<Element>> = tower[level]
        else
        {
            return true
        }

        return next.pointee.value > value
    }
    */
    private mutating
    func insert(_ element:Element, height:Int)
    {
        typealias NodePointer = UnmanagedBuffer<Element, Link>

        if height > self.head_vector.count
        {
            self.head_vector.resize(to: height, repeating: Link(prev: nil, next: nil))
        }

        let head:NodePointer    = self.head_vector.storage
        var current:NodePointer = head,
            new:NodePointer     = NodePointer.allocate(capacity: height),
            level:Int           = self.head_vector.count - 1

        new.initialize_header(to: element)
        while true
        {
            if let  next:NodePointer = current[level].next,
                    next.header < element,
                    next != head[level].next || current == head
                    // account for the discontinuity to prevent infinite traversal
            {
                current = next
                continue
            }
            else if level < height
            {
                new[level].next = current[level].next ?? head[level].next ?? new
                current[level].next = new

                // height will always be > 0, so if level == 0 then level < height
                if level == 0
                {
                    break
                }
            }

            level -= 1
        }
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

class _TestElement
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
}

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
