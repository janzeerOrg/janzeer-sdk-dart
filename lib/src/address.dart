/// Addresses (`AddressUtils`, `ECKey.getAddress`).
library;

import 'dart:typed_data';

import 'bytes.dart';
import 'hashes.dart';

final RegExp _addressRe = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// CANONICAL address = `"0x"` + lowercase hex of the first 20 bytes of keccak256(compressed public key).
/// This is what the node stores, hashes and expects as `senderAddress`.
String publicKeyToAddress(Uint8List compressedPublicKey) {
  if (compressedPublicKey.length != 33) {
    throw RangeError('compressed (33-byte) public key expected');
  }
  return '0x${bytesToHex(keccak256(compressedPublicKey).sublist(0, 20))}';
}

/// EIP-55 mixed-case display form (`AddressUtils.toChecksumAddress`). Presentation only — never sign or store it.
String toChecksumAddress(String address) {
  final body =
      (address.startsWith('0x') ? address.substring(2) : address).toLowerCase();
  final h = bytesToHex(keccak256(utf8ToBytes(body)));
  final sb = StringBuffer('0x');
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    final cu = c.codeUnitAt(0);
    final isLetter = cu >= 0x61 && cu <= 0x66;
    sb.write(isLetter && int.parse(h[i], radix: 16) >= 8 ? c.toUpperCase() : c);
  }
  return sb.toString();
}

/// `AddressUtils.isChecksumValid`: all-lowercase (canonical), all-uppercase, or a correctly cased EIP-55 address.
bool isChecksumValid(String address) {
  if (!_addressRe.hasMatch(address)) return false;
  final body = address.substring(2);
  if (body == body.toLowerCase() || body == body.toUpperCase()) return true;
  return toChecksumAddress(address) == address;
}

/// Shape + checksum check — exactly what the node's `@AddressChecksum` validator accepts.
bool isValidAddress(Object? address) =>
    address is String && isChecksumValid(address);

/// Canonical lowercase form; throws [FormatException] on an invalid address.
String normalizeAddress(String address) {
  if (!isValidAddress(address)) {
    throw FormatException('Invalid address: $address');
  }
  return address.toLowerCase();
}
