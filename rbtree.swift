// a balanced tree which does not enforce Element to be comparable
struct BalancedTree<Element>
{
    struct Node
    {
        enum Color
        {
            case red, black
        }

        fileprivate
        var parent:UnsafeMutablePointer<Node>?,
            lchild:UnsafeMutablePointer<Node>?,
            rchild:UnsafeMutablePointer<Node>?

        let element:Element

        // arrange later to take advantage of padding space if Element produces any
        fileprivate
        var color:Color

        fileprivate
        var grandparent:UnsafeMutablePointer<Node>?
        {
            return self.parent?.pointee.parent
        }

        fileprivate
        var uncle:UnsafeMutablePointer<Node>?
        {
            guard let grandparent:UnsafeMutablePointer<Node> = self.grandparent
            else
            {
                return nil
            }

            return self.parent == grandparent.pointee.lchild ?
                grandparent.pointee.rchild : grandparent.pointee.lchild
        }

        fileprivate static
        func create(_ value:Element, color:Color = .red) -> UnsafeMutablePointer<Node>
        {
            let node = UnsafeMutablePointer<Node>.allocate(capacity: 1)
                node.initialize(to: Node(   parent: nil,
                                            lchild: nil,
                                            rchild: nil,
                                            element: value,
                                            color: color))
            return node
        }
    }

    private(set)
    var root:UnsafeMutablePointer<Node>? = nil

    // frees the tree from memory
    func destroy()
    {
        BalancedTree.destroy(self.root)
    }

    // verifies that all paths in the red-black tree have the same black height,
    // that all nodes satisfy the red property, and that the root is black
    func verify() -> Bool
    {
        return  self.root?.pointee.color ?? .black == .black &&
                BalancedTree.verify(self.root) != nil
    }

    @inline(__always)
    private
    func extreme(descent:(UnsafePointer<Node>) -> UnsafePointer<Node>)
        -> UnsafePointer<Node>?
    {
        guard let root:UnsafeMutablePointer<Node> = self.root
        else
        {
            return nil
        }

        return descent(root)
    }

    // returns the leftmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func first() -> UnsafePointer<Node>?
    {
        return self.extreme(descent: BalancedTree.leftmost(from:))
    }

    // returns the rightmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func last() -> UnsafePointer<Node>?
    {
        return self.extreme(descent: BalancedTree.rightmost(from:))
    }

    static
    func leftmost(from node:UnsafePointer<Node>) -> UnsafePointer<Node>
    {
        var leftmost:UnsafePointer<Node> = node
        while let lchild:UnsafeMutablePointer<Node> = leftmost.pointee.lchild
        {
            leftmost = UnsafePointer(lchild)
        }

        return leftmost
    }

    static
    func rightmost(from node:UnsafePointer<Node>) -> UnsafePointer<Node>
    {
        var rightmost:UnsafePointer<Node> = node
        while let rchild:UnsafeMutablePointer<Node> = rightmost.pointee.rchild
        {
            rightmost = UnsafePointer(rchild)
        }

        return rightmost
    }

    // returns the inorder successor of the node in amortized O(1) time
    static
    func successor(of node:UnsafePointer<Node>) -> UnsafePointer<Node>?
    {
        if let rchild:UnsafeMutablePointer<Node> = node.pointee.rchild
        {
            return BalancedTree.leftmost(from: rchild)
        }

        var current:UnsafePointer<Node> = node
        while let   parent:UnsafeMutablePointer<Node> = current.pointee.parent,
                    current == UnsafePointer(parent.pointee.rchild)
        {
            current = UnsafePointer(parent)
        }

        return UnsafePointer(current.pointee.parent)
    }

    // returns the inorder predecessor of the node in amortized O(1) time
    static
    func predecessor(of node:UnsafePointer<Node>) -> UnsafePointer<Node>?
    {
        if let lchild:UnsafeMutablePointer<Node> = node.pointee.lchild
        {
            return BalancedTree.rightmost(from: lchild)
        }

        var current:UnsafePointer<Node> = node
        while let   parent:UnsafeMutablePointer<Node> = current.pointee.parent,
                    current == UnsafePointer(parent.pointee.lchild)
        {
            current = UnsafePointer(parent)
        }

        return UnsafePointer(current.pointee.parent)
    }

