## Inspector

An in-game tool to inspect node and item parameters and metadata.

### Node Information

Nodes are inspected through the use of an inspector tool. Click on any node with this tool and it will pop up a form showing a variety of information for it, separated into several categories.

"Node data" includes the basic map database parameters for that location.

"Meta" lists all of the metadata associated with the node, including inventory.

"Nodedef" lists the properties of the registered definition for this node. Lines that begin with a "`->`" are properties that have been explicitly defined for this node, lines without an "`->`" are inherited default values that were not explicitly defined in this node def.

### Item information

Items in your inventory can be similarly inspected. The chat command "`/inspect_item`" will bring up a form with your player inventory at the bottom and a single inventory slot to the right. Place an itemstack you wish to inspect into this field (either by dragging or shift-clicking) and the item's information will be displayed.

Items have simpler data sets than nodes.

"Count" is the number of items in the itemstack.

"Meta" is the item's metadata. Metadata belonging to an empty string key (`[""]`) represents the value of the deprecated `ItemStack:set_metadata()` and `get_metadata()` methods. Item metadata doesn't include any inventories.

"Itemdef" lists the properties of the registered definition for this item. As with the nodedef, properties marked with "`->`" were explicitly defined for this item's definition and lines without are inherited defaults.