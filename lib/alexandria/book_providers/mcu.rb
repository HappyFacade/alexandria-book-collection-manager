# Copyright (C) 2004 Javier Fernandez-Sanguino
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
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'cgi'
require 'net/http'

module Alexandria
class BookProviders
    class MCUProvider < GenericProvider
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        LANGUAGES = {
            'es' => '1'
        }

        BASE_URI = "http://www.mcu.es/cgi-bin/BRSCGI3701?"
        def initialize
            super("MCU","Spanish Culture Ministry")
	    # No preferences
        end
        
        def search(criterion, type)
            prefs.read
	    criterion = GLib.convert(criterion, "WINDOWS-1252", "UTF-8")
	    print "Doing search with MCU #{criterion}, type: #{type}\n" if $DEBUG # for DEBUGing
            req = BASE_URI + "CMD=VERLST&BASE=ISBN&CONF=AEISPA.cnf&OPDEF=AND&DOCS=1-1000&SEPARADOR=&"
            req += case type
                when SEARCH_BY_ISBN
                    "WGEN-C=&WISB-C=#{CGI::escape(criterion)}&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=DISPONIBLE&WLEN-C=&WCLA-C=&WSOP-C="

                when SEARCH_BY_TITLE
		    "WGEN-C=&WISB-C=&WAUT-C=&WTIT-C=#{CGI::escape(criterion)}&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=DISPONIBLE&WLEN-C=&WCLA-C=&WSOP-C="

                when SEARCH_BY_AUTHORS
		      "WGEN-C=&WISB-C=&WAUT-C=#{CGI::escape(criterion)}&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=DISPONIBLE&WLEN-C=&WCLA-C=&WSOP-C="

                when SEARCH_BY_KEYWORD
			"WGEN-C=#{CGI::escape(criterion)}&WISB-C=&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=DISPONIBLE&WLEN-C=&WCLA-C=&WSOP-C="

                else
                    raise InvalidSearchTypeError
            end
            products = {}
	    print "Request page is #{req}\n" if $DEBUG # for DEBUGing
            transport.get(URI.parse(req)).each do |line|
	    	#line = GLib.convert(line, "ISO-8859-1", "UTF-8")
	    	print "Reading line: #{line}" if $DEBUG # for DEBUGing
                if (line =~ /CMD=VERDOC.*&DOCN=([^&]*)&NDOC=([^&]*)/) and (!products[$1]) and (book = parseBook($1,$2)) then
                    products[$1] = book
                end
            end

            raise NoResultsError if products.values.empty?
            type == SEARCH_BY_ISBN ? products.values.first : products.values
        end
        
        def parseBook(docn,ndoc)
            detailspage='http://www.mcu.es/cgi-bin/BRSCGI3701?CMD=VERDOC&CONF=AEISPA.cnf&BASE=ISBN&DOCN=' + docn + '&NDOC=' + ndoc
	    print "Looking at detailspage: #{detailspage}\n" if $DEBUG # for DEBUGing
            product = {}
            product['authors'] = []
            nextline = nil
	    robotstate = 0
            transport.get(URI.parse(detailspage)).each do |line|
	    # This is a very crude robot interpreter
	    # Note that the server provides more information 
	    # we don't store:
	    # - Language  - Description
	    # - Binding   - Price 
	    # - Colection - Theme
	    # - CDU      - Last update

	    # There seems to be an issue with accented chars..
	    line = GLib.convert(line, "UTF-8", "ISO-8859-1")
	    print "Reading line (robotstate #{robotstate}): #{line}" if $DEBUG # for DEBUGing
                if line =~ /^<\/td>$/ or line =~ /^<\/tr>$/
		    robotstate = 0 
		elsif robotstate == 1 and line =~ /^([^<]+)</ 
	 	    author = $1.gsub('&nbsp;',' ').sub(/ +$/,'')
		    if author.length > 3 then
		    # Only add authors of appropiate length
       	       		    product['authors'] << author
			    print "Authors are #{product['authors']}\n" if $DEBUG # for DEBUGing
		    end
                elsif robotstate == 10 and line =~ /^([^<]+)/
		    if product['name'].nil?  then
	                    product['name'] = $1.strip
	            else
	                    product['name'] += $1.strip
		    end
		    print "Name is #{product['name']}\n" if $DEBUG # for DEBUGing
                elsif robotstate == 2 and line =/^<td class="tex1"/
		    robotstate = 10
                elsif robotstate == 3 and line =~ /^([0-9]+-[0-9]+-[0-9]+-[0-9X]+)/ 
                    product['isbn'] = $1
		    print "ISBN is #{product['isbn']}\n" if $DEBUG # for DEBUGing
		    robotstate = 0
                elsif robotstate == 4 and line =~ /^([^<]+)</
                    product['manufacturer'] = $1.strip
		    print "Manufacturer is #{product['manufacturer']}\n" if $DEBUG # for DEBUGing
		    robotstate = 0 
                elsif robotstate == 5 and line =~ /^([^<]+)</
                    product['media'] = $1.strip
		    print "Media is #{product['media']}\n" if $DEBUG # for DEBUGing
		    robotstate = 0 
                elsif line =~ /^Autor:/
		    robotstate = 1
                elsif line =~ /^T.tulo:/
		    robotstate = 2
                elsif line =~ /^ISBN:/
		    robotstate = 3
                elsif line =~ /^Publicaci.n:/
		    robotstate = 4
                elsif line =~ /^Encuadernaci.n:/
		    robotstate = 5 
                end
            end

	    # TODO: This provider does not include picture for books
            %w{name isbn media manufacturer}.each do |field|
	        print "Checking #{field} for nil\n" if $DEBUG # for DEBUGing
                return nil if product[field].nil?
            end 
            
	    print "Creating new book\n" if $DEBUG # for DEBUGing
	    book = Book.new(product['name'],
	                    product['authors'],
			    product['isbn'].delete('-'),
			    product['manufacturer'],
			    product['media'])
            return [ book ]
        end

        def url(book)
		"http://www.mcu.es/cgi-bin/BRSCGI3701?CMD=VERLST&BASE=ISBN&CONF=AEISPA.cnf&OPDEF=AND&DOCS=1&SEPARADOR=&WGEN-C=&WISB-C=" + book.isbn + "&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=DISPONIBLE&WLEN-C=&WCLA-C=&WSOP-C="
        end
    end
end
end
