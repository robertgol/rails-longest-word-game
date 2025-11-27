# app/services/word_finder.rb
#
# WordFinder finds all valid words that can be formed from a given set of 10 letters.
# Uses character frequency matching to determine if a word can be formed.
#
# Usage in a game:
#
#   finder = WordFinder.for_letters("gardenpils")
#   finder.valid?("gardenias")        # => true
#   finder.valid?("pizza")            # => false
#   finder.longest                    # => ["gardenias", "panelised", ...]
#   finder.longest_length             # => 9
#   finder.all                        # => all valid words (sorted longest first)
#
class WordFinder
  WORD_LIST_PATH = Rails.root.join("lib/assets/words.txt").freeze
  CACHE_KEY = "word_finder/normalized_words_v2".freeze
  CACHE_EXPIRES = 7.days
  INSTANCE_CACHE_EXPIRES = 1.hour

  # Get or create a WordFinder instance for the given letters
  # Uses Rails cache to store pre-computed word lists, so the same letter combination
  # will reuse cached results instead of recalculating.
  #
  # @param letters [String] exactly 10 letters (case-insensitive, non-alphabetic chars removed)
  # @return [WordFinder] instance for these letters
  # @raise [ArgumentError] if letters length is not exactly 10 after normalization
  def self.for_letters(letters)
    normalized = normalize_letters(letters)

    # Validate length before checking cache
    raise ArgumentError, "Exactly 10 letters required" if normalized.length != 10

    # Create cache key from normalized letters (sorted for consistency)
    # Same letters in different order should use same cache
    cache_key = "word_finder/instance/#{normalized.chars.sort.join}"

    # Try to get cached word list
    cached_data = Rails.cache.read(cache_key)

    if cached_data
      # Reconstruct instance from cache
      from_cache(normalized, cached_data)
    else
      # Create new instance and cache it
      instance = new(normalized)
      Rails.cache.write(
        cache_key,
        {
          words: instance.all,
          letter_counts: instance.instance_variable_get(:@letter_counts),
          score_multiplier: instance.score_multiplier
        },
        expires_in: INSTANCE_CACHE_EXPIRES
      )
      instance
    end
  end

  # Create a new game instance with 10 letters
  # Use WordFinder.for_letters instead of calling new directly to benefit from caching
  #
  # @param letters [String] exactly 10 letters (case-insensitive, non-alphabetic chars removed)
  # @raise [ArgumentError] if letters length is not exactly 10 after normalization
  def initialize(letters)
    @letters = WordFinder.normalize_letters(letters)
    @letter_counts = @letters.chars.tally

    raise ArgumentError, "Exactly 10 letters required" if @letters.length != 10

    build_word_set!
  end

  # Check if a submitted word is valid
  # @param word [String] word to validate
  # @return [Boolean] true if word can be formed from the letters
  def valid?(word)
    clean_word = word.to_s.downcase.gsub(/[^a-z]/, "")
    clean_word.present? && @valid_words_set.include?(clean_word)
  end

  # All valid words, sorted longest first
  # @return [Array<String>] sorted array of valid words
  def all
    @sorted_words
  end

  # Just the longest ones (could be multiple)
  # @return [Array<String>] array of longest valid words
  def longest
    return [] if @sorted_words.empty?

    longest_length = @sorted_words.first.length
    @sorted_words.take_while { |w| w.length == longest_length }
  end

  # Length of the longest possible word(s)
  # @return [Integer] length of longest word, or 0 if no words found
  def longest_length
    @sorted_words.first&.length || 0
  end

  # Total number of valid words found
  # @return [Integer] count of valid words
  def total_count
    @valid_words_set.size
  end

  # Calculate the difficulty-based score multiplier for this letter set.
  # The multiplier accounts for both word count and scoring potential (word lengths).
  # Harder sets (fewer words, shorter words) get higher multipliers.
  #
  # This value is cached with the instance to avoid recalculating.
  #
  # @return [Float] score multiplier (typically 0.7 to 1.8)
  # @example
  #   finder = WordFinder.for_letters("gardenpils")
  #   multiplier = finder.score_multiplier  # => 1.32
  #   base_score = (answer.size**2) * (100.0 / time)
  #   final_score = (base_score * multiplier).to_i
  def score_multiplier
    @score_multiplier ||= ScoreMultiplier.calculate(@sorted_words)
  end

  private

  # Normalize letters: lowercase, remove non-alphabetic characters
  # @param letters [String] input letters
  # @return [String] normalized letters
  def self.normalize_letters(letters)
    letters.to_s.downcase.gsub(/[^a-z]/, "")
  end

  # Reconstruct instance from cached data
  # @param letters [String] normalized letters
  # @param cached_data [Hash] hash with :words and :letter_counts keys
  # @return [WordFinder] reconstructed instance
  def self.from_cache(letters, cached_data)
    instance = allocate  # Create without calling initialize
    instance.instance_variable_set(:@letters, letters)
    instance.instance_variable_set(:@letter_counts, cached_data[:letter_counts])
    instance.instance_variable_set(:@sorted_words, cached_data[:words])
    instance.instance_variable_set(:@valid_words_set, cached_data[:words].to_set)
    # Cache the score multiplier if available (for backward compatibility with old cache entries)
    if cached_data[:score_multiplier]
      instance.instance_variable_set(:@score_multiplier, cached_data[:score_multiplier])
    end
    instance
  end

  # Build once: a Set for O(1) lookups + sorted array for display
  # Filters the cached word list to find words that can be formed from @letters
  # CRITICAL: Uses select (non-mutating) instead of select! to avoid mutating the shared cache
  def build_word_set!
    # Filter words that can be formed from available letters
    # Use select (not select!) to avoid mutating the cached array
    filtered_words = normalized_words.select do |word|
      word.length <= 10 && can_form_word?(word)
    end

    @valid_words_set = filtered_words.to_set
    @sorted_words = @valid_words_set.sort_by { |w| [-w.length, w] }
  end

  # Check if a word can be formed from available letters using character frequency matching
  # @param word [String] word to check
  # @return [Boolean] true if all required characters are available in sufficient quantity
  def can_form_word?(word)
    word.chars.tally.all? { |char, needed| @letter_counts[char].to_i >= needed }
  end

  # Shared normalized word list (cached across all instances)
  # Loads word list from file, normalizes (lowercase, letters only), and caches for 7 days
  # @return [Array<String>] array of normalized words
  def normalized_words
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRES) do
      # Validate file exists
      unless File.exist?(WORD_LIST_PATH)
        raise Errno::ENOENT, "Word list file not found: #{WORD_LIST_PATH}"
      end

      File.readlines(WORD_LIST_PATH, chomp: true)
      # don't need all that - assume the input file is cleaned
      # .map { |line| line.downcase.gsub(/[^a-z]/, "") }
      # .reject(&:empty?)
      # .to_a
    end
  end