    @inline(__always)
    private static
    func rotate(_ pivot:UnsafeMutablePointer<Node>,
                  root:inout UnsafeMutablePointer<Node>?,
                  rotation:(UnsafeMutablePointer<Node>) -> UnsafeMutablePointer<Node>)
    {
        guard let parent:UnsafeMutablePointer<Node> = pivot.pointee.parent
        else
        {
            // updates the external root variable since the root will change
            root = rotation(pivot)
            return
        }

        if pivot == parent.pointee.lchild
        {
            parent.pointee.lchild = rotation(pivot)
        }
        else
        {
            parent.pointee.rchild = rotation(pivot)
        }
    }

    private static
    func rotate_left(_ pivot:UnsafeMutablePointer<Node>) -> UnsafeMutablePointer<Node>
    {
        let new_vertex:UnsafeMutablePointer<Node> = pivot.pointee.rchild!

        new_vertex.pointee.lchild?.pointee.parent = pivot
        new_vertex.pointee.parent                 = pivot.pointee.parent
        pivot.pointee.parent                      = new_vertex

        pivot.pointee.rchild                      = new_vertex.pointee.lchild
        new_vertex.pointee.lchild                 = pivot
        return new_vertex
    }

    private static
    func rotate_left(_ pivot:UnsafeMutablePointer<Node>,
                       root:inout UnsafeMutablePointer<Node>?)
    {
        BalancedTree.rotate(pivot, root: &root, rotation: BalancedTree.rotate_left(_:))
    }

    private static
    func rotate_right(_ pivot:UnsafeMutablePointer<Node>) -> UnsafeMutablePointer<Node>
    {
        let new_vertex:UnsafeMutablePointer<Node> = pivot.pointee.lchild!

        new_vertex.pointee.rchild?.pointee.parent = pivot
        new_vertex.pointee.parent                 = pivot.pointee.parent
        pivot.pointee.parent                      = new_vertex

        pivot.pointee.lchild                      = new_vertex.pointee.rchild
        new_vertex.pointee.rchild                 = pivot
        return new_vertex
    }

    private static
    func rotate_right(_ pivot:UnsafeMutablePointer<Node>,
                        root:inout UnsafeMutablePointer<Node>?)
    {
        BalancedTree.rotate(pivot, root: &root, rotation: BalancedTree.rotate_right(_:))
    }

    private static
    func balance(on node:UnsafeMutablePointer<Node>,
                    root:inout UnsafeMutablePointer<Node>?)
    {
        assert(node.pointee.color == .red)
        // case 1: the node is the root. repaint the node black
        guard let parent:UnsafeMutablePointer<Node> = node.pointee.parent
        else
        {
            node.pointee.color = .black
            return
        }
        // case 2: the node’s parent is black. the tree is already valid
        if parent.pointee.color == .black
        {
            return
        }
        // from here on out, the node *must* have a grandparent because its
        // parent is red which means it cannot be the root
        let grandparent:UnsafeMutablePointer<Node> = node.pointee.grandparent!

        // case 3: both the parent and the uncle are red. repaint both of them
        //         black and make the grandparent red. fix the grandparent.
        if let  uncle:UnsafeMutablePointer<Node> = node.pointee.uncle,
                uncle.pointee.color == .red
        {
            parent.pointee.color            = .black
            uncle.pointee.color             = .black

            // recursive call
            grandparent.pointee.color       = .red
            BalancedTree.balance(on: grandparent, root: &root)
            // swift can tail call optimize this right?
            return
        }

        // case 4: the node’s parent is red, its uncle is black, and the node is
        //         an inner child. perform a rotation on the node’s parent.
        //         then fallthrough to case 5.
        let n:UnsafeMutablePointer<Node>
        if      node   == parent.pointee.rchild,
                parent == grandparent.pointee.lchild
        {
            n = parent
            grandparent.pointee.lchild = BalancedTree.rotate_left(parent)
        }
        else if node   == parent.pointee.lchild,
                parent == grandparent.pointee.rchild
        {
            n = parent
            grandparent.pointee.rchild = BalancedTree.rotate_right(parent)
        }
        else
        {
            n = node
        }

        // case 5: the node’s (n)’s parent is red, its uncle is black, and the node
        //         is an outer child. rotate on the grandparent, which is known
        //         to be black, and switch its color with the former parent’s.
        assert(n.pointee.parent != nil)

        n.pointee.parent?.pointee.color = .black
        grandparent.pointee.color       = .red
        if n == n.pointee.parent?.pointee.lchild
        {
            BalancedTree.rotate_right(grandparent, root: &root)
        }
        else
        {
            BalancedTree.rotate_left(grandparent, root: &root)
        }
    }

