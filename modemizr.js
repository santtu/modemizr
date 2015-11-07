// Generated by CoffeeScript 1.10.0

/*
 * modemizr.coffee
 *
 * The MIT License (MIT)
 * Copyright © 2015 Santeri Paavolainen <santtu@iki.fi>
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation files
 * (the “Software”), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */


/*
 * How would you slowly drip text into HTML character-by-character?
 *
 * Plain text is easy to handle. Just muck with `textContent`. But it
 * will both not work with styles or more complex DOM structure.
 *
 * This code works by having an input and output stack. These stacks
 * mirror the DOM structure, e.g. when a DOM element is encountered in
 * the input then it is recursed into and corresponding structures get
 * pushed to input and output stacks for processing.
 *
 * The input stack actually contains arrays of input elements, with the
 * output stack (mostly, see below) mirroring each input array's
 * position in the structure. This is because for example <p>yet
 * <b>another</b> test</p> consists of three different input
 * elements at the P level. They have to be processed in order.
 *
 * So with <p>yet <b>another</b> test</p> being the input element and
 * some DIV as the output element this is what happens (the top of
 * stack is always the **current** element):
 *
 * 1. current_input = [ <P>...</P> ], current_output = DIV
 * 2. Pick the first element of current input, input_head = <P>...</P>
 * 3. Remove P from current_input and push P to output stack
 * 4. Push contents of P to input stack
 *
 * After this step the stacks are:
 *
 * input  = [[#Text(yet) <B>another</B> #Text(test)], []]
 * output = [P, DIV]
 *
 * Here #Text() is a DOM Text element, not a string. Note the empty []
 * list in input -- the first input list had only the P element which
 * was removed, leaving an empty list (it will be later popped out when
 * going back up the recursion).
 *
 * 5. current_input = [#Text(yet) <B>another</B> #Text(test)]
 * 6. input_head = #Text(yet)
 * 7. This is a text element, convert to plain string and replace at
 *    current_input head, push a #Text() element to output
 *
 * Now current_input = ["yet" <B>another</B> #Text(test)]
 *
 * 8. input_head = "yet", hooray, finally a plain string! add "y" to
 *    current_output = #Text() and modify input_head = "et"
 * 9. Keep going on, after this: input_head = "t", current_output = #Text(ye)
 * 10. ...: input_head = "", current_output = #Text(yet)
 * 11. Empty string, pop input_head and output
 *
 * Now current_input = [<B>another</B> #Text(test)]
 * and current_output = <P>yet</P>
 *
 * 12. Now input_head = <B>another</B>, push <B> to output, pop
 *     input_head and push [#Text(another)] from the B to input stack
 * 13. input_head is #Text, convert to string (see above)
 * 14. => input_head = "nother", current_output = <B>a</B>
 * 15. => input_head = "other", current_output = <B>an</B>
 * 16. ... and so on
 *
 * The process should now be ... clearer.
 *
 * How do we handle images and pauses? We use a class called
 * `Processor` which if found as current_output will be given control
 * over for a while. When finished it is popped off the output stack
 * (there is no corresponding input stack element, which is left
 * untouched).
 *
 * Handling the cursor is a bit more kludgy, but essentially it boils
 * to removing and adding a SPAN element into correct place (which is
 * **before** the current #Text() element) when moving up and down the
 * stack.
 *
 */

