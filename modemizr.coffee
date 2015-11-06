# -*- tab-width: 2 -*-

# Text is easy to handle, but what to do with HTML elements?
#
# One could of course ignore any formatting and just use
# textContent. That works of course.
#
# Another way is to handle text-like formatting (**not** IMG, HR etc.)
# so that they are output too, but with their contents at the correct
# pace. This requires tracking **what** element you are currently
# appending to and what you are reading **from**.
#
# For simplicity let's look at <b>abc</b>. We start with an empty
# output and start scanning the input element's contents. We hit the
# B element.
#
# Now set a new B element (or better still, a copy of the original to
# keep classes etc. intact but drop content) as output target. Start
# scanning B's contents.
#
# Encounter string "abc". Take "a", put it to the output B element and
# put "bc" back as "to be scanned".
#
# Keep doing this until hitting the end of scan list (e.g. end of
# string).
#
# For deeper structure this needs of course stacks to keep the state.
#

stringp = (s) -> typeof s == 'string' or s instanceof String
log = (args...) ->
#  console.log.apply(console, args)

class Modemizr
  bps: 1200

  # Output is a stack of output elements. It starts with the initial
  # `output` container given at init.
  output: []

  # Input is an stack of arrays. When an empty array is encountered,
  # then output value is removed. Similarly if output needs to
  # recurse, then a new input array is pushed in.
  input: []

  constructor: (output, input) ->
    @output = [output]
    @input = [Array.prototype.slice.call input]
    log "output", @output, "input", @input

  start: () ->
    if @timer
      return

    interval = 1000.0 / (@bps / 10.0)
    @last = (new Date).getTime()
    @timer = setInterval (() => @tick()), interval
    @

  stop: () ->
    if @timer
      clearInterval @timer

    @timer = null
    @

  # Count the number of characters that shold be output to keep the
  # BPS value correct since `last` when now is `now`.
  countCharsNeeded: (last, now) ->
    elapsed = now - last
    chars = Math.round(elapsed / (1000.0 / (@bps / 10.0)))
    chars

  finished: () ->
    @input.length == 0

  tick: () ->
    if @finished()
      @stop()
      return

    now = (new Date).getTime()
    chars = @countCharsNeeded(@last, now)
    @last = now

    while chars-- > 0
      @step()


  pop_both: () ->
    @output.pop()
    @input.pop()

  push_both: (node, content) ->
    @output[@output.length - 1].appendChild node
    @output.push node

    @input[@input.length - 1].shift()
    @input.push content

  drop_input: () ->
    @input[@input.length - 1].shift()

  step: () ->
    if @input.length == 0 or @output.length == 0
      return

    output = @output[@output.length - 1]
    input = @input[@input.length - 1]

    if input.length == 0
      @pop_both()
      return @step()

    current = input[0]
    log "current", current

    # If it is a plain string, easy -- pick one character and append
    # to output (it will always be a Text element at this point).
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

    # If it is Text node, add an empty text node to output and push
    # its text value to input. This is because we should only append
    # characters to text nodes -- without this styles would pop out of
    # existence at the end of an element.
    if current.nodeType == 3
      log "string node"

      node = current.cloneNode()
      node.textContent = ""

      # output.appendChild node
      # @output.push node

      # input.shift()
      # @input.push [current.textContent]
      @push_both node, [current.textContent]

      return @step()

    if current.nodeType == 8
      log "comment node"
      @drop_input()
      return @step()

    # If it is a formatting style element then recurse into it.
    if current.tagName in ['B', 'I', 'EMPH', 'SPAN', 'DIV', 'P', 'PRE', 'A', 'IMG']
      log "formatting node"

      node = current.cloneNode()
      @push_both node, Array.prototype.slice.call current.childNodes

      return @step()

    console.log "Unrecognized node type #{current.nodeType} with tag #{current.tagName}, skipping."
    @drop_input()
    return @step()


window.modemizr = (output, input) ->
  (new Modemizr output, input).start()


window.blink = (elt) ->
  tick = () =>
    elt.classList.toggle "blink"

  setInterval tick, 500.0
