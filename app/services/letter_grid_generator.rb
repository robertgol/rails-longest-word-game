# frozen_string_literal: true

# Generates a balanced 10-letter grid using real English letter frequencies
# Guarantees 2–5 vowels
# The average ratio of vowels to consonants in English words, based on letter frequency in general English text (including Y as a vowel), is approximately 40.2% vowels to 59.8% consonants, or about 2:3.
class LetterGridGenerator
  VOWEL_FREQUENCY = ("A" * 8 + "E" * 12 + "I" * 8 + "O" * 7 + "U" * 4 + "Y" * 2).chars.freeze

  CONSONANT_FREQUENCY = (
    "B" * 2 + "C" * 4 + "D" * 5 + "F" * 2 + "G" * 2 +
    "H" * 6 + "J" * 1 + "K" * 1 + "L" * 5 + "M" * 3 +
    "N" * 7 + "P" * 2 + "Q" * 1 + "R" * 6 + "S" * 7 +
    "T" * 9 + "V" * 1 + "W" * 3 + "X" * 1 + "Z" * 1
  ).chars.freeze

  VOWEL_COUNTS = [2, 3, 3, 3, 4, 4, 5].freeze

  def self.generate
    vowel_count = VOWEL_COUNTS.sample
    vowels = VOWEL_FREQUENCY.sample(vowel_count)
    consonants = CONSONANT_FREQUENCY.sample(10 - vowel_count)
    (vowels + consonants).shuffle
  end
end
