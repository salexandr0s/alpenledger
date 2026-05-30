#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CATALOG_PATH="$REPO_ROOT/config/fixture-catalog.json"

ruby - "$REPO_ROOT" "$CATALOG_PATH" <<'RUBY'
require "digest"
require "csv"
require "json"
require "set"

repo_root = ARGV.fetch(0)
catalog_path = ARGV.fetch(1)
failures = []

def fail_with(failures, message)
  failures << message
end

def verify_ech_fixture(failures, id, full_path, standard, namespace, root_element)
  xml = File.read(full_path)
  fail_with(failures, "#{standard} fixture #{id} does not start with XML declaration") unless xml.start_with?("<?xml")
  fail_with(failures, "#{standard} fixture #{id} missing namespace #{namespace}") unless xml.include?("xmlns:#{standard}=\"#{namespace}\"")
  fail_with(failures, "#{standard} fixture #{id} missing root #{root_element}") unless xml.include?("<#{standard}:#{root_element}")
  fail_with(failures, "#{standard} fixture #{id} missing standard marker") unless xml.include?("<#{standard}:standard>#{standard}</#{standard}:standard>")
  fail_with(failures, "#{standard} fixture #{id} missing 2026 tax year") unless xml.include?("<#{standard}:taxYear>2026</#{standard}:taxYear>")
  fail_with(failures, "#{standard} fixture #{id} missing CHF amount evidence") unless xml.include?('currency="CHF"')
end

unless File.file?(catalog_path)
  abort("Missing fixture catalog: #{catalog_path}")
end

catalog = JSON.parse(File.read(catalog_path))
unless catalog["schemaVersion"] == 1
  fail_with(failures, "fixture catalog schemaVersion must be 1")
end

%w[reviewedAt reviewedBy policyDoc requiredPacks fixtures].each do |key|
  value = catalog[key]
  if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    fail_with(failures, "fixture catalog missing #{key}")
  end
end

policy_doc = File.join(repo_root, catalog.fetch("policyDoc", ""))
fail_with(failures, "fixture policy doc is missing: #{catalog["policyDoc"]}") unless File.file?(policy_doc)

fixtures = catalog.fetch("fixtures", [])
required_packs = catalog.fetch("requiredPacks", [])
seen_ids = Set.new
seen_paths = Set.new
seen_packs = Set.new
project_yml = File.read(File.join(repo_root, "project.yml"))

