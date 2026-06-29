#!/usr/bin/env swift
import CryptoKit
import Foundation

// Dev signer for the rule bundle. Generates a dev Ed25519 keypair on first run (private key
// stays local + gitignored; public key is committed), then signs dist/rules.bundle.json over its
// exact bytes -> dist/rules.bundle.json.sig. CI replaces this dev key with a managed key later.
//
// Run from the repo root: swift tools/sign-bundle.swift

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let keysDir = repoRoot.appendingPathComponent("keys")
let privateKeyURL = keysDir.appendingPathComponent("dev_private.key")
let publicKeyURL = keysDir.appendingPathComponent("dev_public.key")
let bundleURL = repoRoot.appendingPathComponent("dist/rules.bundle.json")
let signatureURL = repoRoot.appendingPathComponent("dist/rules.bundle.json.sig")

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("error: \(message)\n".utf8))
  exit(1)
}

let privateKey: Curve25519.Signing.PrivateKey
if let raw = try? Data(contentsOf: privateKeyURL) {
  guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
    fail("\(privateKeyURL.path) is not a valid raw Ed25519 private key")
  }
  privateKey = key
  print("reused dev private key (\(privateKeyURL.lastPathComponent))")
} else {
  privateKey = Curve25519.Signing.PrivateKey()
  try? FileManager.default.createDirectory(at: keysDir, withIntermediateDirectories: true)
  do {
    try privateKey.rawRepresentation.write(to: privateKeyURL)
    try privateKey.publicKey.rawRepresentation.write(to: publicKeyURL)
  } catch {
    fail("could not persist keypair: \(error)")
  }
  print("generated dev keypair -> \(keysDir.path)")
}

// Keep the committed public key in sync with the private key on every run.
try? privateKey.publicKey.rawRepresentation.write(to: publicKeyURL)

guard let bundleBytes = try? Data(contentsOf: bundleURL) else {
  fail("missing \(bundleURL.path)")
}

let signature: Data
do {
  signature = try privateKey.signature(for: bundleBytes)
} catch {
  fail("signing failed: \(error)")
}

guard privateKey.publicKey.isValidSignature(signature, for: bundleBytes) else {
  fail("self-check failed: signature does not verify")
}

do {
  try signature.write(to: signatureURL)
} catch {
  fail("could not write signature: \(error)")
}

print("signed \(bundleBytes.count)B bundle -> \(signatureURL.lastPathComponent) (\(signature.count)B sig, verified)")
print("public key (raw 32B, hex): \(privateKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined())")
