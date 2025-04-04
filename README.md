# Record Matcher

This command-line Ruby program reads a CSV file and identifies rows that may represent the **same person** based on one or more **matching criteria** (email, phone, or both). It then writes a new output file that includes a `user_id` column used to group matching individuals.

---

## How to Run

The program is executed from the command line like so:

```
ruby record_matcher.rb <matching_type> <input_filename.csv>
```

### Running Tests and Debugging

This project uses [RSpec](https://rspec.info/) for testing. To run the test suite:

```bash
bundle install
bundle exec rspec
```

To debug any part of this code, you can insert the following line:

```bash
binding.pry
```

### Examples

```
ruby record_matcher.rb email input1.csv
ruby record_matcher.rb phone input2.csv
ruby record_matcher.rb email_or_phone input3.csv
```

Matching types can only be entered exactly **email**, **phone**, **email_or_phone**.

---

## Supported Matching Types

Matching types define the logic used to compare rows:

| Input            | Matching Logic                                       |
| ---------------- | ---------------------------------------------------- |
| `email`          | Matches if any email field matches                   |
| `phone`          | Matches if any phone field matches                   |
| `email_or_phone` | Matches if **either** any email or any phone matches |

---

## Input CSV Format

The program accepts any CSV file that includes:

- One or more **email fields** (e.g., `Email1`, `EmailWork`, etc.)
- One or more **phone fields** (e.g., `Phone1`, `PhoneMobile`, etc.)
- Any other columns (name, address, etc.) are preserved in the output

Headers are automatically detected based on whether they contain the word "email" or "phone".

---

## Output

- A **new CSV file** is created — the original input is **not modified**
- The output file is named like: `input1_with_user_ids.csv`
- A `user_id` column is **prepended** to indicate matched groups
- Only records that matched at least one other row will receive a `user_id`; unmatched records will have an empty value

---

## Sample Output

Given:

```
FirstName,Phone1,Phone2,Email1,Email2
John,1234567890,,john@example.com,
Jane,1234567890,,jane@something.com,
Alice,,,john@example.com,
```

The `phone_or_email` output will be:

```
user_id,FirstName,Phone1,Phone2,Email1,Email2
1,John,1234567890,,john@example.com,
1,Jane,1234567890,,jane@something.com,
1,Alice,,,john@example.com,
```

All three users are grouped under `user_id` 1 because of overlapping phone/email matches.

---

## Guidelines & Expectations

- Do **not** overwrite the original CSV
- Do **not** publicly fork the repo (clone and push to a private one instead)
- Keep dependencies minimal — core Ruby only
- Code should be clean, readable, and consistent

---

## Scoring Guide

### Running the Program

- Does this run from command line as instructed?
- Does it run without errors?

### Implement Matching Types

- Can it match on a single column?
- Do similar columns match to one another?
- Are you able to use multiple matchers?

### Output

- Is there a csv file?
- Are there IDs prepended to each row?

### Code Quality

- Is it readable?
- Is it consistent?
