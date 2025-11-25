require "open-uri"

# Put this in your GamesController (or in a helper/module)
LETTER_FREQUENCY = [
  "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", # 12× E
  "T", "T", "T", "T", "T", "T", "T", "T", "T",                   # 9× T
  "A", "A", "A", "A", "A", "A", "A", "A",                        # 8× A
  "I", "I", "I", "I", "I", "I", "I", "I",                        # 8× I
  "N", "N", "N", "N", "N", "N", "N",                             # 7× N
  "O", "O", "O", "O", "O", "O", "O",                             # 7× O
  "S", "S", "S", "S", "S", "S", "S",                             # 7× S
  "H", "H", "H", "H", "H", "H",                                  # 6× H
  "R", "R", "R", "R", "R", "R",                                  # 6× R
  "D", "D", "D", "D", "D",                                        # 5× D
  "L", "L", "L", "L", "L",                                        # 5× L
  "C", "C", "C", "C",                                            # 4× C
  "U", "U", "U", "U",                                            # 4× U
  "M", "M", "M",                                                 # 3× M
  "W", "W", "W",                                                 # 3× W
  "F", "F",                                                      # 2× F
  "G", "G",                                                      # 2× G
  "Y", "Y",                                                      # 2× Y
  "P", "P",                                                      # 2× P
  "B", "B",                                                      # 2× B
  "V",                                                          # 1× V
  "K",                                                          # 1× K
  "J",                                                          # 1× J
  "X",                                                          # 1× X
  "Q",                                                          # 1× Q
  "Z"                                                            # 1× Z
].freeze

class GamesController < ApplicationController
  def new
    @letters = LETTER_FREQUENCY.sample(10)
    @start_time = Time.now.to_i
  end

  def create
    end_time = Time.now.to_i
    letters = params[:letters].split
    answer = params[:answer].downcase.strip
    start_time = params[:start_time].to_i

    unless answer_in_letters?(answer, letters.dup)
      return redirect_to score_path(
        answer: answer,
        score: 0,
        message: "Your word uses characters that are not in the grid!"
      )
    end

    json = JSON.parse(URI.open("https://dictionary.lewagon.com/#{answer}").read)
    unless json["found"]
      return redirect_to score_path(
        answer: answer,
        score: 0,
        message: "Your word is not an english word!"
      )
    end

    time = end_time - start_time
    score = (answer.size**2) * (100.0 / time)

    redirect_to score_path(
      answer: answer,
      score: score,
      message: "Well done!"
    )
  end

  def score
    @answer = params[:answer]
    @score = params[:score]
    @message = params[:message]
  end

  private

  def answer_in_letters?(answer, letters)
    answer.chars.all? do |char|
      index = letters.index(char.upcase)
      index.nil? ? false : letters.delete_at(index)
    end
  end
end
