namespace :rizz do
  desc "Send figure names to Rizz and adopt the codes it assigns (needs rizz-client, RIZZ_ENDPOINT, RIZZ_API_TOKEN)"
  task sync_figures: :environment do
    sync = RizzFigureSync.new
    counts = Hash.new(0)
    RizzFigureSync.figures.find_each { |figure| counts[sync.call(figure).state] += 1 }
    puts RizzSync::STATES.filter_map { |state| "#{state}: #{counts[state]}" if counts[state].positive? }.join(", ").presence || "No figures with athletic profiles."
  end

  desc "Adopt Rizz place codes for countries, states and cities, keeping AthleteAce's codes as aliases (needs rizz-client, RIZZ_ENDPOINT, RIZZ_API_TOKEN)"
  task sync_places: :environment do
    outcomes = RizzPlaceSync.new.call
    outcomes.group_by { |outcome| outcome.record.class.name }.each do |model, group|
      puts "#{model}: " + group.group_by(&:state).map { |state, items| "#{state} #{items.size}" }.join(", ")
    end
    outcomes.reject { |outcome| %w[adopted unchanged].include?(outcome.state) }.each do |outcome|
      puts "  #{outcome.state} #{outcome.record.class.name} #{outcome.record.id} #{outcome.record.entity_code}: #{outcome.detail}"
    end
  end
end
