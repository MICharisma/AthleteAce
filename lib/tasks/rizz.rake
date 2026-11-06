namespace :rizz do
  desc "Send people's names to Rizz and adopt the codes it assigns (needs rizz-client, RIZZ_ENDPOINT, RIZZ_API_TOKEN)"
  task sync_people: :environment do
    sync = RizzPersonSync.new
    counts = Hash.new(0)
    RizzPersonSync.people.find_each { |person| counts[sync.call(person).state] += 1 }
    puts RizzSync::STATES.filter_map { |state| "#{state}: #{counts[state]}" if counts[state].positive? }.join(", ").presence || "No people with athletic profiles."
  end
end
