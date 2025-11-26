require "open-uri"

class GamesController < ApplicationController
  def new
    @letters = LetterGridGenerator.generate
    @start_time = Time.now.to_i
    WordFinder.for_letters(@letters.join)
  end

  def create
    end_time = Time.now.to_i
    letters = params[:letters].split
    answer = params[:answer].downcase.strip
    start_time = params[:start_time].to_i

    word_finder = WordFinder.for_letters(letters.join)

    unless answer_in_letters?(answer, letters.dup)
      return redirect_to score_path(
        answer: answer,
        score: 0,
        message: "Your word uses characters that were not in the grid!",
        letters: letters
      )
    end

    unless word_finder.valid?(answer)
      return redirect_to score_path(
        answer: answer,
        score: 0,
        message: "Your word is not an english word!",
        letters: letters
      )
    end

    time = [end_time - start_time, 1].max
    score = ((answer.size**2) * (100.0 / time)).to_i

    redirect_to score_path(
      answer: answer,
      score: score,
      message: "Well done!",
      letters: letters
    )
  end

  def score
    @answer = params[:answer]
    @score = params[:score]
    @message = params[:message]
    @letters = params[:letters]
    @words = WordFinder.for_letters(@letters.join).all
  end

  private

  def answer_in_letters?(answer, letters)
    answer.chars.all? do |char|
      index = letters.index(char.upcase)
      index.nil? ? false : letters.delete_at(index)
    end
  end
end
