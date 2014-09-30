require './plugins/pygments_code'

module BacktickCodeBlock
  AllOptions = /([^\s]+)\s+(.+?)\s+(https?:\/\/\S+|\/\S+)\s*(.+)?/i
  LangCaption = /([^\s]+)\s*(.+)?/i
  RestOptions = /(.*?)(\w+):([^\s]+)\s?(.*)?/i
  def self.render_code_block(input)
    @options = nil
    @lang = nil
    @url = nil
    @urlname = nil
    input.gsub(/^`{3} *([^\n]+)?\n(.+?)\n`{3}/m) do
      @title = nil
      @caption = nil
      @rest = nil
      @offset = nil
      @options = $1 || ''
      str = $2

      if @options =~ AllOptions
        @lang = $1
        @title = $2
        @url = $3
        @rest = $4
        while @rest =~ RestOptions
          @urlname = $1 if !$1.empty?
          @offset = $3 if $2 == "start"
          linenos = $3 if $2 == "linenos"
          @rest = $4
        end
        #@caption = "<figcaption><span>#{$2}</span><a href='#{$3}'>#{$4 || 'link'}</a></figcaption>"
        @caption = "<figcaption><span>#{@title}</span><a href='#{@url}'>#{@urlname || 'link'}</a></figcaption>"
      elsif @options =~ LangCaption
        @lang = $1
        @rest = $2
        @title = @rest
        while @rest =~ RestOptions
          @title = $1 if !$1.empty?
          @offset = $3 if $2 == "start"
          linenos = $3 if $2 == "linenos"
          @rest = $4
        end
        #@caption = "<figcaption><span>#{$2}</span></figcaption>"
        @caption = "<figcaption><span>#{@title}</span></figcaption>"
      end


      if str.match(/\A( {4}|\t)/)
        str = str.gsub(/^( {4}|\t)/, '')
      end
      if @lang.nil? || @lang == 'plain'
        code = HighlightCode::tableize_code(str.gsub('<','&lt;').gsub('>','&gt;'))
        "<figure class='code'>#{@caption}#{code}</figure>"
      else
        if @lang.include? "-raw"
          raw = "``` #{@options.sub('-raw', '')}\n"
          raw += str
          raw += "\n```\n"
        else
          code = HighlightCode::highlight(str, @lang, linenos, @offset)
          "<figure class='code'>#{@caption}#{code}</figure>"
        end
      end
    end
  end
end
