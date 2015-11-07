# -*- tab-width: 2 -*-

###
# modemizr.coffee
#
# The MIT License (MIT)
# Copyright © 2015 Santeri Paavolainen <santtu@iki.fi>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
###

###
# How would you slowly drip text into HTML character-by-character?
#
# Plain text is easy to handle. Just muck with `textContent`. But it
# will both not work with styles or more complex DOM structure.
#
# This code works by having an input and output stack. These stacks
# mirror the DOM structure, e.g. when a DOM element is encountered in
# the input then it is recursed into and corresponding structures get
# pushed to input and output stacks for processing.
#
# The input stack actually contains arrays of input elements, with the
# output stack (mostly, see below) mirroring each input array's
# position in the structure. This is because for example <p>yet
# <b>another</b> test</p> consists of three different input
# elements at the P level. They have to be processed in order.
#
# So with <p>yet <b>another</b> test</p> being the input element and
# some DIV as the output element this is what happens (the top of
# stack is always the **current** element):
#
# 1. current_input = [ <P>...</P> ], current_output = DIV
# 2. Pick the first element of current input, input_head = <P>...</P>
# 3. Remove P from current_input and push P to output stack
# 4. Push contents of P to input stack
#
# After this step the stacks are:
#
# input  = [[#Text(yet) <B>another</B> #Text(test)], []]
# output = [P, DIV]
#
# Here #Text() is a DOM Text element, not a string. Note the empty []
# list in input -- the first input list had only the P element which
# was removed, leaving an empty list (it will be later popped out when
# going back up the recursion).
#
# 5. current_input = [#Text(yet) <B>another</B> #Text(test)]
# 6. input_head = #Text(yet)
# 7. This is a text element, convert to plain string and replace at
#    current_input head, push a #Text() element to output
#
# Now current_input = ["yet" <B>another</B> #Text(test)]
#
# 8. input_head = "yet", hooray, finally a plain string! add "y" to
#    current_output = #Text() and modify input_head = "et"
# 9. Keep going on, after this: input_head = "t", current_output = #Text(ye)
# 10. ...: input_head = "", current_output = #Text(yet)
# 11. Empty string, pop input_head and output
#
# Now current_input = [<B>another</B> #Text(test)]
# and current_output = <P>yet</P>
#
# 12. Now input_head = <B>another</B>, push <B> to output, pop
#     input_head and push [#Text(another)] from the B to input stack
# 13. input_head is #Text, convert to string (see above)
# 14. => input_head = "nother", current_output = <B>a</B>
# 15. => input_head = "other", current_output = <B>an</B>
# 16. ... and so on
#
# The process should now be ... clearer.
#
# How do we handle images and pauses? We use a class called
# `Processor` which if found as current_output will be given control
# over for a while. When finished it is popped off the output stack
# (there is no corresponding input stack element, which is left
# untouched).
#
# Handling the cursor is a bit more kludgy, but essentially it boils
# to removing and adding a SPAN element into correct place (which is
# **before** the current #Text() element) when moving up and down the
# stack.
#
###

stringp = (s) -> typeof s == 'string' or s instanceof String
log = (args...) ->
#  console.log.apply(console, args)

time = () -> (new Date()).getTime()

class Processor
  constructor: (@master, @parentNode) ->
  done: true

class Image extends Processor
  pos: 0
  done: false

  constructor: (master, @image) ->
    super master, @image

    @last = time()
    @update()
    @image.style.overflow = "hidden"

  update: () ->
    fh = @pos // @image.width
    ph = fh + 1
    fw = @image.width
    pw = @pos % @image.width

    @image.style.webkitClipPath =
      @image.style.clipPath = "polygon(0px 0px, #{fw}px 0px, #{fw}px #{fh}px, #{pw}px #{fh}px, #{pw}px #{ph}px, 0px #{ph}px)"

  ###
  # Calculate how many pixels we should show since last update. This
  # calculates the number of bytes we have accumulated so far and
  # approximates 8-bit images e.g. one byte per pixel to show.
  ###
  pixelsPending: () ->
    bytes = (time() - @last) / 1000.0 * @master.bps * @master.imageSpeedup / 10
    bytes

  tick: () ->
    if @pos >= @image.height * @image.width
      @image.style.webkitClipPath = @image.style.clipPath = ""
      return @done = true

    pixels = @pixelsPending()

    if pixels > 0
      @last = time()
      @pos += pixels
      @update()


