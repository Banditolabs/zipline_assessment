require 'csv'
require_relative 'disjoint_set'  
require 'pry'

# RecordMatcher reads a CSV and assigns user IDs to records that match by email and/or phone.
class RecordMatcher

  def initialize(match_type, file_path )
    @file_path = file_path
    @match_type = match_type.to_sym
    @records = load_csv(file_path)
    detect_email_and_phone_fields
  end

  def match
    normalize_records!
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
  # - phones are stripped of all non-digit characters
  def normalize_records!
    @records.each do |record|
      @email_fields.each do |key|
        record[key] = record[key]&.strip&.downcase
      end
      @phone_fields.each do |key|
        record[key] = record[key]&.gsub(/\D/, "")
      end
    end
  end

  def assign_user_ids!
    # DisjointSet helps group records that are directly or indirectly connected.
    # For example: if A matches B, and B matches C, then A, B, and C belong to the same group.
    ds = DisjointSet.new

    # Map object IDs to their corresponding record hashes for later assignment
    record_ids = {}
    @records.each { |record| record_ids[record.object_id] = record }

    # Index each normalized email or phone value → list of records that share it
    value_to_records = Hash.new { |h, k| h[k] = [] }

    # extract any email or phone values, remove nil values
    @records.each do |record|
      emails = @email_fields.map { |field| record[field] }.compact
      phones = @phone_fields.map { |field| record[field] }.compact

      # Populate the hash based on the selected match type; byEmail: value_to_records = { "john@example.com"   => [{rowData}, {rowData}], }
      case @match_type
      when :email
        emails.each { |email| value_to_records[email] << record }
      when :phone
        phones.each { |phone| value_to_records[phone] << record }
      when :email_or_phone
        (emails + phones).each { |val| value_to_records[val] << record }
      else
        raise ArgumentError, "Unsupported match type: #{@match_type}. [email|phone|email_or_phone]"
      end
    end

    # Union records that share the same matching value
    value_to_records.each_value do |group|
      next if group.size < 2
      # For every pair in the group, mark them as connected in the disjoint set
      group.combination(2).each do |a, b|
        ds.union(a.object_id, b.object_id)
      end
    end

     # Assign user_id to each connected group of records
    groups = ds.groups
    groups.each_with_index do |group, idx|
      user_id = idx + 1
      group.each do |oid|
        record_ids[oid][:user_id] = user_id  # {:firstname => "john", :email=>"john@example.com", :user_id=>1}
      end
    end
  end

  def write_output_file
    # Create a new filename based on the original
    output_path = @file_path.sub(/\.csv$/, "_with_user_ids.csv")

    # Normalize the original CSV headers to match the internal format
    normalized_keys = @raw_headers.map { |h| h.strip.downcase.gsub(/\s+/, "_").to_sym }
    headers = [:user_id] + normalized_keys

    CSV.open(output_path, "w") do |csv|
      # Write the header row using original column names
      csv << ['user_id'] + @raw_headers
      # This ensures we preserve original column order and values.
      @records.each do |r|
        csv << headers.map { |h| r[h] }
      end
    end

    puts "Wrote output to #{output_path}"
  end
end