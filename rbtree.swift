struct UnsafeBalancedTree<Element>
{
    fileprivate
    struct NodeCore
    {
        enum Color
        {
            case red, black
        }

        var parent:Node?,
            lchild:Node?,
            rchild:Node?

        var element:Element

        // arrange later to take advantage of padding space if Element produces any
        var color:Color
    }

    struct Node:Equatable
    {
        private
        var core:UnsafeMutablePointer<NodeCore>

        var element:Element
        {
            get
            {
                return self.core.pointee.element
            }
            set(v)
            {
                self.core.pointee.element = v
            }
        }

        fileprivate
        var color:NodeCore.Color
        {
            get
            {
                return self.core.pointee.color
            }
            nonmutating set(v)
            {
                self.core.pointee.color = v
            }
        }

        internal fileprivate(set)
        var parent:Node?
        {
            get
            {
                return self.core.pointee.parent
            }
            nonmutating set(v)
            {
                self.core.pointee.parent = v
            }
        }

        internal fileprivate(set)
        var lchild:Node?
        {
            get
            {
                return self.core.pointee.lchild
            }
            nonmutating set(v)
            {
                self.core.pointee.lchild = v
            }
        }

        internal fileprivate(set)
        var rchild:Node?
        {
            get
            {
                return self.core.pointee.rchild
            }
            nonmutating set(v)
            {
                self.core.pointee.rchild = v
            }
        }

        fileprivate
        func deallocate()
        {
            self.core.deinitialize(count: 1)
            self.core.deallocate(capacity: 1)
        }

        fileprivate static
        func create(_ value:Element, color:NodeCore.Color = .red) -> Node
        {
            let core = UnsafeMutablePointer<NodeCore>.allocate(capacity: 1)
                core.initialize(to: NodeCore(parent: nil,
                                             lchild: nil,
                                             rchild: nil,
                                             element: value,
                                             color: color))
            return Node(core: core)
        }

        static
        func == (a:Node, b:Node) -> Bool
        {
            return a.core == b.core
        }
    }

    internal private(set)
    var root:Node? = nil

    // frees the tree from memory
    func deallocate()
    {
        UnsafeBalancedTree.deallocate(self.root)
    }

    // verifies that all paths in the red-black tree have the same black height,
    // that all nodes satisfy the red property, and that the root is black
    func verify() -> Bool
    {
        return  self.root?.color ?? .black == .black &&
                UnsafeBalancedTree.verify(self.root) != nil
    }

    // returns the inserted node
    @discardableResult
    mutating
    func append(_ element:Element) -> Node
    {
        if let last:Node = self.last()
        {
            return self.insert(element, after: last)
        }
        else
        {
            let root:Node = Node.create(element, color: .black)
            self.root = root
            return root
        }
    }

    // returns the inserted node
    @discardableResult
    mutating
    func insert(_ element:Element, after predecessor:Node) -> Node
    {
        let new:Node = Node.create(element)
        UnsafeBalancedTree.insert(new, after: predecessor, root: &self.root)
        return new
    }

    mutating
    func delete(_ node:Node)
    {
        UnsafeBalancedTree.delete(node, root: &self.root)
    }

    @inline(__always)
    private
    func extreme(descent:(Node) -> Node) -> Node?
    {
        guard let root:Node = self.root
        else
        {
            return nil
        }

        return descent(root)
    }

    // returns the leftmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func first() -> Node?
    {
        return self.extreme(descent: UnsafeBalancedTree.leftmost(from:))
    }

    // returns the rightmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func last() -> Node?
    {
        return self.extreme(descent: UnsafeBalancedTree.rightmost(from:))
    }

    static
    func leftmost(from node:Node) -> Node
    {
        var leftmost:Node = node
        while let lchild:Node = leftmost.lchild
        {
            leftmost = lchild
        }

        return leftmost
    }

    static
    func rightmost(from node:Node) -> Node
    {
        var rightmost:Node = node
        while let rchild:Node = rightmost.rchild
        {
            rightmost = rchild
        }

        return rightmost
    }

    // returns the inorder successor of the node in amortized O(1) time
    static
    func successor(of node:Node) -> Node?
    {
        if let rchild:Node = node.rchild
        {
            return leftmost(from: rchild)
        }

        var current:Node = node
        while let   parent:Node = current.parent,
                    current == parent.rchild
        {
            current = parent
        }

        return current.parent
    }

    // returns the inorder predecessor of the node in amortized O(1) time
    static
    func predecessor(of node:Node) -> Node?
    {
        if let lchild:Node = node.lchild
        {
            return rightmost(from: lchild)
        }

        var current:Node = node
        while let   parent:Node = current.parent,
                    current == parent.lchild
        {
            current = parent
        }

        return current.parent
    }

    @inline(__always)
    private static
    func rotate(_ pivot:Node, root:inout Node?, rotation:(Node) -> Node)
    {
        guard let parent:Node = pivot.parent
        else
        {
            // updates the external root variable since the root will change
            root = rotation(pivot)
            return
        }

        if pivot == parent.lchild
        {
            parent.lchild = rotation(pivot)
        }
        else
        {
            parent.rchild = rotation(pivot)
        }
    }

    private static
    func rotateLeft(_ pivot:Node, root:inout Node?)
    {
        rotate(pivot, root: &root, rotation: rotateLeft(_:))
    }

    // performs a left rotation and returns the new vertex
    private static
    func rotateLeft(_ pivot:Node) -> Node
    {
        let newVertex:Node = pivot.rchild!

        newVertex.lchild?.parent = pivot
        newVertex.parent         = pivot.parent
        pivot.parent             = newVertex

        pivot.rchild             = newVertex.lchild
        newVertex.lchild         = pivot
        return newVertex
    }

    private static
    func rotateRight(_ pivot:Node, root:inout Node?)
    {
        rotate(pivot, root: &root, rotation: rotateRight(_:))
    }

    // performs a right rotation and returns the new vertex
    private static
    func rotateRight(_ pivot:Node) -> Node
    {
        let newVertex:Node = pivot.lchild!

        newVertex.rchild?.parent = pivot
        newVertex.parent         = pivot.parent
        pivot.parent             = newVertex

        pivot.lchild             = newVertex.rchild
        newVertex.rchild         = pivot
        return newVertex
    }

    private static
    func insert(_ node:Node,
                  after predecessor:Node,
                  root:inout Node?)
    {
        guard let rchild:Node = predecessor.rchild
        else
        {
            predecessor.rchild = node
            node.parent        = predecessor
            return
        }

        let parent:Node = leftmost(from: rchild)
        parent.lchild   = node
        node.parent     = parent
        balanceInsertion(at: node, root: &root)
    }

    private static
    func balanceInsertion(at node:Node,
                             root:inout Node?)
    {
        assert(node.color == .red)
        // case 1: the node is the root. repaint the node black
        guard let parent:Node = node.parent
        else
        {
            node.color = .black
            return
        }
        // case 2: the node’s parent is black. the tree is already valid
        if parent.color == .black
        {
            return
        }
        // from here on out, the node *must* have a grandparent because its
        // parent is red which means it cannot be the root
        let grandparent:Node = parent.parent!

        // case 3: both the parent and the uncle are red. repaint both of them
        //         black and make the grandparent red. fix the grandparent.
        if let  uncle:Node  = parent == grandparent.lchild ? grandparent.rchild :
                                                             grandparent.lchild,
                uncle.color == .red
        {
            parent.color        = .black
            uncle.color         = .black

            // recursive call
            grandparent.color   = .red
            balanceInsertion(at: grandparent, root: &root)
            // swift can tail call optimize this right?
            return
        }

        // case 4: the node’s parent is red, its uncle is black, and the node is
        //         an inner child. perform a rotation on the node’s parent.
        //         then fallthrough to case 5.
        let n:Node
        if      node   == parent.rchild,
                parent == grandparent.lchild
        {
            n = parent
            grandparent.lchild = rotateLeft(parent)
        }
        else if node   == parent.lchild,
                parent == grandparent.rchild
        {
            n = parent
            grandparent.rchild = rotateRight(parent)
        }
        else
        {
            n = node
        }

        // case 5: the node’s (n)’s parent is red, its uncle is black, and the node
        //         is an outer child. rotate on the grandparent, which is known
        //         to be black, and switch its color with the former parent’s.
        assert(n.parent != nil)

        n.parent?.color   = .black
        grandparent.color = .red
        if n == n.parent?.lchild
        {
            rotateRight(grandparent, root: &root)
        }
        else
        {
            rotateLeft(grandparent, root: &root)
        }
    }

    private static
    func delete(_ node:Node,
                  root:inout Node?)
    {
        @inline(__always)
        func _replaceLink(  to node:Node,
                            with other:Node?,
                            on_parent parent:Node)
        {
            if node == parent.lchild
            {
                parent.lchild = other
            }
            else
            {
                parent.rchild = other
            }
        }

        if let       _:Node = node.lchild,
           let  rchild:Node = node.rchild
        {
            let replacement:Node = leftmost(from: rchild)

            // the replacement always lives below the node, so this shouldn’t
            // disturb any links we are modifying later
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: replacement, on_parent: parent)
            }
            else
            {
                root = replacement
            }

            // if we don’t do this check, we will accidentally double flip a link
            if node == replacement.parent
            {
                // turn the links around so they get flipped correctly in the next step
                replacement.parent = replacement
                if replacement == node.lchild
                {
                    node.lchild = node
                }
                else
                {
                    node.rchild = node
                }
            }
            else
            {
                // the replacement can never be the root, so it always has a parent
                _replaceLink(   to: replacement,
                                with: node,
                                on_parent: replacement.parent!)
            }

            // swap all container information, taking care of outgoing links
            swap(&replacement.parent, &node.parent)
            swap(&replacement.lchild, &node.lchild)
            swap(&replacement.rchild, &node.rchild)
            swap(&replacement.color , &node.color)

            // fix uplink consistency
            node.lchild?.parent        = node
            node.rchild?.parent        = node
            replacement.lchild?.parent = replacement
            replacement.rchild?.parent = replacement
        }

        if      node.color == .red
        {
            assert(node.lchild == nil && node.rchild == nil)
            // a red node cannot be the root, so it must have a parent
            _replaceLink(to: node, with: nil, on_parent: node.parent!)
        }
        else if let child:Node = node.lchild ?? node.rchild,
                    child.color == .red
        {
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: child, on_parent: parent)
            }
            else
            {
                root = child
            }

            child.parent = node.parent
            child.color  = .black
        }
        else
        {
            assert(node.lchild == nil && node.rchild == nil)

            balanceDeletion(phantom: node, root: &root)
            // the root case is checked but not handled inside the
            // balanceDeletion(phantom:root:) function
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: nil, on_parent: parent)
            }
            else
            {
                root = nil
            }
        }

        node.deallocate()
    }

    private static
    func balanceDeletion(phantom node:Node, root:inout Node?)
    {
        // case 1: node is the root. do nothing. don’t nil out the root because
        // we may be here on a recursive call
        guard let parent:Node = node.parent
        else
        {
            return
        }
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        var sibling:Node = node == parent.lchild ? parent.rchild! : parent.lchild!

        // case 2: the node’s sibling is red. (the parent must be black.)
        //         make the parent red and the sibling black. rotate on the parent.
        //         fallthrough to cases 4–6.
        if sibling.color == .red
        {
            parent.color  = .red
            sibling.color = .black
            if node == parent.lchild
            {
                rotateLeft(parent, root: &root)
            }
            else
            {
                rotateRight(parent, root: &root)
            }

            // update the sibling. the sibling must have children because it is
            // red and has a black sibling (the node we are deleting).
            sibling = node == parent.lchild ? parent.rchild! : parent.lchild!
        }
        // case 3: the parent and sibling are both black. on the first iteration,
        //         the sibling has no children or else the black property would ,
        //         not have been held. however later, the sibling may have children
        //         which must both be black. repaint the sibling red, then fix the
        //         parent.
        else if parent.color == .black,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red

            // recursive call
            balanceDeletion(phantom: parent, root: &root)
            return
        }

        // from this point on, the sibling is assumed black because of case 2
        assert(sibling.color == .black)

        // case 4: the sibling is black, but the parent is red. repaint the sibling
        //         red and the parent black.
        if      parent.color  == .red,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red
            parent.color  = .black
            return
        }
        // from this point on, the sibling is assumed to have at least one red child
        // because of cases 2–4

        // case 5: the sibling has one red inner child. (the parent’s color does
        //         not matter.) rotate on the sibling and switch its color and that
        //         of its child so that the new sibling has a red outer child.
        //         fallthrough to case 6.
        else if node == parent.lchild,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color                 = .red
            sibling.lchild!.color = .black

            // update the sibling
            sibling       = rotateRight(sibling)
            parent.rchild = sibling
        }
        else if node == parent.rchild,
                sibling.lchild?.color ?? .black == .black
        {
            sibling.color         = .red
            sibling.rchild!.color = .black

            // update the sibling
            sibling       = rotateLeft(sibling)
            parent.lchild = sibling
        }

        // case 6: the sibling has at least one red child on the outside. switch
        // the colors of the parent and the sibling, make the outer child black,
        // and rotate on the parent.
        sibling.color = parent.color
        parent.color  = .black
        if node == parent.lchild
        {
            sibling.rchild!.color = .black
            rotateLeft(parent, root: &root)
        }
        else
        {
            sibling.lchild!.color = .black
            rotateRight(parent, root: &root)
        }
    }

    // deinitializes and deallocates the node and all of its children
    private static
    func deallocate(_ node:Node?)
    {
        guard let node:Node = node
        else
        {
            return
        }
        deallocate(node.lchild)
        deallocate(node.rchild)
        node.deallocate()
    }

    // verifies that all paths in `node`’s subtree have the same black height,
    // and that `node` and all of its children satisfy the red property.
    private static
    func verify(_ node:Node?) -> Int?
    {
        guard let node:Node = node
        else
        {
            return 1
        }

        if node.color == .red
        {
            guard node.lchild?.color ?? .black == .black,
                  node.rchild?.color ?? .black == .black
            else
            {
                return nil
            }
        }

        guard let   l_height:Int = verify(node.lchild),
              let   r_height:Int = verify(node.rchild),
                    l_height == r_height
        else
        {
            return nil
        }

        return l_height + (node.color == .black ? 1 : 0)
    }
}
extension UnsafeBalancedTree where Element:Comparable
{
    // returns the inserted node
    @discardableResult
    mutating
    func insort(_ element:Element) -> Node
    {

        guard var current:Node = self.root
        else
        {
            let root:Node = Node.create(element, color: .black)
            self.root = root
            return root
        }

        let new:Node = Node.create(element)
        while true
        {
            if element < current.element
            {
                if let next:Node = current.lchild
                {
                    current = next
                }
                else
                {
                    current.lchild = new
                    break
                }
            }
            else
            {
                if let next:Node = current.rchild
                {
                    current = next
                }
                else
                {
                    current.rchild = new
                    break
                }
            }
        }

        new.parent = current
        UnsafeBalancedTree.balanceInsertion(at: new, root: &self.root)
        return new
    }

