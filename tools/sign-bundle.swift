#!/usr/bin/env swift
import AppKit
import CryptoKit
import Foundation

// Run by the maintainer in their own terminal, never through an agent session, so the key (64 hex
// characters on stdin or at the hidden prompt) never lands in a transcript. Run from the repo root.

let bundleURL = URL(fileURLWithPath: "dist/rules.bundle.json")
let signatureURL = URL(fileURLWithPath: "dist/rules.bundle.json.sig")
let publicKeyURL = URL(fileURLWithPath: "keys/managed_public.key")

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("error: \(message)\n".utf8))
  exit(1)
}

func readKeyText() -> String {
  guard isatty(STDIN_FILENO) != 0 else {
    return String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
  }
  var buffer = [CChar](repeating: 0, count: 256)
  defer { buffer.withUnsafeMutableBufferPointer { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
  guard readpassphrase("Managed signing key (hidden): ", &buffer, buffer.count, RPP_REQUIRE_TTY) != nil else {
    fail("could not read the key from the terminal")
  }
  return String(cString: buffer)
}

let keyText = readKeyText().trimmingCharacters(in: .whitespacesAndNewlines)

// Copying the key from the password manager leaves it on the clipboard (and Universal Clipboard).
let pasteboard = NSPasteboard.general
if !keyText.isEmpty, pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) == keyText {
  pasteboard.clearContents()
  print("cleared the clipboard")
}

let hex = Array(keyText.utf8)
let keyBytes = hex.count == 64
  ? stride(from: 0, to: 64, by: 2).compactMap { UInt8(String(decoding: hex[$0..<$0 + 2], as: UTF8.self), radix: 16) }
  : []
guard keyBytes.count == 32 else {
  fail("expected the key as 64 hex characters")
}

guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyBytes) else {
  fail("not a valid Ed25519 private key")
}
guard let pinnedPublicKey = try? Data(contentsOf: publicKeyURL) else {
  fail("missing \(publicKeyURL.path)")
}
guard privateKey.publicKey.rawRepresentation == pinnedPublicKey else {
  fail("this key does not match \(publicKeyURL.path)")
}

guard let bundleBytes = try? Data(contentsOf: bundleURL) else {
  fail("missing \(bundleURL.path)")
}
guard let signature = try? privateKey.signature(for: bundleBytes),
  let verifier = try? Curve25519.Signing.PublicKey(rawRepresentation: pinnedPublicKey),
  verifier.isValidSignature(signature, for: bundleBytes)
else {
  fail("signing failed or the signature does not verify against \(publicKeyURL.path)")
}

do {
  try signature.write(to: signatureURL)
} catch {
  fail("could not write \(signatureURL.path): \(error)")
}
print("signed \(bundleBytes.count)B bundle -> \(signatureURL.path), verified against \(publicKeyURL.path)")
