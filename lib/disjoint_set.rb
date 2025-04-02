# This data structure for efficiently grouping elements
# into non-overlapping sets and determining connected components.
# In this app, it's used to find all records that belong to the same matching group
# based on shared values like emails or phone numbers.
class DisjointSet

  def initialize
    # Maps each element to its parent in the tree.
    @parent_map = {}
  end

  def find(record_id)
    # If record_id has no parent, set it as its own parent
    @parent_map[record_id] ||= record_id

    # If not the root, recursively find the root and compress the path
    if @parent_map[record_id] != record_id
      @parent_map[record_id] = find(@parent_map[record_id]) 
    end
    @parent_map[record_id]
  end

  # Union two sets by connecting their roots.
  def union(record_id_a, record_id_b)
    root_a = find(record_id_a)
    root_b = find(record_id_b)

    # Merge root_a's set into root_b's set
    @parent_map[root_a] = root_b
  end

  def groups
    grouped_records = Hash.new { |hash, root_id| hash[root_id] = [] } # {180=>[80]}
    
    @parent_map.keys.each do |record_id|
      root = find(record_id)
      grouped_records[root] << record_id
    end

    # Return an array of groups, where each group is an array of connected record_ids.
    grouped_records.values
  end
end
