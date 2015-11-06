# -*- tab-width: 2 -*-

class Modemizr
  bps: 9600

  constructor: (@elt, @text) ->

  start: () ->
    if @timer or not @elt
      return

    interval = 1000.0 / (@bps / 10.0)
    console.log "bps #{@bps} interval #{interval}"
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
    chars = Math.ceil(elapsed / (1000.0 / (@bps / 10.0)))
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
