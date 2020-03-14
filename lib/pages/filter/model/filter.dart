import 'package:flutter/foundation.dart';

/// Filter represented in the form of a tree with named levels
///
///                                  All
///                    _______________|_______________
///                  /                                \
///                BSc                               MSc       // Degree
///         ________|________                 ________|__ ...
///       /                  \              /     |
///      IS                 CTI            IA   SPRC ...       // Specialization
///   ...|...          ______|______       ⋮      ⋮
///                  /    |     |   \
///               CTI-1 CTI-2 CTI-3 CTI-4                      // Year
///                  ⋮    ⋮   __|... ⋮
///                        /   |
///                     3-CA 3-CB ...                          // Series
///                     __|...
///                   /   |
///               331CA 332CA ...                              // Group
class Filter {
  /// Tree structure for filter.
  ///
  /// **Note:** No two nodes should have the same name.
  FilterNode root;

  /// Name of each level of the tree.
  ///
  /// **Note:** There should be at least as many names as there are levels in the tree.
  List<Map<String, String>> localizedLevelNames;

  Filter({this.root, this.localizedLevelNames, void Function() listener}) {
    this.root.value = true;  // root value is true by default
    _addListener(listener ?? () {}, this.root);
  }

  static _addListener(void Function() listener, FilterNode node) {
    node._valueNotifier.addListener(listener);
    if (node.children != null) {
      for (var child in node.children) {
        _addListener(listener, child);
      }
    }
  }

  void _relevantNodesHelper(List<String> list, FilterNode node) {
    if (node.value) {
      if (node.children != null) {
        node.children
            .forEach((child) => this._relevantNodesHelper(list, child));
      }
      list.add(node.name);
    }
  }

  /// Get the names of all nodes with `value = true`.
  List<String> get relevantNodes {
    List<String> list = [];
    _relevantNodesHelper(list, root);
    return list;
  }

  bool _setRelevantHelper(String nodeName, FilterNode node, bool setParents) {
    if (node.name == nodeName) {
      node.value = true;
      return true;
    }

    bool found = false;
    if (node.children != null) {
      node.children.forEach(
          (child) => found |= _setRelevantHelper(nodeName, child, setParents));
    }

    // Also set the node's parents if `setParents` is `true`
    if (setParents && found) {
      node.value = true;
    }
    return found;
  }

  /// Set the value of node with name [nodeName] and its parents to `true`.
  bool setRelevantUpToRoot(String nodeName) {
    if (nodeName != null) {
      return _setRelevantHelper(nodeName, root, true);
    }
    return false;
  }

  bool setRelevantNodes(List<String> nodes) {
    if(nodes == null || nodes.isEmpty) {
      return false;
    }
    bool setAllNodes = true;
    nodes.forEach(
        (node) => setAllNodes &= _setRelevantHelper(node, root, false));
    return setAllNodes;
  }
}

class FilterNode {
  /// Name of node
  final String name;

  /// Whether (at least one) child should be included in the results
  ValueNotifier _valueNotifier;

  /// Children of node
  final List<FilterNode> children;

  FilterNode({this.name = '', bool value, this.children})
      : this._valueNotifier = ValueNotifier(value ?? false);

  get value => _valueNotifier.value;

  set value(bool value) => _valueNotifier.value = value;
}