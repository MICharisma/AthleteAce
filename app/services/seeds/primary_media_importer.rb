module Seeds
  class PrimaryMediaImporter
    def initialize source:
      @source = Pathname.new source
    end

    def call
      report = { updated: [], unchanged: [], conflicts: [] }
      return report unless @source.file?

      importer = LibraryImporter.new
      JSON.parse(@source.read).fetch("selections").each do |selection|
        type = selection.fetch "type"
        code = selection.fetch "code"
        attribute, target_type = type == "Figure" ? [:primary_portrait, "AssetRepresentation"] : [:primary_logo, "Logo"]
        raise "Unsupported media owner #{type}" unless %w[Figure Sport League Conference Division Team].include? type
        owner = importer.resolve_code(type, code) || raise("Missing media owner #{code}")
        target = importer.resolve_code(target_type, selection.fetch("asset")) || raise("Missing media #{selection.fetch('asset')}")
        owner.with_lock do
          current = owner.public_send attribute
          if current == target
            report[:unchanged] << code
          elsif current
            report[:conflicts] << { code: code, existing: current.entity_code, incoming: target.entity_code }
          else
            owner.update! attribute => target
            report[:updated] << code
          end
        end
      end
      report
    end
  end
end