    mutating
    func delete(_ node:UnsafeMutablePointer<Node>)
    {
        BalancedTree.delete(node, root: &self.root)
    }

    private static
    func delete(_ node:UnsafeMutablePointer<Node>,
                  root:inout UnsafeMutablePointer<Node>?)
    {
        @inline(__always)
        func _replace_link( to node:UnsafeMutablePointer<Node>,
                            with other:UnsafeMutablePointer<Node>?,
                            on_parent parent:UnsafeMutablePointer<Node>)
        {
            if node == parent.pointee.lchild
            {
                parent.pointee.lchild = other
            }
            else
            {
                parent.pointee.rchild = other
            }
        }

        if let       _:UnsafeMutablePointer<Node> = node.pointee.lchild,
           let  rchild:UnsafeMutablePointer<Node> = node.pointee.rchild
        {
            let replacement = UnsafeMutablePointer<Node>(mutating:
                                        BalancedTree.leftmost(from: rchild))

            // the replacement always lives below the node, so this shouldn’t
            // disturb any links we are modifying later
            if let parent:UnsafeMutablePointer<Node> = node.pointee.parent
            {
                _replace_link(to: node, with: replacement, on_parent: parent)
            }
            else
            {
                root = replacement
            }

            // if we don’t do this check, we will accidentally double flip a link
            if node == replacement.pointee.parent
            {
                // turn the links around so they get flipped correctly in the next step
                replacement.pointee.parent = replacement
                if replacement == node.pointee.lchild
                {
                    node.pointee.lchild = node
                }
                else
                {
                    node.pointee.rchild = node
                }
            }
            else
            {
                // the replacement can never be the root, so it always has a parent
                _replace_link(  to: replacement,
                                with: node,
                                on_parent: replacement.pointee.parent!)
            }

            // swap all container information, taking care of outgoing links
            swap(&replacement.pointee.parent, &node.pointee.parent)
            swap(&replacement.pointee.lchild, &node.pointee.lchild)
            swap(&replacement.pointee.rchild, &node.pointee.rchild)
            swap(&replacement.pointee.color , &node.pointee.color)

            // fix uplink consistency
            node.pointee.lchild?.pointee.parent        = node
            node.pointee.rchild?.pointee.parent        = node
            replacement.pointee.lchild?.pointee.parent = replacement
            replacement.pointee.rchild?.pointee.parent = replacement
        }

        if      node.pointee.color == .red
        {
            assert(node.pointee.lchild == nil && node.pointee.rchild == nil)
            // a red node cannot be the root, so it must have a parent
            _replace_link(to: node, with: nil, on_parent: node.pointee.parent!)
        }
        else if let child:UnsafeMutablePointer<Node> = node.pointee.lchild ?? node.pointee.rchild,
                    child.pointee.color == .red
        {
            if let parent:UnsafeMutablePointer<Node> = node.pointee.parent
            {
                _replace_link(to: node, with: child, on_parent: parent)
            }
            else
            {
                root = child
            }

            child.pointee.parent = node.pointee.parent
            child.pointee.color  = .black
        }
        else
        {
            assert(node.pointee.lchild == nil && node.pointee.rchild == nil)

            BalancedTree.balance_deletion(phantom: node, root: &root)
            // the root case is handled inside the
            // BalancedTree.balance_deletion(phantom:root:) function
            if let parent:UnsafeMutablePointer<Node> = node.pointee.parent
            {
                _replace_link(to: node, with: nil, on_parent: parent)
            }
        }

        node.deinitialize(count: 1)
        node.deallocate(capacity: 1)
    }

