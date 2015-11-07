// test.js

(function() {
    var name = /[^/]*$/.exec(document.location)[0];

    // The array is just to keep js linter not complaining about
    // document.write.
    ([document])[0].write(
        '<script src="../modemizr.js"></script>',
        '<link rel="stylesheet" type="text/css" href="test.css" />',
        '<h1>' + name + '</h1>');

    document.title = name;

    window.addEventListener("load", function() {
        var input = document.getElementsByClassName("input")[0];
        var output = document.getElementsByClassName("output")[0];
        var m = modemizr(output, input, window.modemizr_options);
    });
})();
