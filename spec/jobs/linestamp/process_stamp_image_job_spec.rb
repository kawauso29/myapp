require "rails_helper"

RSpec.describe Linestamp::ProcessStampImageJob, type: :job do
  let(:brand) { Linestamp::Brand.create!(slug: "test", character_name: "Test Brand", series_name: "Test Series") }
  let(:pack) { brand.packs.create!(series_theme: "Pack 1", position: 1, status: "in_progress") }
  let(:stamp) { pack.stamps.create!(position: 1, status: "raw_uploaded") }

  before do
    skip "ImageMagick not installed" unless imagemagick_available?

    temp = Tempfile.new(["test_green_", ".png"])
    system("convert -size 400x400 xc:'#00FF00' #{temp.path}")
    stamp.raw_image.attach(io: File.open(temp.path), filename: "test.png", content_type: "image/png")
    temp.close!
  end

  def imagemagick_available?
    system("command -v mogrify > /dev/null 2>&1") || system("command -v magick > /dev/null 2>&1")
  end

  it "processes stamp image and transitions state" do
    described_class.perform_now(stamp.id)

    stamp.reload
    expect(stamp).to be_processed
    expect(stamp.processed_image).to be_attached
  end
end
