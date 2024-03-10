var express = require('express')
var {argv} = require('process');
var app = express();
function authentication(req, res, next) {
    next();
    return;
 
}
// app.use("/builder", authentication, express.static('./web_builder')); Web builder needs to be finished in the other repo
app.use("/decryptfinal", authentication,express.static("./getkeyfromfinal"))
app.use("/verify_keys",authentication, express.static("./smite_loader"))
app.use("/keygen", authentication,express.static("./smite_keygen"));
app.use("/reenroll", authentication, express.static("./toolkit"))
app.use("/", express.static("./docs"));
app.listen(parseInt(argv[2]));