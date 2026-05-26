namespace :linestamp do
  desc "Apply pending seed imports from db/seeds/linestamp/imports/pending/"
  task apply_imports: :environment do
    require "digest"
    require "fileutils"

    pending_dir = Rails.root.join("db/seeds/linestamp/imports/pending")
    applied_dir = Rails.root.join("db/seeds/linestamp/imports/applied")

    files = Dir.glob(pending_dir.join("*.rb")).sort
    if files.empty?
      puts "No pending imports found."
      next
    end

    puts "Found #{files.size} pending import(s)."

    files.each do |path|
      filename = File.basename(path)
      seed_id = filename.sub(/\.rb\z/, "")
      file_sha = Digest::SHA256.hexdigest(File.read(path))

      app = Linestamp::SeedApplication.find_or_initialize_by(seed_id: seed_id)
      if app.applied?
        puts "  SKIP (already applied): #{filename}"
        next
      end

      app.assign_attributes(file_path: path, file_sha256: file_sha, state: "pending")
      app.save!

      begin
        importer = nil
        ActiveRecord::Base.transaction do
          importer = eval(File.read(path), TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
        end
        summary = importer.is_a?(Linestamp::Importer) ? importer.summary.inspect : "OK"
        app.mark_applied!(summary: summary)
        FileUtils.mv(path, applied_dir.join(filename))
        puts "  APPLIED: #{filename} => #{summary}"
      rescue => e # rubocop:disable Style/RescueStandardError
        app.mark_failed!(error: "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
        puts "  FAILED: #{filename} => #{e.message}"
        raise
      end
    end
  end
end
