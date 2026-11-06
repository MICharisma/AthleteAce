namespace :rizz do
  desc "Send figure names to Rizz and adopt the codes it assigns (needs rizz-client, RIZZ_ENDPOINT, RIZZ_API_TOKEN)"
  task sync_figures: :environment do
    sync = RizzFigureSync.new
    counts = Hash.new(0)
    RizzFigureSync.figures.find_each { |figure| counts[sync.call(figure).state] += 1 }
    puts RizzSync::STATES.filter_map { |state| "#{state}: #{counts[state]}" if counts[state].positive? }.join(", ").presence || "No figures with athletic profiles."
  end
end
