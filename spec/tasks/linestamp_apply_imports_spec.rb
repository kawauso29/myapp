# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "linestamp:apply_imports rake task" do
  before do
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call
    Rails.application.load_tasks unless Rake::Task.task_defined?("linestamp:apply_imports")
  end

  let(:pending_dir) { Rails.root.join("db/seeds/linestamp/imports/pending") }
  let(:applied_dir) { Rails.root.join("db/seeds/linestamp/imports/applied") }

  after do
    # Clean up any test files
    Dir.glob(pending_dir.join("test_*.rb")).each { |f| File.delete(f) }
    Dir.glob(applied_dir.join("test_*.rb")).each { |f| File.delete(f) }
  end

  it "applies pending seed files and moves to applied/" do
    seed_content = <<~RUBY
      Linestamp::Importer.run(seed_id: "test_apply_rake") do
        upsert_brand!(slug: "rake_test_brand", character_name: "Rake", series_name: "Rake Series")
      end
    RUBY
    File.write(pending_dir.join("test_apply_rake.rb"), seed_content)

    expect { Rake::Task["linestamp:apply_imports"].invoke }.to output(/APPLIED/).to_stdout

    expect(Linestamp::Brand.find_by(slug: "rake_test_brand")).to be_present
    expect(File.exist?(applied_dir.join("test_apply_rake.rb"))).to be true
    expect(File.exist?(pending_dir.join("test_apply_rake.rb"))).to be false

    sa = Linestamp::SeedApplication.find_by(seed_id: "test_apply_rake")
    expect(sa.state).to eq("applied")
  ensure
    Rake::Task["linestamp:apply_imports"].reenable
  end

  it "skips already applied seeds" do
    Linestamp::SeedApplication.create!(seed_id: "test_skip_applied", state: "applied", applied_at: Time.current)
    seed_content = <<~RUBY
      Linestamp::Importer.run(seed_id: "test_skip_applied") do
        upsert_brand!(slug: "should_not_exist", character_name: "X", series_name: "X")
      end
    RUBY
    File.write(pending_dir.join("test_skip_applied.rb"), seed_content)

    expect { Rake::Task["linestamp:apply_imports"].invoke }.to output(/SKIP/).to_stdout
    expect(Linestamp::Brand.find_by(slug: "should_not_exist")).to be_nil
  ensure
    File.delete(pending_dir.join("test_skip_applied.rb")) if File.exist?(pending_dir.join("test_skip_applied.rb"))
    Rake::Task["linestamp:apply_imports"].reenable
  end

  it "marks failed and re-raises on error" do
    seed_content = <<~RUBY
      Linestamp::Importer.run(seed_id: "test_fail_rake") do
        upsert_research!(slug: "bad", title: "Bad", communication_themes: %w[nonexistent])
      end
    RUBY
    File.write(pending_dir.join("test_fail_rake.rb"), seed_content)

    expect { Rake::Task["linestamp:apply_imports"].invoke }.to raise_error(ArgumentError)

    sa = Linestamp::SeedApplication.find_by(seed_id: "test_fail_rake")
    expect(sa.state).to eq("failed")
    expect(sa.error_message).to include("Unknown CommunicationTheme slug")
    # File should remain in pending
    expect(File.exist?(pending_dir.join("test_fail_rake.rb"))).to be true
  ensure
    File.delete(pending_dir.join("test_fail_rake.rb")) if File.exist?(pending_dir.join("test_fail_rake.rb"))
    Rake::Task["linestamp:apply_imports"].reenable
  end
end
