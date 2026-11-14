module Seeds
  # Fills each bound game's venue and its entries' home/away sides from a
  # generated bindings file. Like the rest of the seed replay, existing
  # different values are preserved and reported rather than overwritten.
  class GameVenueImporter
    def initialize(source:, resolver: LibraryImporter.new)
      @source = Pathname.new(source)
      @resolver = resolver
    end

    def call
      report = { updated: [], unchanged: [], conflicts: [] }
      return report unless @source.file?

      ApplicationRecord.transaction do
        JSON.parse(@source.read).fetch("games").each do |binding|
          game = resolve("Game", binding.fetch("game"))
          stadium = resolve("Stadium", binding.fetch("stadium"))
          entries = %w[home away].to_h { |side| [ side, resolve("Contestant", binding.fetch(side)) ] }
          unless entries.values.all? { |entry| entry.contest_id == game.id }
            raise LibraryImporter::Error, "Venue binding entries are not in #{binding.fetch('game')}"
          end

          changes = []
          conflicts = {}
          fill(game, :stadium, stadium, changes, conflicts)
          entries.each { |side, entry| fill(entry, :side, side, changes, conflicts) }
          if conflicts.any?
            report[:conflicts] << { code: game.entity_code, differences: conflicts }
          elsif changes.any?
            changes.each(&:save!)
            report[:updated] << game.entity_code
          else
            report[:unchanged] << game.entity_code
          end
        end
      end
      report
    end

    private

    def resolve(type, code)
      @resolver.resolve_code(type, code) || raise(LibraryImporter::MissingReference, "Missing game venue #{type}: #{code}")
    end

    def fill(record, attribute, incoming, changes, conflicts)
      current = record.public_send(attribute)
      if current.nil?
        record.public_send("#{attribute}=", incoming)
        changes << record unless changes.include?(record)
      elsif current != incoming
        label = record.is_a?(Contestant) ? "#{record.entity_code}.#{attribute}" : attribute.to_s
        conflicts[label] = { existing: describe(current), incoming: describe(incoming) }
      end
    end

    def describe(value)
      value.respond_to?(:entity_code) ? value.entity_code : value
    end
  end
end
