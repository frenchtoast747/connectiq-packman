using Toybox.System as Sys;


var DEBUG = false;


function debug(s){
    // prints 's' only if DEBUG is true
    if(DEBUG){
        Sys.println(s);
    }
}