    func binarySearch(_ element:Element) -> Node?
    {
        var node:Node? = self.root
        while let current:Node = node
        {
            if element < current.element
            {
                node = current.lchild
            }
            else if element > current.element
            {
                node = current.rchild
            }
            else
            {
                return current
            }
        }

        return nil
    }
}


// tests
/*
do
{
    var rbtree:UnsafeBalancedTree<Int> = UnsafeBalancedTree()

    var _nodes:[UnsafePointer<UnsafeBalancedTree<Int>.Node>] = []
    for v in 0 ..< 12
    {
        _nodes.append(rbtree.insert(v))
    }
    //print(_nodes.map{"@\($0) : \($0.pointee)"}.joined(separator: "\n"))
    print(rbtree.find(11)?.pointee ?? "not found")
    // test the integrity of the tree by traversing it, doing it forwards and
    // backwards traverses each link forwards and backwards at least once.
    for node in _nodes.dropLast()
    {
        print(rbtree.verify())
        rbtree.delete(UnsafeMutablePointer(mutating: node))
    }

    print(rbtree.verify())
    var iterator:UnsafePointer<UnsafeBalancedTree<Int>.Node>? = rbtree.first()
    while let current:UnsafePointer<UnsafeBalancedTree<Int>.Node> = iterator
    {
        print(current.pointee.element)
        iterator = UnsafeBalancedTree.successor(of: current)
    }

    iterator = rbtree.last()
    while let current:UnsafePointer<UnsafeBalancedTree<Int>.Node> = iterator
    {
        print(current.pointee.element)
        iterator = UnsafeBalancedTree.predecessor(of: current)
    }

    rbtree.deallocate()
}
*/

