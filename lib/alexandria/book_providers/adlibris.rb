# Copyright (C) 2005 Rene Samselnig - Modified by Linus Zetterlund
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# TODO:
# fix ���


require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class AdlibrisProvider < GenericProvider
        BASE_URI = "http://www.adlibris.se/"
        def initialize
            super("Adlibris", "Adlibris")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            req = BASE_URI
            if type == SEARCH_BY_ISBN
                req += "shop/product.asp?isbn="+criterion
            else
				search_criterions = {}
				search_criterions[type] = CGI.escape(criterion)
				req = "http://www.adlibris.se/shop/search_result.asp?additem=&page=search%5Fresult%2Easp&search=advanced&format=&status=&ebook=&quickvalue=&quicktype=&isbn=&titleorauthor=&title="+search_criterions[SEARCH_BY_TITLE].to_s()+"&authorlast=&authorfirst=&keyword="+search_criterions[SEARCH_BY_KEYWORD].to_s()+"&publisher=&category=&language=&inventory1=1&inventory2=2&inventory4=4&inventory8=&get=&type=&sortorder=1&author="+search_criterions[SEARCH_BY_AUTHORS].to_s()
			end


			results = []
			
            if type == SEARCH_BY_ISBN
				data = transport.get(URI.parse(req))
				puts "if type == SEARCH_BY_ISBN"
				return to_book_isbn(data, criterion) rescue raise NoResultsError
            else
                begin
					data = transport.get(URI.parse(req+"&row=1"))
					
					regx = /shop\/product\.asp\?isbn=([^&]+?)&[^>]+>([^<]+?)<\/a>([^>]*?>){10}([^<]+?)<\/b>[^\)]+?\);\"\)>[\s]+?([^<\s]+?)<\/a>/
					
					
					data.scan(regx) do |md| next unless md[0] != md[1]
						isbn = md[0].to_s()
						
						imageAddr = nil
 						imgAddrMatch = data.scan(isbn+'.jpg')
						if imgAddrMatch.length() == 2
							imageAddr = 'http://www.adlibris.se/shop/images/'+isbn+'.jpg'
						end
												
						results << [Book.new(md[1].to_s(), # Title
							[md[3].to_s()], # Authors
							isbn,
							"", # Publisher
							translate_stuff_stuff(md[4].to_s())), # Edition
							imageAddr]
						
					end
					
					return results
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
			#puts "debug: url(book)"
            BASE_URI + "shop/product.asp?isbn=" + (book.isbn or "")
        end

        #######
        private
        #######
		
		def translate_html_stuff!(r)
			r.sub!('&#229;','å') # �
			r.sub!('&#228;','ä') # �
			r.sub!('&#246;','ö') # �
			r.sub!('&#197;','�.') # �
			r.sub!('&#196;','�.') # �
			r.sub!('&#214;','�.') # �
			return r
		end
		def translate_html_stuff(s)
			r = s
			translate_html_stuff!(r)
			return r
		end


		def translate_stuff_stuff!(r)
			#r.sub!('\�','å') # �
			#r.sub!('\�','ä') # �
			#r.sub!('\�','ö') # �
			#r.sub!('\�','�.') # �
			#r.sub!('\�','�.') # �
			#r.sub!('\�','�.') # �
			return r
		end
		def translate_stuff_stuff(s)
			r = s
			translate_stuff_stuff!(r)
			return r
		end

		
		def to_book_isbn(data, isbn)
			product = {}			
			if /Ingen titel med detta ISBN finns hos AdLibris/.match(data) != nil
				raise NoResultsError
			end


			regxp = /^<b>(.+)<\/b>/
			md = regxp.match(data)
			if md == nil
				#puts "Title string not found, but no \"book not found\" string found\n"
				# TODO: Raise something more accurate
				raise NoResultsError
			end
			product["title"] = CGI.unescape(md[1])


			regx = /<tr><td colspan="2" class="text">F&#246;rfattare:&nbsp;<b>([^<]*)<\/b><\/td><\/tr>/
			product["authors"] = []
			data.scan(regx) do |md| next unless md[0] != md[1]
    			product["authors"] << translate_html_stuff(CGI.unescape(md[0]))
			end


			regxp = /^<tr><td colspan="2" class="Text">F�rlag: (.+)<\/td><\/tr>/
			md = regxp.match(data)
			if md == nil
				puts "Publisher string not found, but no \"book not found\" string found\n"
				# TODO: Raise something more accurate
				raise NoResultsError
			end
			product["publisher"] = md[1]


			regxp = /^<tr><td colspan="2" class="Text">Bandtyp: <a style="font-weight: lighter" href="javascript:popWindow\([^\)]*\);"\)>([^<]*)<\/a>/
			md = regxp.match(data)
			if md == nil
				#puts "Binding string not found, but no \"book not found\" string found\n"
				# TODO: Raise something more accurate
				raise NoResultsError
			end
			product["edition"] = md[1]


			img_url = "shop/images/" + isbn + "\.jpg"
			puts img_url
			md = data.match(img_url)
			if md != nil
				product["cover"] = BASE_URI + img_url
			end
						
			book = Book.new(
				translate_html_stuff(product["title"]),
				product["authors"],
				isbn,
				translate_html_stuff(product["publisher"]),
				translate_html_stuff(product["edition"]))
			return [ book, product["cover"] ]
		end

    end
end
end