(function() {
  var $, Image, Modemizr, Pause, Processor, log, stringp, time,
    slice = [].slice,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  stringp = function(s) {
    return typeof s === 'string' || s instanceof String;
  };

  log = function() {
    var args;
    args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
  };

  time = function() {
    return (new Date()).getTime();
  };

  Processor = (function() {
    function Processor(master1, parentNode) {
      this.master = master1;
      this.parentNode = parentNode;
    }

    Processor.prototype.done = true;

    return Processor;

  })();

  Image = (function(superClass) {
    extend(Image, superClass);

    Image.prototype.pos = 0;

    Image.prototype.done = false;

    function Image(master, image) {
      this.image = image;
      Image.__super__.constructor.call(this, master, this.image);
      this.last = time();
      this.update();
      this.image.style.overflow = "hidden";
    }

    Image.prototype.update = function() {
      var fh, fw, ph, pw;
      fh = Math.floor(this.pos / this.image.width);
      ph = fh + 1;
      fw = this.image.width;
      pw = this.pos % this.image.width;
      return this.image.style.webkitClipPath = this.image.style.clipPath = "polygon(0px 0px, " + fw + "px 0px, " + fw + "px " + fh + "px, " + pw + "px " + fh + "px, " + pw + "px " + ph + "px, 0px " + ph + "px)";
    };


    /*
     * Calculate how many pixels we should show since last update. This
     * calculates the number of bytes we have accumulated so far and
     * approximates 8-bit images e.g. one byte per pixel to show.
     */

    Image.prototype.pixelsPending = function() {
      var bytes;
      bytes = (time() - this.last) / 1000.0 * this.master.bps * this.master.imageSpeedup / 10;
      return bytes;
    };

    Image.prototype.tick = function() {
      var pixels;
      if (this.pos >= this.image.height * this.image.width) {
        return this.done = true;
      }
      pixels = this.pixelsPending();
      if (pixels > 0) {
        this.last = time();
        this.pos += pixels;
        return this.update();
      }
    };

    return Image;

  })(Processor);

  Pause = (function(superClass) {
    extend(Pause, superClass);

    Pause.prototype.ticks = 0;

    function Pause(master, parent, chars1, secs1) {
      this.chars = chars1;
      this.secs = secs1;
      this.start = time();
      this.done = this.donep();
      Pause.__super__.constructor.call(this, master, parent);
    }

    Pause.prototype.donep = function() {
      var pending;
      log("donep: ticks " + this.ticks + " chars " + this.chars + " elapsed " + (time() - this.start) + " secs " + this.secs);
      pending = ((this.chars != null) && this.ticks < this.chars) || ((this.secs != null) && (time() - this.start) < (1000.0 * this.secs));
      log("pending: " + pending);
      return !pending;
    };

    Pause.prototype.tick = function() {
      this.ticks++;
      return this.done = this.donep();
    };

    return Pause;

  })(Processor);

  Modemizr = (function() {

    /*
     * Default parameters
     */
    Modemizr.prototype.bps = 300;

    Modemizr.prototype.cursor = false;

    Modemizr.prototype.blink = false;

    Modemizr.prototype.imageSpeedup = 100;

    Modemizr.prototype.blinker = null;

    Modemizr.prototype.timer = null;


    /*
     * Output is a stack of output elements. It starts with the initial
     * `output` container given at init.
     */

    Modemizr.prototype.output = [];

    Modemizr.prototype.root = null;


    /*
     * Input is an stack of arrays. When an empty array is encountered,
     * then output value is removed. Similarly if output needs to
     * recurse, then a new input array is pushed in.
     */

    Modemizr.prototype.input = [];


    /*
     * Output should always be a single node, input can either be an
     * array of elements, or a single element. If a single element is
     * given then its **child nodes** are used, not the node itself.
     */

    function Modemizr(output, input, options) {
      var child, nodes;
      if (options != null) {
        if (options.bps != null) {
          this.bps = options.bps;
        }
        if (options.cursor != null) {
          this.cursor = options.cursor;
        }
        if (options.blink != null) {
          this.blink = options.blink;
        }
        if (options.imageSpeedup != null) {
          this.imageSpeedup = options.imageSpeedup;
        }
      }
      if (output == null) {
        return;
      }
      if (input == null) {
        input = output;
      }
      this.output = [output];
      this.root = output;
      if ((options != null) && (options.show != null) && options.show) {
        if (this.root.style.display === "none") {
          this.root.style.display = "block";
        }
      }

      /*
       * If input is the same as output, grab node content first and then
       * clear it.
       */
      if (output === input) {
        nodes = Array.prototype.slice.call(input.childNodes);
        while ((child = input.firstChild) != null) {
          input.removeChild(child);
        }
        input = nodes;
      }

      /*
       * If we are passed a plain input node grab its children only.
       */
      if (!(input instanceof Array) && (input.childNodes != null)) {
        input = input.childNodes;
      }

      /*
       * ... and remember to use slice to ensure it is a true array, not
       * an object of childNodes
       */
      this.input = [Array.prototype.slice.call(input)];
      log("output", this.output, "input", this.input);
    }

    Modemizr.prototype.restart = function() {
      this.stop();
      return this.start();
    };

    Modemizr.prototype.start = function() {
      var blink_interval, interval;
      if (this.timer != null) {
        return;
      }
      interval = 1000.0 / (this.bps / 10.0);
      this.last = (new Date()).getTime();
      this.timer = setInterval(((function(_this) {
        return function() {
          return _this.tick();
        };
      })(this)), interval);
      if (this.blink) {
        blink_interval = parseFloat(this.blink === this.blink) ? this.blink : 500.0;
        this.blinker = setInterval(((function(_this) {
          return function() {
            return _this.blinks();
          };
        })(this)), blink_interval);
      }
      return this;
    };

    Modemizr.prototype.stop = function() {
      if (this.timer != null) {
        clearInterval(this.timer);
        this.timer = null;
      }
      if (this.blinker != null) {
        clearInterval(this.blinker);
        this.blinker = null;
        this.root.classList.remove('blink');
      }
      return this;
    };

    Modemizr.prototype.blinks = function() {
      return this.root.classList.toggle('blink');
    };


    /*
     * Count the number of characters that shold be output to keep the
     * BPS value correct since `last` when now is `now`.
     */

    Modemizr.prototype.countCharsNeeded = function(last, now) {
      var chars, elapsed;
      elapsed = now - last;
      chars = Math.round(elapsed / (1000.0 / (this.bps / 10.0)));
      return chars;
    };

    Modemizr.prototype.tick = function() {
      var chars, now, results;
      if (this.input.length === 0) {
        this.stop();
        return;
      }
      now = (new Date()).getTime();
      chars = this.countCharsNeeded(this.last, now);
      if (chars > 0) {
        this.last = now;
        results = [];
        while (chars-- > 0) {
          results.push(this.step());
        }
        return results;
      }
    };

    Modemizr.prototype.pop_both = function() {
      this.pop_output();
      return this.pop_input();
    };

    Modemizr.prototype.pop_input = function() {
      return this.input.pop();
    };

    Modemizr.prototype.pop_output = function() {
      if (this.cursor) {
        this.pop_cursor();
      }
      return this.output.pop();
    };

    Modemizr.prototype.current_output = function() {
      return this.output[this.output.length - 1];
    };


    /*
     * Remove cursor from the topmost output element.
     */

    Modemizr.prototype.pop_cursor = function() {
      var cursor, cursors, output, results;
      output = this.current_output();
      if (output.getElementsByClassName != null) {
        cursors = output.getElementsByClassName("cursor");
        results = [];
        while (cursors.length > 0) {
          cursor = cursors[0];
          results.push(cursor.remove());
        }
        return results;
      }
    };


    /*
     * If the topmost element is a text node, add cursor **after** it (in
     * its parent child node list). For any other element type we don't
     * do anything as we are guaranteed to get a text node eventually
     * here.
     */

    Modemizr.prototype.push_cursor = function() {
      var cursor, output;
      output = this.current_output();
      if (((output.nodeType != null) && output.nodeType === 3) || (output instanceof Processor)) {
        cursor = document.createElement("span");
        cursor.className = (stringp(this.cursor)) && this.cursor || "cursor";
        return output.parentNode.appendChild(cursor);
      }
    };

    Modemizr.prototype.push_both = function(node, content) {
      if (this.cursor) {
        this.pop_cursor();
      }
      this.output[this.output.length - 1].appendChild(node);
      this.output.push(node);
      this.input.push(content);
      if (this.cursor) {
        return this.push_cursor();
      }
    };

    Modemizr.prototype.push_output = function(node) {
      if (this.cursor) {
        this.pop_cursor();
      }
      this.output.push(node);
      if (this.cursor) {
        return this.push_cursor();
      }
    };


    /*
     * Remove the current head element of the top input. Remember, input
     * is a stack of arrays.
     */

    Modemizr.prototype.drop_input = function() {
      return this.input[this.input.length - 1].shift();
    };


    /*
     * Produce output of "one character" or its equivalent.
     */

    Modemizr.prototype.step = function() {
      var bps, chars, current, img, input, node, output, pause, ref, secs;
      if (this.input.length === 0 || this.output.length === 0) {
        while (this.output.length) {
          this.pop_output();
        }
        this.stop();
        return;
      }
      output = this.output[this.output.length - 1];
      input = this.input[this.input.length - 1];
      if (output instanceof Processor) {
        log("processing");
        output.tick();
        if (!output.done) {
          return;
        }
        this.pop_output();
        return this.step();
      }
      if (input.length === 0) {
        this.pop_both();
        return this.step();
      }
      current = input[0];
      log("current", current);

      /*
       * If it is a plain string, easy -- pick one character and append
       * to output (it will always be a Text element at this point).
       */
      if (stringp(current)) {
        if (current.length === 0) {
          this.drop_input();
          return this.step();
        }
        log("plain string", current);
        output.textContent += current[0];
        input[0] = current.slice(1);
        return;
      }
      log("not string");

      /*
       * All other types get dropped from the input and replaced with
       * something else (a new element on the stack or ignored.)
       */
      this.drop_input();

      /*
       * If it is Text node, add an empty text node to output and push
       * its text value to input. This is because we should only append
       * characters to text nodes -- without this styles would pop out of
       * existence at the end of an element.
       */
      if (current.nodeType === 3) {
        log("string node");
        node = current.cloneNode();
        node.textContent = "";
        this.push_both(node, [current.textContent]);
        return this.step();
      }
      if (current.nodeType === 8) {
        log("comment node");
        return this.step();
      }

      /*
       * If it is a formatting style element then recurse into it.
       */
      if ((bps = current.getAttribute('data-bps')) != null) {
        this.bps = parseFloat(bps);
        this.restart();
      }
      if ((ref = current.tagName) === 'B' || ref === 'I' || ref === 'TT' || ref === 'EMPH' || ref === 'SPAN' || ref === 'DIV' || ref === 'P' || ref === 'PRE' || ref === 'A' || ref === 'IMG' || ref === 'BR' || ref === 'H1' || ref === 'H2' || ref === 'H3' || ref === 'H4' || ref === 'H5' || ref === 'DL' || ref === 'DT' || ref === 'DD' || ref === 'OT' || ref === 'OL' || ref === 'LI' || ref === 'UL') {
        log("formatting node");
        node = current.cloneNode();
        this.push_both(node, Array.prototype.slice.call(current.childNodes));
        if (current.tagName === 'IMG') {
          img = new Image(this, node);
          this.push_output(img);
        }
        chars = node.getAttribute('data-pause-chars');
        secs = node.getAttribute('data-pause-secs');
        if ((chars != null) || (secs != null)) {
          pause = new Pause(this, node, (chars != null) && parseFloat(chars) || null, (secs != null) && parseFloat(secs) || null);
          this.push_output(pause);
        }
        return this.step();
      }
      console.log("Unrecognized node type " + current.nodeType + " with tag " + current.tagName + ", skipping.");
      return this.step();
    };

    return Modemizr;

  })();


  /*
   * Global initializer
   */

  window.modemizr = function(output, input, options) {
    return (new Modemizr(output, input, options)).start();
  };


  /*
   * If jQuery is available, add a jQuery plugin.
   */

  if (($ = window.jQuery) != null) {
    $.fn.modemizr = function(options) {
      return this.each(function() {
        return (new Modemizr(this, this, options)).start();
      });
    };
  }

  window.blink = function(elt) {
    var tick;
    tick = (function(_this) {
      return function() {
        return elt.classList.toggle("blink");
      };
    })(this);
    return setInterval(tick, 500.0);
  };

}).call(this);
