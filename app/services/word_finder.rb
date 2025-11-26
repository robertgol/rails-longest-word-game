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
          letter_counts: instance.instance_variable_get(:@letter_counts)
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
        .map { |line| line.downcase.gsub(/[^a-z]/, "") }
        .reject(&:empty?)
        .to_a
    end
  end
end
