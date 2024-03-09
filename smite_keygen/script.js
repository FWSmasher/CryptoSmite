const DIGEST_LENGTH = 256 / 8;
const kFinalizationNeeded = "needs finalization";
class CharBuffer extends Uint8Array {
  toString() {
    return new TextDecoder().decode(this);
  }
}

async function SHA256(value) {
  var out = null;
  out = new CharBuffer(await crypto.subtle.digest("SHA-256", value));
  return out;
}
const kFinalizationNeededBuf = new TextEncoder().encode(kFinalizationNeeded);
function downloadBytesSync(name, bytes) {
  var blob = new Blob([bytes], {
    type: "application/octet-stream"
  });
  var url = URL.createObjectURL(blob);
  var elem = document.createElement('a');
  elem.href = url;
  elem.download = name;
  elem.click();
}
async function main() {
 
  var x = await SHA256(kFinalizationNeededBuf);
  var buffer = x.buffer;
  let iv;
  iv = new Uint8Array(16);
  iv.fill(0);

  var aesKeyBytes = crypto.getRandomValues(new Uint8Array(256 / 8));
  var aesEncryptorKey = await crypto.subtle.importKey("raw", buffer, { name: "AES-CBC" }, true, ["encrypt", "decrypt"]);
  var aesFinal = await crypto.subtle.encrypt({
    "name": "AES-CBC",
    iv: iv,

  }, aesEncryptorKey, aesKeyBytes);
  console.log(new Uint8Array(aesKeyBytes));
  console.log(new Uint8Array(aesFinal));

  console.log(
    new Uint8Array(await crypto.subtle.decrypt({
      name: "AES-CBC",
      iv: iv
    }, aesEncryptorKey, aesFinal))
  );
  var zip = new JSZip();
  zip.file("aes.key", aesKeyBytes);
  zip.file("aes.final", aesFinal);
  var bl = await zip.generateAsync({type: "uint8array"});
  downloadBytesSync("aes.zip", bl);

}
onload = main;