fixtures.each do |fixture|
  id = fixture["id"]
  path = fixture["path"]
  pack = fixture["pack"]
  format = fixture["format"]
  sha256 = fixture["sha256"]

  %w[id path pack format purpose sha256 coverageTests].each do |key|
    value = fixture[key]
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      fail_with(failures, "fixture #{id || path || "<unknown>"} missing #{key}")
    end
  end

  unless fixture["synthetic"] == true
    fail_with(failures, "fixture #{id} must declare synthetic: true")
  end
  unless fixture["containsPersonalData"] == false
    fail_with(failures, "fixture #{id} must declare containsPersonalData: false")
  end

  fail_with(failures, "duplicate fixture id: #{id}") unless seen_ids.add?(id)
  fail_with(failures, "duplicate fixture path: #{path}") unless seen_paths.add?(path)
  seen_packs.add(pack)

  if path.nil? || path.start_with?("Fixtures/") == false || path.include?("..")
    fail_with(failures, "fixture #{id} path must stay under Fixtures/: #{path.inspect}")
    next
  end

  full_path = File.join(repo_root, path)
  unless File.file?(full_path)
    fail_with(failures, "fixture #{id} file is missing: #{path}")
    next
  end

  fail_with(failures, "fixture #{id} is empty: #{path}") if File.size(full_path).zero?
  actual_sha = Digest::SHA256.file(full_path).hexdigest
  if actual_sha != sha256
    fail_with(failures, "fixture #{id} hash drifted: expected #{sha256}, got #{actual_sha}")
  end

  if fixture["appResource"] == true && project_yml.include?("path: #{path}") == false
    fail_with(failures, "app fixture #{id} is not registered as a project.yml resource")
  end

  case format
  when "csv"
    header = File.open(full_path, &:readline).strip
    expected_header = "booking_date,value_date,amount,currency,counterparty,memo,reference,balance"
    fail_with(failures, "CSV fixture #{id} has unexpected header: #{header}") unless header == expected_header
    if pack == "customer-scale-bank-statement"
      rows = CSV.read(full_path, headers: true)
      fail_with(failures, "customer-scale CSV fixture #{id} must contain at least 2,500 data rows") if rows.length < 2_500
      counterparties = rows.map { |row| row["counterparty"].to_s }.uniq
      fail_with(failures, "customer-scale CSV fixture #{id} must cover at least 80 counterparties") if counterparties.length < 80
      currencies = rows.map { |row| row["currency"].to_s }.uniq
      fail_with(failures, "customer-scale CSV fixture #{id} must stay CHF-only") unless currencies == ["CHF"]
    end
  when "pdf"
    magic = File.open(full_path, "rb") { |file| file.read(4) }
    fail_with(failures, "PDF fixture #{id} does not start with %PDF") unless magic == "%PDF"
  when "text-tax-fixture"
    text = File.read(full_path)
    fail_with(failures, "tax text fixture #{id} missing document_type") unless text.include?("document_type:")
    fail_with(failures, "tax text fixture #{id} missing tax_year") unless text.include?("tax_year:")
  when "json-expected-tax-facts"
    facts = JSON.parse(File.read(full_path))
    unless facts.is_a?(Array) && facts.any?
      fail_with(failures, "expected tax facts fixture #{id} must be a non-empty array")
    end
    facts.each_with_index do |fact, index|
      %w[conceptCode valueType].each do |key|
        fail_with(failures, "expected tax fact #{id}[#{index}] missing #{key}") if fact[key].to_s.empty?
      end
      if fact["valueType"] == "money"
        fail_with(failures, "money tax fact #{id}[#{index}] missing moneyMinor") unless fact.key?("moneyMinor")
        fail_with(failures, "money tax fact #{id}[#{index}] missing currency") if fact["currency"].to_s.empty?
      end
    end
  when "json-business-tax-export-readiness"
    fixture = JSON.parse(File.read(full_path))
    fail_with(failures, "business tax export fixture #{id} schemaVersion must be 1") unless fixture["schemaVersion"] == 1
    %w[jurisdiction taxYear entityKind exportFormat sourceFixtureRefs requiredConceptCodes blockingIssues warnings expectedSummary].each do |key|
      fail_with(failures, "business tax export fixture #{id} missing #{key}") unless fixture.key?(key)
    end
    fail_with(failures, "business tax export fixture #{id} must target CH-ZH") unless fixture["jurisdiction"] == "CH-ZH"
    fail_with(failures, "business tax export fixture #{id} must target tax year 2026") unless fixture["taxYear"] == 2026
    fail_with(failures, "business tax export fixture #{id} must target soleProprietor") unless fixture["entityKind"] == "soleProprietor"
    fail_with(failures, "business tax export fixture #{id} must use draft review export format") unless fixture["exportFormat"] == "business-tax-draft-review"
    unless fixture["sourceFixtureRefs"].is_a?(Array) && fixture["sourceFixtureRefs"].include?("bank.sample_statement.csv.v1")
      fail_with(failures, "business tax export fixture #{id} must reference the bank-statement input fixture")
    end
    required = fixture["requiredConceptCodes"]
    expected_concepts = %w[
      personal.self_employment.revenue_gross
      personal.self_employment.expense_total
      personal.self_employment.net_profit
    ]
    fail_with(failures, "business tax export fixture #{id} has unexpected required concepts") unless required == expected_concepts
    summary = fixture["expectedSummary"] || {}
    %w[revenueGrossMinor expenseTotalMinor netProfitMinor currency].each do |key|
      fail_with(failures, "business tax export fixture #{id} summary missing #{key}") unless summary.key?(key)
    end
  when "json-personal-tax-export-readiness"
    fixture = JSON.parse(File.read(full_path))
    fail_with(failures, "personal tax export fixture #{id} schemaVersion must be 1") unless fixture["schemaVersion"] == 1
    %w[jurisdiction taxYear entityKind exportFormat sourceFixtureRefs requiredConceptCodes blockingIssues warnings expectedSummary].each do |key|
      fail_with(failures, "personal tax export fixture #{id} missing #{key}") unless fixture.key?(key)
    end
    fail_with(failures, "personal tax export fixture #{id} must target CH-ZH") unless fixture["jurisdiction"] == "CH-ZH"
    fail_with(failures, "personal tax export fixture #{id} must target tax year 2026") unless fixture["taxYear"] == 2026
    fail_with(failures, "personal tax export fixture #{id} must target naturalPerson") unless fixture["entityKind"] == "naturalPerson"
    fail_with(failures, "personal tax export fixture #{id} must use draft review export format") unless fixture["exportFormat"] == "personal-tax-draft-review"
    source_refs = fixture["sourceFixtureRefs"]
    unless source_refs.is_a?(Array) && source_refs.include?("tax.zh.2026.expected_facts.json.v1")
      fail_with(failures, "personal tax export fixture #{id} must reference the expected personal tax facts fixture")
    end
    required = fixture["requiredConceptCodes"]
    expected_concepts = %w[
      personal.income.salary_gross
      personal.deduction.health_insurance_premiums
      personal.deduction.pillar3a_contributions
      personal.readiness.has_salary_certificate
      personal.readiness.has_health_insurance_certificate
      personal.readiness.has_pillar3a_certificate
    ]
    fail_with(failures, "personal tax export fixture #{id} has unexpected required concepts") unless required == expected_concepts
    summary = fixture["expectedSummary"] || {}
    %w[salaryGrossMinor healthInsurancePremiumsMinor pillar3aContributionsMinor currency].each do |key|
      fail_with(failures, "personal tax export fixture #{id} summary missing #{key}") unless summary.key?(key)
    end
  when "json-vat-period-fixture"
    fixture = JSON.parse(File.read(full_path))
    unless fixture["schemaVersion"] == 1
      fail_with(failures, "VAT fixture #{id} schemaVersion must be 1")
    end
    %w[jurisdiction rulesetVersion period transactions expected].each do |key|
      value = fixture[key]
      if value.nil? || (value.respond_to?(:empty?) && value.empty?)
        fail_with(failures, "VAT fixture #{id} missing #{key}")
      end
    end
    period = fixture["period"] || {}
    %w[start end currency].each do |key|
      fail_with(failures, "VAT fixture #{id} period missing #{key}") if period[key].to_s.empty?
    end
    unless fixture["transactions"].is_a?(Array) && fixture["transactions"].any?
      fail_with(failures, "VAT fixture #{id} must include transactions")
    end
    fixture.fetch("transactions", []).each_with_index do |transaction, index|
      %w[id bookingDate amountMinor currency counterpartyName memo taxCode].each do |key|
        fail_with(failures, "VAT fixture #{id} transaction #{index} missing #{key}") if transaction[key].to_s.empty?
      end
    end
    expected = fixture["expected"] || {}
    %w[lineCount outputTaxMinor inputTaxMinor netTaxPayableMinor issueCount].each do |key|
      fail_with(failures, "VAT fixture #{id} expected missing #{key}") unless expected.key?(key)
    end
  when "ech-0217-vat-export.xml"
    xml = File.read(full_path)
    fail_with(failures, "eCH-0217 VAT export fixture #{id} does not start with XML declaration") unless xml.start_with?("<?xml")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing VATDeclaration root") unless xml.include?("eCH-0217:VATDeclaration")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing eCH-0217 v2 namespace") unless xml.include?('xmlns:eCH-0217="http://www.ech.ch/xmlns/eCH-0217/2"')
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing generalInformation") unless xml.include?("<eCH-0217:generalInformation>")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing turnoverComputation") unless xml.include?("<eCH-0217:turnoverComputation>")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing effectiveReportingMethod") unless xml.include?("<eCH-0217:effectiveReportingMethod>")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing payableTax") unless xml.include?("<eCH-0217:payableTax>")
    fail_with(failures, "eCH-0217 VAT export fixture #{id} missing normalized synthetic UID") unless xml.include?("<eCH-0217:uid>CHE123456789</eCH-0217:uid>")
  when "ech-0196-tax-statement.xml"
    verify_ech_fixture(failures, id, full_path, "eCH-0196", "http://www.ech.ch/xmlns/eCH-0196/2", "eTaxStatement")
  when "ech-0248-pension-certificate.xml"
    verify_ech_fixture(failures, id, full_path, "eCH-0248", "http://www.ech.ch/xmlns/eCH-0248/1", "pensionContributionCertificate")
  when "ech-0275-health-insurance-certificate.xml"
    verify_ech_fixture(failures, id, full_path, "eCH-0275", "http://www.ech.ch/xmlns/eCH-0275/1", "healthInsuranceTaxCertificate")
  when "camt.052.xml"
    xml = File.read(full_path)
    fail_with(failures, "CAMT fixture #{id} does not start with XML declaration") unless xml.start_with?("<?xml")
    fail_with(failures, "CAMT fixture #{id} missing BkToCstmrAcctRpt") unless xml.include?("BkToCstmrAcctRpt")
    fail_with(failures, "CAMT fixture #{id} missing camt.052 namespace/version marker") unless xml.include?("camt.052")
    fail_with(failures, "CAMT fixture #{id} missing report entry") unless xml.include?("<Ntry>")
    fail_with(failures, "CAMT fixture #{id} missing CHF amount") unless xml.include?('Amt Ccy="CHF"')
  when "camt.053.xml"
    xml = File.read(full_path)
    fail_with(failures, "CAMT fixture #{id} does not start with XML declaration") unless xml.start_with?("<?xml")
    fail_with(failures, "CAMT fixture #{id} missing BkToCstmrStmt") unless xml.include?("BkToCstmrStmt")
    fail_with(failures, "CAMT fixture #{id} missing camt.053 namespace/version marker") unless xml.include?("camt.053")
    fail_with(failures, "CAMT fixture #{id} missing statement entry") unless xml.include?("<Ntry>")
    fail_with(failures, "CAMT fixture #{id} missing CHF amount") unless xml.include?('Amt Ccy="CHF"')
  when "camt.054.xml"
    xml = File.read(full_path)
    fail_with(failures, "CAMT fixture #{id} does not start with XML declaration") unless xml.start_with?("<?xml")
    fail_with(failures, "CAMT fixture #{id} missing BkToCstmrDbtCdtNtfctn") unless xml.include?("BkToCstmrDbtCdtNtfctn")
    fail_with(failures, "CAMT fixture #{id} missing camt.054 namespace/version marker") unless xml.include?("camt.054")
    fail_with(failures, "CAMT fixture #{id} missing notification entry") unless xml.include?("<Ntry>")
    fail_with(failures, "CAMT fixture #{id} missing CHF amount") unless xml.include?('Amt Ccy="CHF"')
  when "text-qr-bill-fixture"
    lines = File.read(full_path).lines.map(&:strip)
    fail_with(failures, "QR-bill fixture #{id} missing Swiss QR-code marker") unless lines[0] == "SPC"
    fail_with(failures, "QR-bill fixture #{id} missing supported version") unless lines[1]&.start_with?("02")
    fail_with(failures, "QR-bill fixture #{id} missing synthetic account placeholder") unless lines.include?("SYNTHETIC-QR-ACCOUNT")
    fail_with(failures, "QR-bill fixture #{id} missing CHF currency") unless lines.include?("CHF")
    fail_with(failures, "QR-bill fixture #{id} missing QRR reference type") unless lines.include?("QRR")
    fail_with(failures, "QR-bill fixture #{id} is too short for structured address extraction") if lines.length < 24
  else
    fail_with(failures, "fixture #{id} has unsupported format: #{format}")
  end

  if %w[csv text-tax-fixture json-expected-tax-facts json-business-tax-export-readiness json-personal-tax-export-readiness json-vat-period-fixture ech-0217-vat-export.xml ech-0196-tax-statement.xml ech-0248-pension-certificate.xml ech-0275-health-insurance-certificate.xml camt.052.xml camt.053.xml camt.054.xml text-qr-bill-fixture].include?(format)
    text = File.read(full_path)
    personal_patterns = {
      "email" => /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
      "swiss_iban" => /\bCH\d{2}[A-Z0-9]{17}\b/,
      "ahv_number" => /\b756[.\s-]?\d{4}[.\s-]?\d{4}[.\s-]?\d{2}\b/,
      "phone_number" => /(?:\+41|0041)\s?\d{2}\s?\d{3}\s?\d{2}\s?\d{2}/
    }
    personal_patterns.each do |label, pattern|
      fail_with(failures, "fixture #{id} appears to contain #{label}") if text.match?(pattern)
    end
  end
end

fixture_files = Dir.glob(File.join(repo_root, "Fixtures", "**", "*"))
  .select { |path| File.file?(path) }
  .map { |path| path.delete_prefix("#{repo_root}/") }
  .reject { |path| File.basename(path) == ".DS_Store" }
  .sort

unregistered = fixture_files - seen_paths.to_a
missing_files = seen_paths.to_a - fixture_files
fail_with(failures, "unregistered fixture file(s): #{unregistered.join(", ")}") unless unregistered.empty?
fail_with(failures, "catalog references missing fixture file(s): #{missing_files.join(", ")}") unless missing_files.empty?

required_packs.each do |pack|
  fail_with(failures, "required fixture pack has no fixtures: #{pack}") unless seen_packs.include?(pack)
end

if failures.any?
  warn failures.map { |failure| "Fixture verification failed: #{failure}" }.join("\n")
  exit 1
end

puts "Fixture catalog verification passed."
RUBY
