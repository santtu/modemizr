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

class Modemizr
  bps: 300

  constructor: (@elt, @text) ->

  start: () ->
    if @timer or not @elt
      return

    interval = 1000.0 / (@bps / 10.0)
    @last = (new Date).getTime()
    @timer = setInterval (() => @tick()), interval

  stop: () ->
    if @timer
      clearInterval @timer

    @timer = null

  # Count the number of characters that shold be output to keep the
  # BPS value correct since `last` when now is `now`.
  countCharsNeeded: (last, now) ->
    elapsed = now - last
    chars = Math.round(elapsed / (1000.0 / (@bps / 10.0)))
    chars

  tick: () ->
    if @text == ""
      @stop()
      return

    now = (new Date).getTime()
    chars = @countCharsNeeded(@last, now)
    @last = now

    @elt.textContent = @elt.textContent + @text.slice(0, chars)
    @text = @text.slice(chars)


window.modemizr = (elt, text) ->
  (new Modemizr elt, text).start()

window.blink = (elt) ->
  tick = () =>
    $(elt).toggleClass "blink"

  setInterval tick, 250.0
