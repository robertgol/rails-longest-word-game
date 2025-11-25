require "open-uri"

class GamesController < ApplicationController
  def new
    @letters = LetterGridGenerator.generate
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
