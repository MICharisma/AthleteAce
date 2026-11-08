# The player names games show. With Rizz on, that is the name Rizz authorizes
# (Figure#display_name), and a player Rizz has no name for is left out of
# games, since a neutral label can't be an answer.
#
# Rounds save their questions, names included, when they start, and answers
# are checked by ID. Questions that reviews and missed-name drills reuse from
# earlier rounds get current names before they are asked again.
module GameNames
  module_function

  # The players a game may name.
  def playable(scope)
    return scope unless RizzNames.enabled?

    withheld = RizzName.where(purpose: "referring").where("state <> 'current' OR display_name IS NULL").select(:figure_id)
    scope.where.not(figure_id: withheld)
  end

  # Saved or new questions with current player names. A question whose
  # subject or answer is a player Rizz now withholds is dropped, and so is a
  # withheld player among the choices. A changed name is scrambled afresh.
  def refresh(questions)
    questions = questions.map(&:deep_stringify_keys)
    ids = questions.flat_map { player_ids(it) }.uniq
    players = Player.where(id: ids).includes(figure: :rizz_names).index_by(&:id)
    questions.filter_map { refresh_question(it, players) }
  end

  def refresh_question(question, players)
    if question["subject_type"] == "Player"
      subject = players[question["subject_id"]]
      return if subject.nil? || subject.name_withheld?

      changed = question["subject_name"] != subject.display_name
      question["subject_name"] = subject.display_name
      question["scrambled_name"] = NameCipherRound.scramble(subject.display_name) if changed && question.key?("scrambled_name")
    end
    if question["target_type"] == "Player"
      target = players[question["target_id"]]
      return if target.nil? || target.name_withheld?

      question["target_name"] = target.display_name
      question["choices"] = question.fetch("choices").filter_map do |choice|
        player = players[choice["id"]]
        choice.merge("name" => player.display_name) if player && !player.name_withheld?
      end
      return if question["choices"].size < 2
    end
    question
  end

  def player_ids(question)
    ids = []
    ids << question["subject_id"] if question["subject_type"] == "Player"
    if question["target_type"] == "Player"
      ids << question["target_id"]
      ids.concat Array(question["choices"]).map { it["id"] }
    end
    ids
  end
end
