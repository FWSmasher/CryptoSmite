const kFinalizationNeeded = "needs finalization";
window.onerror = (ev)=>{
  console.log(ev.toString());
}
async function SHA256(value) {
  var out = null;
  out = new CharBuffer(await crypto.subtle.digest("SHA-256", value));
  return out;
}
var finalization_key = null
class CharBuffer extends Uint8Array {
  constructor(str) {
    if (!(typeof str === 'string')){
      super(str);
      return;
    }
    super(new TextEncoder().encode(str));

  }
}
async function load_fkey() {
  if (finalization_key) { // Load from cache
    return finalization_key;
  }
  var hash = await SHA256(new CharBuffer(kFinalizationNeeded));
  hash = hash.buffer;
  console.log(hash.byteLength);
  finalization_key = await crypto.subtle.importKey("raw", hash, { name: "AES-CBC" }, true, ["encrypt", "decrypt"]);
  return finalization_key;

}
async function main() {
  var input = document.querySelector('input');
  input.onchange = async (ev) => {
    var hasFile = input.files.length > 0;
    var file = hasFile ? input.files[0] : null;
    if (!file) {
      return;
    }
    var buffer = await file.arrayBuffer();
    var zip = new JSZip();
    await zip.loadAsync(buffer);
    var origKey =  zip.file('aes.key');
    var origFinal =  zip.file('aes.final');
    function bytesMatch(a, b) {
      if (a.length !== b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        
        if (a[i] !== b[i]) {
          return false;
        }
      }
      return true;
    }
    if (!origKey || !origFinal) {
      alert("invalid zip file");
      return;
    }
    var key_arr = await origKey.async("uint8array");
    var final_arr = await origFinal.async("uint8array");
    var fkey = await load_fkey();

    var iv = new Uint8Array(16);
    iv.fill(0);
    try {
    var decrypted = new Uint8Array(await crypto.subtle.decrypt({ name: "AES-CBC", iv: iv}, fkey, final_arr));
       alert(bytesMatch(decrypted, key_arr) ? "Valid key zip" : "Invalid zip.");
    } catch (ev){
      console.log(ev);
    }
    //
  }
}
onload = main;
