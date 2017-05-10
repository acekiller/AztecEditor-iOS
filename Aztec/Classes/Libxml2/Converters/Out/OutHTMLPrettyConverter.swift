import Foundation
import libxml2


// MARK: - HTML Prettifier!
//
extension Libxml2.Out {
    class HTMLPrettyConverter: Converter {

        typealias Attribute         = Libxml2.Attribute
        typealias StringAttribute   = Libxml2.StringAttribute
        typealias ElementNode       = Libxml2.ElementNode
        typealias Node              = Libxml2.Node
        typealias TextNode          = Libxml2.TextNode
        typealias CommentNode       = Libxml2.CommentNode
        typealias RootNode          = Libxml2.RootNode


        // MARK: - Initializers

        init() {
            // No Op
        }

        /// Converts a Node into it's HTML String Representation
        ///
        func convert(_ rawNode: Node) -> String {
            return export(node: rawNode)
                .replacingOccurrences(of: "<\(RootNode.name)>", with: "")
                .replacingOccurrences(of: "</\(RootNode.name)>", with: "")
                .trimmingCharacters(in: CharacterSet.newlines)
        }
    }
}


// MARK: - Export: Nodes
//
private extension Libxml2.Out.HTMLPrettyConverter {

    /// Serializes a Node into it's HTML String Representation
    ///
    func export(node: Node) -> String {
        switch node {
        case let node as CommentNode:
            return export(comment: node)
        case let node as ElementNode:
            return export(element: node)
        case let node as TextNode:
            return export(text: node)
        default:
            fatalError("We're missing support for a node type.  This should not happen.")
        }
    }

    /// Serializes a CommentNode into it's HTML String Representation
    ///
    private func export(comment node: CommentNode) -> String {
        return "<!--" + node.comment + "-->"
    }

    /// Serializes an ElementNode into it's HTML String Representation
    ///
    private func export(element node: ElementNode) -> String {
        var attributes = ""
        for attribute in node.attributes {
            attributes += String(.space) + export(attribute: attribute)
        }

        let prefixForOpeningTag = requiresOpeningTagPrefixNewline(node) ? String(.newline) : ""
        let prefixForClosingTag = requiresClosingTagPrefixNewline(node) ? String(.newline) : ""
        let posfixForClosingTag = requiresClosingTagPosfixNewline(node) ? String(.newline) : ""

        var html = prefixForOpeningTag + "<" + node.name + attributes + ">"

        guard requiresClosingTag(node) else {
            return html
        }

        for child in node.children {
            html += export(node: child)
        }

        html += prefixForClosingTag + "</" + node.name + ">" + posfixForClosingTag

        return html
    }

    /// Serializes a TextNode into it's HTML String Representation
    ///
    private func export(text node: TextNode) -> String {
        return node.text().escapeHtmlEntities().encodeUnicodeCharactersAsHexadecimal()
    }

    /// OpeningTag Prefix Newline: Required whenever the node is a blocklevel element
    ///
    private func requiresOpeningTagPrefixNewline(_ node: ElementNode) -> Bool {
        return node.isBlockLevelElement()
    }

    /// ClosingTag Prefix Newline: Required whenever one of the children is a blocklevel element
    ///
    private func requiresClosingTagPrefixNewline(_ node: ElementNode) -> Bool {
        return node.children.contains { child in
            let elementChild = child as? ElementNode
            return elementChild?.isBlockLevelElement() == true
        }
    }

    /// ClosingTag Posfix Newline: Required whenever the node is blocklevel, and the right sibling is not
    ///
    private func requiresClosingTagPosfixNewline(_ node: ElementNode) -> Bool {
        guard let rightSibling = node.rightSibling() else {
            return false
        }

        return !rightSibling.isBlockLevelElement() && node.isBlockLevelElement()
    }

    /// Indicates if an ElementNode is a Void Element (expected not to have a closing tag), or not.
    ///
    private func requiresClosingTag(_ node: ElementNode) -> Bool {
        return Constants.voidElements.contains(node.name) == false
    }
}


// MARK: - Export: Attributes
//
private extension Libxml2.Out.HTMLPrettyConverter {

    /// Serializes an Attribute into it's corresponding String Value, depending on the actual Attribute subclass.
    ///
    func export(attribute: Attribute) -> String {
        switch attribute {
        case let stringAttribute as StringAttribute where !isBooleanAttribute(name: attribute.name):
            return export(stringAttribute: stringAttribute)
        default:
            return export(rawAttribute: attribute)
        }
    }

    /// Serializes a given StringAttribute.
    ///
    private func export(stringAttribute attribute: StringAttribute) -> String {
        return attribute.name + "=\"" + attribute.value + "\""
    }

    /// Serializes a given Attribute
    ///
    private func export(rawAttribute: Attribute) -> String {
        return rawAttribute.name
    }

    /// Indicates whether if an Attribute is expected to have a value, or not.
    ///
    private func isBooleanAttribute(name: String) -> Bool {
        return Constants.booleanAttributes.contains(name)
    }
}


// MARK: - Private Constants
//
private extension Libxml2.Out.HTMLPrettyConverter {

    struct Constants {

        /// List of 'Void Elements', that are expected *not* to have a closing tag.
        ///
        /// Ref. http://w3c.github.io/html/syntax.html#void-elements
        ///
        static let voidElements = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link",
                                   "meta", "param", "source", "track", "wbr"]

        /// List of Boolean Attributes, that are not expected to have an actual value
        ///
        static let booleanAttributes = ["checked", "compact", "declare", "defer", "disabled", "ismap",
                                        "multiple", "nohref", "noresize", "noshade", "nowrap", "readonly",
                                        "selected"]
    }
}
