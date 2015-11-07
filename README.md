# modemizr

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

   You can also omit the input element in which case the input element
   is used in-place:

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
		cursor: false
	}
	```

Option | Description
--- | ---
`bps` | Initial BPS value for output
`cursor` | Either `false`, `true` or a string. Adds a cursor `SPAN` element at a place where the cursor is. The element has class of either `"cursor"` or the `cursor` option value if given as a string.

If you want your cursor to be visible you will need to add styling:


    ```css
	.cursor:before { content: "."; background: white; color: white; }
	```

(I'll be happy if someone can tell me how to get rid of the dot so
that it works for both DIV and PRE elements and has a matching width
to the element -- non-breaking space works but results in too wide
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

## License

[MIT License](http://santtu.mit-license.org/) © Santeri Paavolainen
