namespace :shots do
  desc "Upload unassigned sample portraits from the three fictional player folders"
  task import_samples: :environment do
    root = Pathname.new ENV.fetch("PORTRAIT_DIR")
    sports = %w[baseball football hockey]
    files = sports.to_h do |sport|
      [sport, root.glob("fictional_#{sport}_players/*.png").sort]
    end
    abort "Expected five PNG portraits per sport in #{root}." unless files.values.all? { |paths| paths.size == 5 }

    created = 0
    files.each do |sport, paths|
      paths.each do |path|
        checksum = Digest::MD5.file(path).base64digest
        tags = ["sample", "portrait", sport]
        next if Shot.tagged("sample").tagged(sport).joins(image_attachment: :blob)
          .exists?(active_storage_blobs: { checksum: checksum })

        path.open("rb") do |file|
          Shot.create!(tags: tags, image: { io: file, filename: path.basename.to_s, content_type: "image/png" })
        end
        created += 1
      end
    end
    puts "Added #{created} of #{files.values.sum(&:size)} sample shots."
  end
end
