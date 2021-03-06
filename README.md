# modemizr

See modemizr in action at
[http://santtu.github.io/modemizr/](http://santtu.github.io/modemizr/).

modemizr is a simple Javascript extension that simulates the effect of
reading the page using a modem, typically at low bits-per-second (bps)
rates of 300 to 9600 (you are probably browsing this page on a
connection with **megabit** per second speed).

For samples see `tests/` directory.

## Usage

### Without jQuery

1. Include it on page:

   ```html
   <script src="modemizr.js"></script>
   ```

2. Call `modemizr` with the input and output element and potential
   options:

   ```javascript
   modemizr(document.getElementById("output"),
             document.getElementById("input"),
             { ... options ... });
   ```

   You can also omit the input element in which case the output element
   is used in-placep:

   ```javascript
   modemizr(document.getElementById("output"));
   ```

For options see below.

### With jQuery

1. Include it on page:

   ```html
   <script src="modemizr.js"></script>
   ```

2. Call the plugin:

   ```javascript
   $('#output').modemizr();
   ```

## Options

You can pass an options hash for both `modemizr` and to the jQuery
plugin (the values below are the defaults):

```javascript
{
    bps: 300,
    cursor: false,
    blink: false,
    imageSpeedup: 100,
	show: true
}
```

Option | Description
--- | ---
`bps` | Initial BPS value for output
`cursor` | Either `false`, `true` or a string. Adds a cursor `SPAN` element at a place where the cursor is. The element has class of either `"cursor"` or the `cursor` option value if given as a string.
`blink` | Enable blinking cursor by setting `true` or the blink interval in milliseconds
`imageSpeedup` | How much image loading is sped up
`show`| Whether to enable automatic de-hiding of the output element

If you want your cursor to be visible you will need to add styling:

```css
.cursor:before { content: "."; background: white; color: white; }
.blink .cursor:before { content: ""; }
```

(I'll be happy if someone can tell me how to get rid of the dot so
that it works for both DIV and PRE elements and has a matching width
to the element — non-breaking space works but results in too wide
cursor.)

## HTML controls

It is possible to change BPS speed and pause by including attributes
in the HTML elements. They have an effect when the element is
encountered, so a `SPAN` with a pause will pause **before** its
contents are processed.

Attribute | Description
--- | ---
`data-pause-chars` | Pause for the equivalent time that would be taken to output this many characters
`data-pause-secs` | Pause for this many seconds (may be a decimal number)
`data-bps` | Change BPS to the value

For example:

```html
<p data-pause-chars="10">10 char pause</p>
<p data-pause-secs="10">10 second pause</p>
<p data-bps="19200">Upgrade!!!!</p>
```

## Image loading

IMG elements are shown in a way that simulates pixel-by-pixel loading
over a slow link. It assumes that each pixel is one byte (8 bits)
approximating 8-bit indexed color image pixel density and calculates
how many pixels can be shown. (This is not an exact calculation and
neither it is meant to be.)

After this the number of pixels shown is multiplied by `imageSpeedup`
parameter which by default is 100. This is because image loading at
*true speeds* would be horrendously slow and would move the "slow
loading" effect from curiosity to purely tedious horror.

You can change the `imageSpeedup` parameter via options to 1 if you
wish. To. Wait. Forever.

## Whitespace and PRE tags

Normally whitespace in HTML does not matter, so from visual point of
view the two following DIVs are the same:

```html
<div>a b</div>
<div>a                                                  b</div>
```

However these two are not:

```html
<pre>a b</pre>
<pre>a                                                  b</pre>
```

Modemizr will output all whitespace characters (spaces, newlines etc.)
when it is inside a PRE output element. Otherwise it will ignore (skip
over) multiple whitspace characters in the input.

This heuristic is not fool-proof as it is possible to both turn PRE
elements into non-whitespace-conserving element and other elements to
whitespace-conserving via CSS `white-space` property.

## License

[MIT License](http://santtu.mit-license.org/) © Santeri Paavolainen

## Known bugs

* Slow image loading doesn't work in Firefox. Images are shown
  completely straight away. The delay still occurs, so there is a
  pause after the image is shown.
