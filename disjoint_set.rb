# This data structure is for efficiently grouping elements
# based on shared values like emails or phone numbers.
class DisjointSet

  def initialize
    @user_map = {}
  end

  # This method does two things:
  # - Looks up the group leader (aka “root”) for this record
  # - Compresses the path from the record_id to it's root_id. 80:180, rather than 80:100:120:...
  def find(record_id)
    @user_map[record_id] ||= record_id

    if @user_map[record_id] != record_id
      @user_map[record_id] = find(@user_map[record_id]) 
    end
    @user_map[record_id]
  end

  # This joins two groups together by making the root of group A point to the root of group B.
  # If A shares a value with B, and B shares with C, then A and C are connected.
  def union(record_id_a, record_id_b)
    root_a = find(record_id_a)
    root_b = find(record_id_b)

    @user_map[root_a] = root_b
  end

  # Use the recursive "find" method to find the root object_id.
  # If that root ID lives in our map's keys, the record_id is added to the list of associates.
  def groups
    grouped_records = Hash.new { |hash, root_id| hash[root_id] = [] } 
    @user_map.keys.each do |record_id|
      root = find(record_id)
      grouped_records[root] << record_id # {180=>[80, 180]}
    end

    grouped_records.values
  end
end