end

# ScoreMultiplier calculates a difficulty-based score multiplier for a set of words.
#
# The multiplier is based on two factors:
# 1. Word Count: Fewer words = harder set = higher multiplier
# 2. Score Potential: Shorter words = lower max scores = harder set = higher multiplier
#
# The score potential is calculated as the average of (word_length²) because the scoring
# formula is (length²) * (100/time), so longer words contribute exponentially more to scores.
#
# Both factors are normalized using logarithmic scaling to handle wide ranges smoothly,
# then combined with configurable weights to produce the final multiplier.
#
# Usage:
#
#   words = ["cat", "dog", "house", "gardenias"]
#   multiplier = ScoreMultiplier.calculate(words)
#   # => 1.32 (example: harder set gets higher multiplier)
#
#   # Use in score calculation:
#   base_score = (answer.size**2) * (100.0 / time)
#   final_score = (base_score * multiplier).to_i
#
# Configuration:
#
# All parameters can be adjusted via the CONFIG constant. See the configuration section
# below for detailed adjustment guidelines.
#
class ScoreMultiplier
  # Configuration hash for all tunable parameters.
  # Adjust these values to fine-tune the difficulty scaling.
  #
  # Word Count Bounds:
  #   - min_words: Minimum expected word count (very hard sets)
  #   - max_words: Maximum expected word count (very easy sets)
  #   Typical range observed: 50-2000 words
  #
  # Score Potential Bounds:
  #   - min_score_potential: Minimum average of (length²) (very short words)
  #   - max_score_potential: Maximum average of (length²) (many long words)
  #   Examples:
  #     - 3-letter average = 9
  #     - 5-letter average = 25
  #     - 9-letter average = 81
  #
  # Component Weights:
  #   - word_count_weight: How much word count matters (0.0 to 1.0)
  #   - score_potential_weight: How much word length matters (0.0 to 1.0)
  #   These should sum to 1.0 for balanced contribution, but don't have to.
  #
  # Multiplier Range:
  #   - min_multiplier: Multiplier for easiest sets (typically < 1.0 to reduce scores)
  #   - max_multiplier: Multiplier for hardest sets (typically > 1.0 to boost scores)
  #   - base_multiplier: Baseline multiplier (typically 1.0)
  #
  CONFIG = {
    # Word count bounds (observed range: ~50-2000 words)
    min_words: 35,
    max_words: 1000,

    # Score potential bounds (average of length²)
    # Typical: 3-letter words = 9, 5-letter = 25, 9-letter = 81
    min_score_potential: 10,
    max_score_potential: 70,

    # Component weights (how much each factor contributes)
    # These can sum to any value, but 1.0 gives balanced contribution
    word_count_weight: 0.5,
    score_potential_weight: 0.5,

    # Multiplier range
    min_multiplier: 0.5,      # Easiest sets get 0.7x score
    max_multiplier: 2.8,      # Hardest sets get 1.8x score
    base_multiplier: 1.0      # Baseline (middle difficulty)
  }.freeze

  # ============================================================================
  # ADJUSTMENT GUIDE
  # ============================================================================
  #
  # How to adjust the configuration for your needs:
  #
  # 1. ADJUSTING MULTIPLIER RANGE (min_multiplier, max_multiplier)
  #    - If scores feel too high across the board: decrease max_multiplier
  #    - If scores feel too low: increase max_multiplier
  #    - If easy sets are still scoring too high: decrease min_multiplier
  #    - Typical range: 0.5x to 2.5x
  #
  # 2. ADJUSTING WORD COUNT BOUNDS (min_words, max_words)
  #    - If you see sets with < 50 words: decrease min_words
  #    - If you see sets with > 2000 words: increase max_words
  #    - These bounds define the "hardest" and "easiest" word counts
  #    - Use logarithmic scaling, so wide ranges work well
  #
  # 3. ADJUSTING SCORE POTENTIAL BOUNDS (min_score_potential, max_score_potential)
  #    - Calculate: average of (word_length²) for your word sets
  #    - If most sets have short words (avg 3-4 letters): decrease max_score_potential
  #    - If many sets have long words (avg 8-9 letters): increase max_score_potential
  #    - Typical values: 10 (very short) to 70 (many long words)
  #
  # 4. ADJUSTING COMPONENT WEIGHTS (word_count_weight, score_potential_weight)
  #    - If word count matters more: increase word_count_weight, decrease score_potential_weight
  #    - If word length matters more: increase score_potential_weight, decrease word_count_weight
  #    - They don't need to sum to 1.0, but doing so gives balanced contribution
  #    - Example: word_count_weight: 0.7, score_potential_weight: 0.3 (emphasize count)
  #
  # 5. TESTING YOUR CHANGES
  #    - Test with known easy sets (many long words): should get low multiplier (~0.7-0.9)
  #    - Test with known hard sets (few short words): should get high multiplier (~1.5-1.8)
  #    - Test with medium sets: should get middle multiplier (~1.0-1.2)
  #
  # 6. OVERRIDING CONFIG FOR TESTING
  #    - You can pass a custom config hash to calculate():
  #      custom_config = ScoreMultiplier::CONFIG.merge(max_multiplier: 2.0)
  #      ScoreMultiplier.calculate(words, config: custom_config)
  #
  # ============================================================================

  # Calculate the difficulty-based score multiplier for a list of words.
  #
  # @param words [Array<String>] array of words to analyze
  # @param config [Hash] optional configuration override (defaults to CONFIG)
  # @return [Float] score multiplier (typically 0.7 to 1.8)
  #
  # @example
  #   # Easy set: many long words
  #   words = ["gardenias", "panelised", "gardens", "panel", "garden", "panels"] * 100
  #   ScoreMultiplier.calculate(words)  # => ~0.8 (lower multiplier = easier)
  #
  #   # Hard set: few short words
  #   words = ["cat", "dog", "bat", "rat"]
  #   ScoreMultiplier.calculate(words)  # => ~1.6 (higher multiplier = harder)
  def self.calculate(words, config: CONFIG)
    return config[:base_multiplier] if words.empty?

    word_count = words.size
    score_potential = calculate_score_potential(words)

    # Normalize each component using logarithmic scaling
    word_count_norm = normalize_log(
      word_count,
      config[:min_words],
      config[:max_words]
    )

    score_potential_norm = normalize_log(
      score_potential,
      config[:min_score_potential],
      config[:max_score_potential]
    )

    # Combine components with weights
    combined_difficulty = (
      word_count_norm * config[:word_count_weight] +
      score_potential_norm * config[:score_potential_weight]
    )

    # Normalize combined difficulty to multiplier range
    # Clamp to [0, 1] range first to handle edge cases
    combined_difficulty = [[combined_difficulty, 0.0].max, 1.0].min

    # Map to multiplier range: 0.0 -> min_multiplier, 1.0 -> max_multiplier
    multiplier_range = config[:max_multiplier] - config[:min_multiplier]
    config[:min_multiplier] + (combined_difficulty * multiplier_range)
  end

  # Calculate the score potential of a word list.
  # Score potential is the average of (word_length²) because the scoring formula
  # uses length², so this reflects the theoretical scoring ceiling.
  #
  # @param words [Array<String>] array of words
  # @return [Float] average of (word_length²) for all words
  #
  # @example
  #   words = ["cat", "house", "gardenias"]
  #   # lengths: 3, 5, 9
  #   # squared: 9, 25, 81
  #   # average: (9 + 25 + 81) / 3 = 38.33
  def self.calculate_score_potential(words)
    return 0.0 if words.empty?

    total_squared_length = words.sum { |word| word.length**2 }
    total_squared_length.to_f / words.size
  end

  # Normalize a value using logarithmic scaling between min and max bounds.
  # Returns a value between 0.0 (at max) and 1.0 (at min).
  #
  # This uses logarithmic scaling because:
  # - It handles wide ranges smoothly (e.g., 50-2000 words)
  # - It provides diminishing returns (going from 50->100 is bigger than 1000->1100)
  # - It prevents extreme outliers from dominating
  #
  # @param value [Numeric] value to normalize
  # @param min [Numeric] minimum bound (hardest/easiest depending on context)
  # @param max [Numeric] maximum bound (easiest/hardest depending on context)
  # @return [Float] normalized value between 0.0 and 1.0
  #
  # @example
  #   # Word count: fewer words = harder = higher normalized value
  #   normalize_log(100, 50, 2000)  # => ~0.65 (closer to min = harder)
  #   normalize_log(1000, 50, 2000) # => ~0.19 (closer to max = easier)
  def self.normalize_log(value, min, max)
    # Handle edge cases
    return 1.0 if value <= min
    return 0.0 if value >= max

    # Clamp value to bounds for safety
    clamped_value = [[value, min].max, max].min

    # Logarithmic normalization formula:
    # normalized = (log(max) - log(value)) / (log(max) - log(min))
    # This gives 1.0 at min and 0.0 at max
    log_min = Math.log(min)
    log_max = Math.log(max)
    log_value = Math.log(clamped_value)

    (log_max - log_value) / (log_max - log_min)
  end

  private_class_method :normalize_log, :calculate_score_potential
end
