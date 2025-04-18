require 'csv'
require 'pry'

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

# RecordMatcher reads a CSV and assigns user IDs to records that match by email and/or phone.
class RecordMatcher

  # I implemented this lambda table in order to allow for a scalable solution to filters.
  # Arguments are always fed values from the csv; "matcher" is defined as the correct lambda.
  MATCH_STRATEGIES = {
    email: ->(emails, phone_numbers) { emails },
    phone: ->(emails, phone_numbers) { phone_numbers },
    email_or_phone: ->(emails, phone_numbers) { emails + phone_numbers }
  }

  def initialize(match_type, file_path )
    @file_path = file_path
    @match_type = match_type.to_sym
    @records = load_csv(file_path)
    detect_email_and_phone_fields
  end

  def match
    normalize_record_values!
    assign_user_ids!
    write_output_file
  end

  private

  # Headers are normalized:
  # - leading/trailing whitespace removed
  # - downcased
  # - internal spaces replaced with underscores
  # - converted to symbols
  def load_csv(file_path)
    @raw_headers = CSV.open(file_path, &:readline)
    CSV.read(file_path, headers: true).map do |row|
      row.to_h.transform_keys { |key| key.strip.downcase.gsub(/\s+/, "_").to_sym }
    end
  end

  # Dynamically detect which CSV columns represent email and phone fields
  # by checking if the column name contains "email" or "phone" (case-insensitive)
  def detect_email_and_phone_fields
    all_keys = @records.first.keys
    @email_fields = all_keys.select { |k| k.to_s.downcase.include?("email") }
    @phone_fields = all_keys.select { |k| k.to_s.downcase.include?("phone") }
  end

  # Normalize all phone and email values:
  # - emails are downcased and stripped
  # - phone_numbers are stripped of all non-digit characters
  def normalize_record_values!
    @records.each do |record|
      @email_fields.each do |key|
        record[key] = record[key]&.strip&.downcase
      end
      @phone_fields.each do |key|
        record[key] = record[key]&.gsub(/\D/, "")
      end
    end
  end

  # Assigns user IDs to grouped records based on shared values (email, phone, or both).
  # Uses a DisjointSet to connect records that share any normalized matching value.
  # - Extract matching values from each record based on the match type.
  # - Group records that share a value into the same connected component.
  # - Assign a unique user ID to each connected group.
  def assign_user_ids!
    ds = DisjointSet.new

    record_ids = {}
    @records.each { |record| record_ids[record.object_id] = record }

    rows_by_value = Hash.new { |h, k| h[k] = [] }

    matcher = MATCH_STRATEGIES[@match_type]
    raise ArgumentError, "Unsupported match type: #{@match_type}" unless matcher

    @records.each do |record|
      emails = @email_fields.map { |field| record[field] }.compact
      phone_numbers = @phone_fields.map { |field| record[field] }.compact
  
      matcher.call(emails, phone_numbers).each do |val|
        next if val.nil? || val.strip.empty?
        rows_by_value[val] << record
      end
    end

    rows_by_value.each_value do |related_rows|
      next if related_rows.size < 2
      related_rows.combination(2).each do |a, b|
        ds.union(a.object_id, b.object_id)
      end
    end

    related_object_id_list = ds.groups
    related_object_id_list.each_with_index do |group, idx|
      user_id = idx + 1
      group.each do |oid|
        record_ids[oid][:user_id] = user_id  # {:firstname => "john", :email=>"john@example.com", :user_id=>1}
      end
    end
  end

  def write_output_file
    output_path = @file_path.sub(/\.csv$/, "_with_user_ids.csv")

    normalized_keys = @raw_headers.map { |h| h.strip.downcase.gsub(/\s+/, "_").to_sym }
    headers = [:user_id] + normalized_keys

    CSV.open(output_path, "w") do |csv|
      csv << ['user_id'] + @raw_headers
      @records.each do |r|
        csv << headers.map { |h| r[h] }
      end
    end

    puts "Wrote output to #{output_path}"
  end
end

# Expect exactly two command-line arguments in order:
# - a match type (email, phone, or email_or_phone)
# - a CSV file path
if __FILE__ == $0
  if ARGV.length != 2
    puts "Usage: ruby record_matcher.rb [email|phone|email_or_phone] path/to/file.csv"
    exit 1
  end

  match_type, file_path = ARGV
  matcher = RecordMatcher.new(match_type, file_path)
  matcher.match
end
