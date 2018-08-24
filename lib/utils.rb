module StringScrubbing
  def self.balance_parentheses(string)
    open_deletes = []
    close_deletes = []

    string.chars.each_with_index do |c, i|
      if c == '('
        open_deletes << i
      elsif c == ')'
        if open_deletes.length == 0
          close_deletes << i
        else
          open_deletes.pop
        end
      end
    end

    deletes = open_deletes
    deletes += close_deletes

    new_string = string.dup
    deletes.reverse.each do |i|
      new_string.slice!(i)
    end
    new_string
  end
end