class Pause extends Processor
  ticks: 0

  constructor: (master, parent, @chars, @secs) ->
    @start = time()
    @done = @donep()
    super master, parent

  donep: () ->
    log "donep: ticks #{@ticks} chars #{@chars} elapsed #{time() - @start} secs #{@secs}"

    pending = (@chars? and @ticks < @chars) or
      (@secs? and (time() - @start) < (1000.0 * @secs))

    log "pending: #{pending}"
    not pending

  tick: () ->
    @ticks++
    @done = @donep()


class Modemizr
  ###
  # Default parameters
  ###
  bps: 300
  cursor: false
  blink: false
  imageSpeedup: 100

  blinker: null
  timer: null

  ###
  # Output is a stack of output elements. It starts with the initial
  # `output` container given at init.
  ###
  output: []
  root: null

  ###
  # Input is an stack of arrays. When an empty array is encountered,
  # then output value is removed. Similarly if output needs to
  # recurse, then a new input array is pushed in.
  ###
  input: []

  ###
  # Output should always be a single node, input can either be an
  # array of elements, or a single element. If a single element is
  # given then its **child nodes** are used, not the node itself.
  ###
  constructor: (output, input, options) ->
    if options?
      if options.bps?
        @bps = options.bps

      if options.cursor?
        @cursor = options.cursor

      if options.blink?
        @blink = options.blink

      if options.imageSpeedup?
        @imageSpeedup = options.imageSpeedup

    if not output?
      return

    if not input?
      input = output

    @output = [output]
    @root = output

    if not (options? and options.show?) or options.show
      if @root.style.display == "none"
        @root.style.display = "block"

    ###
    # If input is the same as output, grab node content first and then
    # clear it.
    ###
    if output == input
      nodes = Array.prototype.slice.call input.childNodes
      while (child = input.firstChild)?
        input.removeChild child
      input = nodes

    ###
    # If we are passed a plain input node grab its children only.
    ###
    if not (input instanceof Array) and input.childNodes?
      input = input.childNodes

    ###
    # ... and remember to use slice to ensure it is a true array, not
    # an object of childNodes
    ###
    @input = [Array.prototype.slice.call input]
    log "output", @output, "input", @input

  restart: () ->
    @stop()
    @start()

  start: () ->
    if @timer?
      return

    interval = 1000.0 / (@bps / 10.0)
    @last = (new Date()).getTime()
    @timer = setInterval (() => @tick()), interval

    if @blink
      blink_interval = if parseFloat @blink == @blink then @blink else 500.0
      @blinker = setInterval (() => @blinks()), blink_interval

    @

  stop: () ->
    if @timer?
      clearInterval @timer
      @timer = null

    if @blinker?
      clearInterval @blinker
      @blinker = null
      @root.classList.remove 'blink'

    @

  blinks: () ->
    @root.classList.toggle 'blink'


  ###
  # Count the number of characters that shold be output to keep the
  # BPS value correct since `last` when now is `now`.
  ###
  countCharsNeeded: (last, now) ->
    elapsed = now - last
    chars = Math.round(elapsed / (1000.0 / (@bps / 10.0)))
    chars

  tick: () ->
    if @input.length == 0
      @stop()
      return

    now = (new Date()).getTime()
    chars = @countCharsNeeded(@last, now)

    if chars > 0
      @last = now
      while chars-- > 0
        @step()

  pop_both: () ->
    @pop_output()
    @pop_input()

  pop_input: () -> @input.pop()

  pop_output: () ->
    if @cursor
      @pop_cursor()

    @output.pop()

  current_output: () ->
    @output[@output.length - 1]

  ###
  # Remove cursor from the topmost output element.
  ###
  pop_cursor: () ->
    output = @current_output()
    if output.getElementsByClassName?
      cursors = output.getElementsByClassName("cursor")
      while cursors.length > 0
        cursor = cursors[0]
        cursor.remove()

  ###
  # If the topmost element is a text node, add cursor **after** it (in
  # its parent child node list). For any other element type we don't
  # do anything as we are guaranteed to get a text node eventually
  # here.
  ###
  push_cursor: () ->
    output = @current_output()
    if (output.nodeType? and output.nodeType == 3) or (output instanceof Processor)
      cursor = document.createElement "span"
      cursor.className = (stringp @cursor) and @cursor or "cursor"
      output.parentNode.appendChild cursor

  push_both: (node, content) ->
    if @cursor
      @pop_cursor()

    @output[@output.length - 1].appendChild node
    @output.push node
    @input.push content

    if @cursor
     @push_cursor()

  push_output: (node) ->
    if @cursor
      @pop_cursor()

    @output.push node

    if @cursor
      @push_cursor()

  ###
  # Remove the current head element of the top input. Remember, input
  # is a stack of arrays.
  ###
  drop_input: () ->
    @input[@input.length - 1].shift()

  ###
  # Produce output of "one character" or its equivalent.
  ###
  step: () ->
    if @input.length == 0 or @output.length == 0
      while @output.length
        @pop_output()

      @stop()
      return

    output = @output[@output.length - 1]
    input = @input[@input.length - 1]

    if output instanceof Processor
      log "processing"

      output.tick()

      if not output.done
        return

      @pop_output()
      return @step()

    if input.length == 0
      @pop_both()
      return @step()

    current = input[0]
    log "current", current

    ###
    # If it is a plain string, easy -- pick one character and append
    # to output (it will always be a Text element at this point).
    ###
    if stringp current
      if current.length == 0
        @drop_input()
        return @step()

      log "plain string", current

      # This will output one character.
      output.textContent += current[0]
      input[0] = current.slice(1)
      return

    log "not string"

    ###
    # All other types get dropped from the input and replaced with
    # something else (a new element on the stack or ignored.)
    ###
    @drop_input()

    ###
    # If it is Text node, add an empty text node to output and push
    # its text value to input. This is because we should only append
    # characters to text nodes -- without this styles would pop out of
    # existence at the end of an element.
    ###
    if current.nodeType == 3
      log "string node"

      node = current.cloneNode()
      node.textContent = ""

      @push_both node, [current.textContent]
      return @step()

    if current.nodeType == 8
      log "comment node"
      return @step()

    ###
    # If it is a formatting style element then recurse into it.
    ###

    if (bps = current.getAttribute 'data-bps')?
      @bps = parseFloat(bps)
      @restart()

    if current.tagName in ['B', 'I', 'TT', 'EMPH', 'SPAN', 'DIV', 'P', 'PRE', 'A', 'IMG', 'BR', 'H1', 'H2', 'H3', 'H4', 'H5', 'DL', 'DT', 'DD', 'OT', 'OL', 'LI', 'UL']
      log "formatting node"

      # Dup the node and put it to processing stack
      node = current.cloneNode()
      @push_both node, Array.prototype.slice.call current.childNodes

      # Images require a customer processor
      if current.tagName == 'IMG'
        img = new Image(@, node)
        @push_output img

      # Add a pauser if required
      chars = node.getAttribute 'data-pause-chars'
      secs = node.getAttribute 'data-pause-secs'

      if chars? or secs?
        pause = new Pause(@, node, chars? and parseFloat(chars) or null,
          secs? and parseFloat(secs) or null)
        @push_output pause


      return @step()

    console.log "Unrecognized node type #{current.nodeType} with tag #{current.tagName}, skipping."
    return @step()


###
# Global initializer
###
window.modemizr = (output, input, options) ->
  (new Modemizr output, input, options).start()

###
# If jQuery is available, add a jQuery plugin.
###
if ($ = window.jQuery)?
  $.fn.modemizr = (options) ->
    return this.each () ->
      (new Modemizr this, this, options).start()


# XXX move this as an option
window.blink = (elt) ->
  tick = () =>
    elt.classList.toggle "blink"

  setInterval tick, 500.0
