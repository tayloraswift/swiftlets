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
