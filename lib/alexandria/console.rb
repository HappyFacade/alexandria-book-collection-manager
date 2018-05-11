# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  def self.list_books_on_console(_title = true, authors = true)
    libraries_simpleton = Alexandria::LibraryCollection.instance
    libraries_simpleton.reload
    libraries = Alexandria::Library.loadall
    output_string = ''
    @books = libraries.flatten
    @books.each do |book|
      book_authors = book.authors.join(' & ') if authors
      output_string += [book.title, book_authors].join(', ') + "\n"
    end
    output_string
  end
end
