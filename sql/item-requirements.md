# Item Schema Requirements

## Overview
Hierarchical item management system with tagging support and automatic sequencing.

## R1: Hierarchical Structure
**Requirement:** Items must support parent-child relationships with unlimited depth.
**Design Decision:** Use self-referencing foreign key `parent_item_id` → `item_id`
**Rationale:** Standard SQL pattern for hierarchical data; enables recursive queries

### R1.1: Top-Level Items
**Requirement:** Items without parents must be supported
**Design Decision:** `parent_item_id` is nullable; NULL indicates top-level item
**Rationale:** NULL is standard SQL pattern (vs. self-referencing approach which complicates queries)

## R2: Ordered Children
**Requirement:** Items within the same parent must have explicit ordering (1..n, no gaps)
**Design Decision:** `item_seq INT NOT NULL` with `UNIQUE(parent_item_id, item_seq)`
**Rationale:** Explicit ordering allows user-defined sequence; UNIQUE constraint prevents duplicates

### R2.1: No Gaps in Sequence
**Requirement:** Deleting/moving items must not create gaps in sequence numbers
**Design Decision:** Automatic renumbering via trigger `app.renumber_items()`
**Rationale:** Maintains data integrity without application-level logic

### R2.2: Automatic Renumbering
**Operations Handled:**
- **INSERT**: Makes space by incrementing seq of existing items at/after insertion point
- **DELETE**: Closes gap by decrementing seq of items after deleted item
- **UPDATE (reorder)**: Shifts items between old and new positions
- **UPDATE (reparent)**: Closes gap in old parent, makes space in new parent

## R3: Item Content
**Requirement:** Each item must have text content
**Design Decision:** `item TEXT NOT NULL`
**Rationale:** TEXT type supports unlimited length; NOT NULL ensures data integrity

## R4: Tagging System
**Requirement:** Items can have zero or more tags; tags can apply to multiple items
**Design Decision:** Many-to-many relationship via junction table

### Schema:
```sql
app.tag (tag_id, tag)           -- Tag definitions
app.item_tag (item_id, tag_id)  -- Item-tag associations
```

**Rationale:**
- Normalized (tag names stored once)
- Supports tag management (rename, delete, statistics)
- Standard SQL pattern
- Extensible (can add tag metadata later)

## R5: Performance
**Requirement:** Efficient queries for common operations

### Indexes:
- `idx_item_parent_seq` on `(parent_item_id, item_seq)` - Fast child retrieval in order
- `idx_item_tag_tag` on `item_tag(tag_id)` - Fast "items with tag X" queries

## R6: Data Integrity
**Constraints:**
- `PRIMARY KEY` on all id columns
- `UNIQUE(parent_item_id, item_seq)` - No duplicate sequences per parent
- `UNIQUE(tag)` - No duplicate tag names
- `FOREIGN KEY` relationships with appropriate `ON DELETE CASCADE`

**Cascade Behavior:**
- Deleting item → cascades to item_tag (removes tag associations)
- Deleting tag → cascades to item_tag (removes from all items)

## Common Queries

### Get all children of item (ordered)
```sql
SELECT * FROM app.item WHERE parent_item_id = ? ORDER BY item_seq;
```

### Get top-level items (ordered)
```sql
SELECT * FROM app.item WHERE parent_item_id IS NULL ORDER BY item_seq;
```

### Get all items with tag
```sql
SELECT i.* FROM app.item i
JOIN app.item_tag it ON i.item_id = it.item_id
JOIN app.tag t ON it.tag_id = t.tag_id
WHERE t.tag = 'urgent';
```

### Get all tags for item
```sql
SELECT t.tag FROM app.tag t
JOIN app.item_tag it ON t.tag_id = it.tag_id
WHERE it.item_id = ?;
```

### Move item to different position
```sql
UPDATE app.item SET item_seq = 5 WHERE item_id = ?;
-- Trigger handles renumbering automatically
```

### Tag usage statistics
```sql
SELECT t.tag, COUNT(*) as usage_count 
FROM app.tag t
JOIN app.item_tag it ON t.tag_id = it.tag_id
GROUP BY t.tag_id, t.tag
ORDER BY usage_count DESC;
```

## Design Tradeoffs

### Why Many-to-Many Tags (Not Array)?
**Chosen:** Normalized many-to-many
**Alternative:** PostgreSQL array `TEXT[]`
**Rationale:** Arrays don't support tag metadata, statistics, or easy renaming

### Why NULL for Top-Level (Not Self-Reference)?
**Chosen:** `parent_item_id = NULL`
**Alternative:** `parent_item_id = item_id`
**Rationale:** Self-reference complicates queries (need extra filters) and insert logic (chicken-egg problem)

### Why Trigger for Renumbering (Not Application)?
**Chosen:** Database trigger
**Alternative:** Application-level logic
**Rationale:** 
- Data integrity guaranteed at DB level; works for any client
- Atomic with operations (single transaction)
- Performance: No round trips (SELECT → calculate → UPDATE); database optimizes bulk UPDATE efficiently
- Network efficiency: Renumbering logic stays in DB, reducing data transfer