    private static
    func balance_deletion(phantom node:UnsafeMutablePointer<Node>,
                                  root:inout UnsafeMutablePointer<Node>?)
    {
        // case 1: node is the root. do nothing (the entire tree has been deleted)
        guard let parent:UnsafeMutablePointer<Node> = node.pointee.parent
        else
        {
            root = nil
            return
        }
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        var sibling:UnsafeMutablePointer<Node>    = node == parent.pointee.lchild ?
                                                    parent.pointee.rchild! :
                                                    parent.pointee.lchild!
        // case 2: the node’s sibling is red. (the parent must be black.)
        //         make the parent red and the sibling black. rotate on the parent.
        //         fallthrough to cases 4–6.
        if sibling.pointee.color == .red
        {
            parent.pointee.color  = .red
            sibling.pointee.color = .black
            if node == parent.pointee.lchild
            {
                BalancedTree.rotate_left(parent, root: &root)
            }
            else
            {
                BalancedTree.rotate_right(parent, root: &root)
            }

            // update the sibling. the sibling must have children because it is
            // red and has a black sibling (the node we are deleting).
            sibling   = node == parent.pointee.lchild ?
                        parent.pointee.rchild! :
                        parent.pointee.lchild!
        }
        // case 3: the parent and sibling are both black. on the first iteration,
        //         the sibling has no children or else the black property would ,
        //         not have been held. however later, the sibling may have children
        //         which must both be black. repaint the sibling red, then fix the
        //         parent.
        else if parent.pointee.color  == .black,
                sibling.pointee.lchild?.pointee.color ?? .black == .black,
                sibling.pointee.rchild?.pointee.color ?? .black == .black
        {
            sibling.pointee.color = .red

            // recursive call
            BalancedTree.balance_deletion(phantom: parent, root: &root)
            return
        }

        // from this point on, the sibling is assumed black because of case 2
        assert(sibling.pointee.color == .black)

        // case 4: the sibling is black, but the parent is red. repaint the sibling
        //         red and the parent black.
        if      parent.pointee.color  == .red,
                sibling.pointee.lchild?.pointee.color ?? .black == .black,
                sibling.pointee.rchild?.pointee.color ?? .black == .black
        {
            sibling.pointee.color = .red
            parent.pointee.color  = .black
            return
        }
        // from this point on, the sibling is assumed to have at least one red child
        // because of cases 2–4

        // case 5: the sibling has one red inner child. (the parent’s color does
        //         not matter.) rotate on the sibling and switch its color and that
        //         of its child so that the new sibling has a red outer child.
        //         fallthrough to case 6.
        else if node == parent.pointee.lchild,
                sibling.pointee.rchild?.pointee.color ?? .black == .black
        {
            sibling.pointee.color                 = .red
            sibling.pointee.lchild!.pointee.color = .black

            // update the sibling
            sibling               = BalancedTree.rotate_right(sibling)
            parent.pointee.rchild = sibling
        }
        else if node == parent.pointee.rchild,
                sibling.pointee.lchild?.pointee.color ?? .black == .black
        {
            sibling.pointee.color                 = .red
            sibling.pointee.rchild!.pointee.color = .black

            // update the sibling
            sibling               = BalancedTree.rotate_left(sibling)
            parent.pointee.lchild = sibling
        }

        // case 6: the sibling has at least one red child on the outside. switch
        // the colors of the parent and the sibling, make the outer child black,
        // and rotate on the parent.
        sibling.pointee.color = parent.pointee.color
        parent.pointee.color  = .black
        if node == parent.pointee.lchild
        {
            sibling.pointee.rchild!.pointee.color = .black
            BalancedTree.rotate_left(parent, root: &root)
        }
        else
        {
            sibling.pointee.lchild!.pointee.color = .black
            BalancedTree.rotate_right(parent, root: &root)
        }
    }

