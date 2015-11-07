# -*- tab-width: 2 -*-

###
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
###

stringp = (s) -> typeof s == 'string' or s instanceof String
log = (args...) ->
#  console.log.apply(console, args)

time = () -> (new Date()).getTime()

class Pause
  ticks: 0

  constructor: (@chars, @secs, options) ->
    @start = time()
    @done = @donep()

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
  bps: 1200

  ###
  # Output is a stack of output elements. It starts with the initial
  # `output` container given at init.
  ###
  output: []

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
    if options? and options.bps?
      @bps = options.bps

    if not output?
      return

    if not input?
      input = output

    @output = [output]

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
    @

  stop: () ->
    if @timer?
      clearInterval @timer

    @timer = null
    @

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
    @output.pop()
    @input.pop()

  pop_output: () ->
    @output.pop()

  push_both: (node, content) ->
    @output[@output.length - 1].appendChild node
    @output.push node
    @input.push content

  push_output: (node) ->
    @output.push node

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
      return

    output = @output[@output.length - 1]
    input = @input[@input.length - 1]

    if output instanceof Pause
      log "pausing"

      output.tick()

      if not output.done
        return

      @pop_output()
      return @step

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
    if current.tagName in ['B', 'I', 'TT', 'EMPH', 'SPAN', 'DIV', 'P', 'PRE', 'A', 'IMG', 'BR', 'H1', 'H2', 'H3', 'H4', 'H5', 'DL', 'DT', 'DD', 'OT', 'OL', 'LI', 'UL']
      log "formatting node"

      node = current.cloneNode()

      @push_both node, Array.prototype.slice.call current.childNodes

      chars = node.getAttribute 'data-pause-chars'
      secs = node.getAttribute 'data-pause-secs'

      if chars? or secs?
        @push_output new Pause(chars? and parseFloat(chars) or null,
          secs? and parseFloat(secs) or null)

      bps = node.getAttribute 'data-bps'

      if bps?
        @bps = parseFloat(bps)
        @restart()

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
