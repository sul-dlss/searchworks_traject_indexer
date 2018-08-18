module Utils
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

  # https://rosettacode.org/wiki/Longest_common_prefix#Ruby
  def self.longest_common_prefix(*strs)
    return '' if strs.empty?
    min, max = strs.minmax
    idx = min.size.times { |i| break i if min[i] != max[i] }
    min[0...idx]
  end
end