// random insertion stress test
import func Glibc.clock
// not mine, i stole this from stackoverflow
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
    for n in (1 ... 100).map({ 1000 * $0 })
    {
        let time1:Int = clock()

        var state:UInt64 = 13,
            rbtree = UnsafeBalancedTree<UInt64>(),
            handle:UnsafeBalancedTree<UInt64>.Node? = nil
        for _ in 0 ..< n
        {
            state = state &* 2862933555777941757 + 3037000493
            handle = rbtree.insort(state >> 32)
        }
        assert(rbtree.verify())
        print(clock() - time1, terminator: " ")

        /*
        var iterator:UnsafePointer<UnsafeBalancedTree<UInt64>.Node>? = rbtree.first()
        while let current:UnsafePointer<UnsafeBalancedTree<UInt64>.Node> = iterator
        {
            print(current.pointee.element, current.pointee.parent ?? "nil")
            iterator = UnsafeBalancedTree.successor(of: current)
        }
        */

        state = 13
        for _ in 0 ..< n
        {
            state  = state &* 2862933555777941757 + 3037000493
            handle = rbtree.binarySearch(state >> 32)!
            rbtree.delete(handle!)
            assert(rbtree.verify())
        }

        assert(rbtree.verify())
        //print("(@ \(handle)", terminator: " ")
        rbtree.deallocate()

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
