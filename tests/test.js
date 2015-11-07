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
        var m = window.m = modemizr(output, input, window.modemizr_options);
    });

 window.addEventListener("load", function() {
     var controls, elt, i;

     var control_bps = function() {
         if (window.m === undefined || window.m === null)
             return;

         window.m.bps = parseFloat(this.dataset.bps);
         return false;
     };

     var control_state = function() {
         if (window.m === undefined || window.m === null)
             return;

         if (this.dataset.action == 'stop')
             window.m.stop();

         if (this.dataset.action == 'start')
             window.m.start();

         return false;
     };

     controls = document.getElementsByClassName("control-bps");

     for (i = 0; i < controls.length; i++) {
         elt = controls[i];
         elt.addEventListener("click", control_bps);
     }

     controls = document.getElementsByClassName("control-state");
     for (i = 0; i < controls.length; i++) {
         elt = controls[i];
         elt.addEventListener("click", control_state);
     }
 });
})();
