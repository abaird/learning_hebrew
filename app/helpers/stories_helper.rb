module StoriesHelper
  def tokenize_hebrew(text)
    # Split on spaces, preserve punctuation
    text.split(/\s+/).map do |token|
      # Separate punctuation from words
      # Hebrew Unicode range: U+0590-05FF
      if token =~ /^([^\u0590-\u05FF\s]+)?(.+?)([^\u0590-\u05FF\s]+)?$/
        {
          prefix: Regexp.last_match(1) || "",
          word: Regexp.last_match(2),
          suffix: Regexp.last_match(3) || ""
        }
      else
        { prefix: "", word: token, suffix: "" }
      end
    end
  end
end
