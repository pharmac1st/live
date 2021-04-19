# frozen_string_literal: true

# Copyright, 2021, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'element'
require_relative 'resolver'

module Live
	class Page
		def initialize(connection, resolver)
			@connection = connection
			@resolver = resolver
			
			@elements = {}
			@updates = Async::Queue.new
			
			@reader = start_reader
		end
		
		attr :updates
		
		def start_reader
			Async do
				while message = @connection.read
					Console.logger.debug(self, "Reading message:", message)
					
					if id = message[:bind] and data = message[:data]
						bind(@resolver.call(id, data))
					elsif id = message[:id]
						@elements[id].handle(message[:event], message[:details])
					end
				end
			ensure
				@reader = nil
			end
		end
		
		def bind(element)
			@elements[element.id] = element
			
			element.bind(self)
		end
		
		def run
			while update = @updates.dequeue
				Console.logger.debug(self, "Sending update:", update)
				
				@connection.write(update)
				@connection.flush if @updates.empty?
			end
		end
	end
end
