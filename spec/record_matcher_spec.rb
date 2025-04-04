require "csv"
require "fileutils"
require_relative "../record_matcher.rb"

RSpec.describe RecordMatcher do
  let(:tmp_dir) { File.expand_path("tmp", __dir__) }

  before do
    FileUtils.mkdir_p(tmp_dir)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  def write_csv(filename, headers, rows)
    CSV.open(filename, "w") do |csv|
      csv << headers
      rows.each do |row|
        padded_row = row + Array.new(headers.length - row.length, "")
        csv << padded_row
      end
    end
  end

  def read_output(file_path)
    CSV.read(file_path, headers: true).map(&:to_h)
  end

  it "uses MATCH_STRATEGIES[:email] to group records by shared email values" do
    path = File.join(tmp_dir, "emails.csv")
    write_csv(path, ["FirstName", "Email1"], [
      ["John", "john@example.com"],
      ["Jane", "john@example.com"],
      ["Alice", "alice@example.com"]
    ])

    matcher = RecordMatcher.new("email", path)
    matcher.match

    output = read_output(path.sub(".csv", "_with_user_ids.csv"))

    expect(output[0]["user_id"]).to eq("1")
    expect(output[1]["user_id"]).to eq("1")
    expect(output[2]["user_id"]).to be_nil
  end

  it "uses MATCH_STRATEGIES[:phone] to group records by shared phone numbers" do
    path = File.join(tmp_dir, "phones.csv")
    write_csv(path, ["FirstName", "Phone1"], [
      ["Bob", "(555) 123-4567"],
      ["Sue", "5551234567"],
      ["Max", "999-999-9999"]
    ])

    matcher = RecordMatcher.new("phone", path)
    matcher.match

    output = read_output(path.sub(".csv", "_with_user_ids.csv"))

    expect(output[0]["user_id"]).to eq("1")
    expect(output[1]["user_id"]).to eq("1")
    expect(output[2]["user_id"]).to be_nil
  end

  it "uses MATCH_STRATEGIES[:email_or_phone] to group records by either value" do
    path = File.join(tmp_dir, "email_or_phone.csv")
    write_csv(path, ["FirstName", "Email1", "Phone1"], [
      ["John", "john@example.com", "1234567890"],
      ["Jane", "", "1234567890"],
      ["Jill", "john@example.com", ""],
      ["Alice", "alice@example.com", "9999999999"]
    ])

    matcher = RecordMatcher.new("email_or_phone", path)
    matcher.match

    output = read_output(path.sub(".csv", "_with_user_ids.csv"))

    expect(output[0]["user_id"]).to eq("1")
    expect(output[1]["user_id"]).to eq("1")
    expect(output[2]["user_id"]).to eq("1")
    expect(output[3]["user_id"]).to be_nil
  end

  it "normalizes phone numbers before matching" do
    path = File.join(tmp_dir, "normalize.csv")
    write_csv(path, ["FirstName", "Phone1"], [
      ["John", "(123) 456-7890"],
      ["Jane", "123.456.7890"],
      ["Jack", "1234567890"]
    ])

    matcher = RecordMatcher.new("phone", path)
    matcher.match

    output = read_output(path.sub(".csv", "_with_user_ids.csv"))
    user_ids = output.map { |row| row["user_id"] }.uniq.compact

    expect(user_ids.size).to eq(1)
  end

  it "matches records using any email_or_phone column" do
    path = File.join(tmp_dir, "multi_column.csv")
    write_csv(path, ["FirstName", "Email1", "Email2", "Phone1", "Phone2"], [
      ["John", "", "shared@example.com", "", ""],
      ["Jane", "shared@example.com", "", "", ""],
      ["Alice", "", "", "1234567890", ""],
      ["Bob", "", "", "", "1234567890"]
    ])

    matcher = RecordMatcher.new("email_or_phone", path)
    matcher.match
    
    output = read_output(path.sub(".csv", "_with_user_ids.csv"))
    expect(output[0]["user_id"]).to eq("1")
    expect(output[1]["user_id"]).to eq("1")
    expect(output[2]["user_id"]).to eq("2")
    expect(output[3]["user_id"]).to eq("2")
  end

  it "raises an error for unsupported match types" do
    path = File.join(tmp_dir, "invalid.csv")
    write_csv(path, ["FirstName", "Email1"], [["Test", "test@example.com"]])

    expect {
      RecordMatcher.new("unsupported", path).match
    }.to raise_error(ArgumentError)
  end
end