    // deinitializes and deallocates the node and all of its children
    private static
    func destroy(_ node:UnsafeMutablePointer<Node>?)
    {
        guard let node:UnsafeMutablePointer<Node> = node
        else
        {
            return
        }
        BalancedTree.destroy(node.pointee.lchild)
        BalancedTree.destroy(node.pointee.rchild)
        node.deinitialize(count: 1)
        node.deallocate(capacity: 1)
    }

    // verifies that all paths in `node`’s subtree have the same black height,
    // and that `node` and all of its children satisfy the red property.
    private static
    func verify(_ node:UnsafeMutablePointer<Node>?) -> Int?
    {
        guard let node:UnsafeMutablePointer<Node> = node
        else
        {
            return 1
        }

        if node.pointee.color == .red
        {
            guard node.pointee.lchild?.pointee.color ?? .black == .black,
                  node.pointee.rchild?.pointee.color ?? .black == .black
            else
            {
                return nil
            }
        }

        guard let   l_height:Int = BalancedTree.verify(node.pointee.lchild),
              let   r_height:Int = BalancedTree.verify(node.pointee.rchild),
                    l_height == r_height
        else
        {
            return nil
        }

        return l_height + (node.pointee.color == .black ? 1 : 0)
    }
}
extension BalancedTree where Element:Comparable
{
    // returns the inserted node
    @discardableResult
    mutating
    func insert(_ element:Element) -> UnsafePointer<Node>
    {

        guard var current:UnsafeMutablePointer<Node> = self.root
        else
        {
            let root:UnsafeMutablePointer<Node> = Node.create(element, color: .black)
            self.root = root
            return UnsafePointer(root)
        }

        let new:UnsafeMutablePointer<Node> = Node.create(element)
        while true
        {
            if element < current.pointee.element
            {
                if let next:UnsafeMutablePointer<Node> = current.pointee.lchild
                {
                    current = next
                }
                else
                {
                    current.pointee.lchild = new
                    break
                }
            }
            else
            {
                if let next:UnsafeMutablePointer<Node> = current.pointee.rchild
                {
                    current = next
                }
                else
                {
                    current.pointee.rchild = new
                    break
                }
            }
        }

        new.pointee.parent = current
        BalancedTree.balance(on: new, root: &self.root)
        return UnsafePointer(new)
    }
}


// tests
do
{
    var rbtree:BalancedTree<Int> = BalancedTree()

    var _nodes:[UnsafePointer<BalancedTree<Int>.Node>] = []
    for v in 0 ..< 12
    {
        _nodes.append(rbtree.insert(v))
    }
    print(_nodes.map{"@\($0) : \($0.pointee)"}.joined(separator: "\n"))

    // test the integrity of the tree by traversing it, doing it forwards and
    // backwards traverses each link forwards and backwards at least once.
    for node in _nodes.dropLast()
    {
        print(rbtree.verify())
        rbtree.delete(UnsafeMutablePointer(mutating: node))
    }

    print(rbtree.verify())
    var iterator:UnsafePointer<BalancedTree<Int>.Node>? = rbtree.first()
    while let current:UnsafePointer<BalancedTree<Int>.Node> = iterator
    {
        print(current.pointee.element)
        iterator = BalancedTree.successor(of: current)
    }

    iterator = rbtree.last()
    while let current:UnsafePointer<BalancedTree<Int>.Node> = iterator
    {
        print(current.pointee.element)
        iterator = BalancedTree.predecessor(of: current)
    }

    rbtree.destroy()
}
