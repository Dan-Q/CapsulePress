require 'nokogiri'
require 'word_wrap'
require 'word_wrap/core_ext'
require 'cgi' # for HTML unescaping

class String
  def upcase_first
    sub(/\S/, &:upcase)
  end
end

class Convert
  def self.html_to_gmi(html)
    linkable_post_names = CapsulePress.known_slugs
    # handle galleries by converting to a list of image links
    html.gsub!(/\[gallery [^\]]*ids="([\d,]+)"\]/) do
      ids = $1.split(',').map(&:to_i)
      urls = WP.query("SELECT DISTINCT ID, post_excerpt, guid FROM wp_posts WHERE ID IN (#{ids.join(',')})", cache_duration: 3600)
      links = urls.map do |u| 
        t = u['post_excerpt']
        t = "Image ##{u['ID']}" if !t || (t == '')
        "<a href=\"#{u['guid']}\" title=\"#{t.gsub('"', '')}\">#{t}</a>"
      end
      links.join('')
    end
    # use a DOM parser for the rest...
    dom = Nokogiri::HTML.parse(html)
    # entirely remove certain tags: e.g. <style>
    dom.css('style').each(&:remove)
    # handle blockquotes
    dom.css('blockquote').each do |b|
      new_node = dom.create_element 'span' # throwaway element
      new_node.inner_html = b.text.split("\n").map{|bl| "> #{bl}"}.join("\n")
      b.replace(new_node)
    end
    # space around <figure>s
    dom.css('figure').each do |f|
      new_node = dom.create_element 'span' # throwaway element
      new_node.inner_html = "\n\n#{f.text}\n\n\n"
      f.replace(new_node)
    end
    # handle preformatted
    dom.css('pre').each do |p|
      new_node = dom.create_element 'span' # throwaway element
      new_node.inner_html = "\n```\n#{p.inner_html.gsub(' ', '&nbsp;')}\n```"
      p.replace(new_node)
    end
    # handle image links
    dom.css('a[href$="png"], a[href$="gif"], a[href$="jpg"], a[href$="webp"]').each do |a|
      t = a['title']
      if (((!t) || (t == '') || (t == a['href'])) && (i = a.css('img')[0]))
        t = i['alt']
      end
      t = a['href'].split('/')[-1] if ((!t) || (t == '') || (t == a['href']))
      a.replace("\n=> #{a['href'].gsub(/^https?:\/\/#{ENV['DOMAIN']}\/wp-content\/uploads\//,'/')} #{t}\n")
    end
    # handle other links
    links_not_to_append_to_bottom = []
    links = dom.css('a').to_a
    links.each do |a|
      if(a['href'] =~ /https?:\/\/#{ENV['DOMAIN']}\/\d{4}\/\d{2}\/\d{2}\/([^\/]+)/ && (linkable_post_names.include?($1)))
        # other links are extracted to the footer either as cross-links or HTTP links depending on capability:
        a['href'] = "#{CapsulePress::POSTS_PREFIX}#{$1}"
      end
    end
    links.reject!{|a| links_not_to_append_to_bottom.include?(a['href'])}
    links = links.map{|a|"=> #{a['href']} #{a['title'] || a.text.upcase_first}"}.join("\n")
    # handle headings
    dom.css('h2').each{|h|h.replace("## #{h.text}")}
    dom.css('h3, h4, h5, h6').each{|h|h.replace("### #{h.text}")}
    # convert to GMI by stripping/tidying
    dom.css('li').each{|li|li.content = "* #{li.inner_text}"}
    gmi = dom.inner_text
    gmi.gsub!(/This post is secret; it.{0,3}s only publicised via my RSS feed\..*[\s\r\n]*/, '') # remove RSS Club disclaimer if present
    gmi.gsub!(/^.*\[\/?caption[^\]]*\].*$/, '') # remove caption blocks
    gmi.gsub!(/\[footnote\](.*?)\[\/footnote\]/, ' (\1)') # convert footnote blocks to parentheses
    # append links
    gmi = "#{gmi}\n## Links\n\n#{links}" if links != ''
    # [q23_...] shortcodes? Definitely kill those:
    gmi.gsub!(/\[\/?q23_.*?\]/, '')
    # Trailing whitespace? Fix that:
    gmi.gsub!(/[ \t]+$/, '')
    # Over-indented bulleted lists? Fix that:
    gmi.gsub!(/^\s+(\* )/, "* ")
    # Linefeed tidying:
    gmi.gsub!(/(\s*\r?\n\s*){3,}/, "\n\n") # reduce multi-\n's to no-more-than-two in a row
    # return output
    gmi
  end

  def self.html_to_gophererb(html)
    # first, convert to gmi, then from there to gophererb
    result = html_to_gmi(html)

    # convert to gophererb -
    # turn "# titles" into uppercase instead
    result.gsub!(/^#+ (.*)/){ "\n#{$1.upcase}\n" }
    # markup external non-gopher http/https/etc. links:
    result.gsub!(/^=> ((https?|ftp|spartan|gemini):\/\/[^\s]+ .*)$/){ "=> URL:#{$1}" }
    # remove ``` block delimiters
    result.gsub!(/^```[ \t]*\r?\n/, '')

    # Linefeed tidying:
    result.gsub!(/(\s*\r?\n\s*){3,}/, "\n\n") # reduce multi-\n's to no-more-than-two in a row

    # unescape HTML entities
    CGI.unescapeHTML result
  end
end
