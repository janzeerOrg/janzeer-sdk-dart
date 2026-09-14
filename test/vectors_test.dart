// Conformance: every entry of sdk_conformance/vectors/wallet-parity-vectors.json must be reproduced byte-for-byte.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:janzeer_sdk/crypto.dart' as compat;
import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  final v = jsonDecode(
          File('test/vectors/wallet-parity-vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final hd = v['hd'] as Map<String, dynamic>;
  final rawKey = v['rawKey'] as Map<String, dynamic>;
  Account signer() => Account.fromPrivateKey(rawKey['privHex'] as String);

  group('vendored vectors', () {
    test('match the conformance kit checksums', () {
      for (final line in File('test/vectors/SHA256SUMS')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)) {
        final parts = line.split(RegExp(r'\s+'));
        final actual = crypto.sha256
            .convert(File('test/vectors/${parts[1]}').readAsBytesSync())
            .toString();
        expect(actual, parts[0], reason: parts[1]);
      }
    });
    test('are the format this SDK targets', () {
      expect(v['vectorsVersion'], SpecVersion.vectors);
      expect(v['networkId'], networkId);
    });
  });

  group('hd', () {
    test('mnemonic → seed → m/0/0/0 → address', () {
      final seed = mnemonicToSeed(hd['mnemonic'] as String,
          passphrase: hd['passphrase'] as String);
      expect(bytesToHex(seed), hd['seedHex']);
      expect(bytesToHex(deriveDefault(seed).priv), hd['privHex']);
      final a = Account.fromMnemonic(hd['mnemonic'] as String,
          passphrase: hd['passphrase'] as String);
      expect(a.privateKeyHex, hd['privHex']);
      expect(a.publicKeyHex, hd['pubHex']);
      expect(a.address, hd['address']);
      expect(Mnemonic.validate(hd['mnemonic'] as String), isTrue);
    });
    test('raw key → address', () {
      final a = signer();
      expect(a.publicKeyHex, rawKey['pubHex']);
      expect(a.address, rawKey['address']);
    });
    test('addresses: EIP-55 overlay', () {
      for (final e in v['addresses'] as List<dynamic>) {
        final m = e as Map<String, dynamic>;
        expect(toChecksumAddress(m['lower'] as String), m['checksum']);
        expect(isChecksumValid(m['checksum'] as String), isTrue);
      }
    });
    test('scaled: toScaledLong table', () {
      for (final e in v['scaled'] as List<dynamic>) {
        final m = e as Map<String, dynamic>;
        expect(toScaledLong(m['in'] as String), BigInt.from(m['out'] as int));
      }
    });
  });

  SignedTx check(UnsignedTx unsigned, Map<String, dynamic> t) {
    if (t['preimageHex'] != null) {
      expect(bytesToHex(unsigned.preimage()), t['preimageHex']);
    }
    expect(unsigned.hash(), t['hash']);
    final signed = signer().signTx(unsigned);
    expect(signed.signature, t['signature']);
    expect(signed.senderPublicKey, t['publicKey']);
    expect(signer().verify(signed.hash, signed.signature), isTrue);
    expect(
        verifyHash(signed.hash, signed.signature,
            'ff${signed.senderPublicKey.substring(2)}'),
        isFalse);
    return signed;
  }

  group('transactions (TxBuilder + Account.signTx)', () {
    test('transferTx', () {
      final t = v['transferTx'] as Map<String, dynamic>;
      final s = check(
          TxBuilder.transfer(
              from: t['senderAddress'] as String,
              to: t['recipientAddress'] as String,
              amount: t['amount'] as String,
              data: t['data'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
      expect(s.toRestBody(), containsPair('hash', t['hash']));
      expect(s.toRestBody(), containsPair('senderSignature', t['signature']));
      expect(s.toRestBody(), containsPair('data', t['data']));
    });
    test('transferNoMemoTx', () {
      final t = v['transferNoMemoTx'] as Map<String, dynamic>;
      final s = check(
          TxBuilder.transfer(
              from: t['senderAddress'] as String,
              to: t['recipientAddress'] as String,
              amount: t['amount'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
      expect(s.toRestBody().containsKey('data'), isFalse);
    });
    test('promoterTx (registerValidator)', () {
      final t = v['promoterTx'] as Map<String, dynamic>;
      check(
          TxBuilder.registerValidator(
              from: t['senderAddress'] as String,
              validatorKey: t['promoterKey'] as String,
              amount: t['amount'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
    });
    test('exitPromoterTx (exitValidator)', () {
      final t = v['exitPromoterTx'] as Map<String, dynamic>;
      check(
          TxBuilder.exitValidator(
              from: t['senderAddress'] as String,
              validatorKey: t['promoterKey'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
    });
    test('tokenCreateTx', () {
      final t = v['tokenCreateTx'] as Map<String, dynamic>;
      check(
          TxBuilder.token.create(
              from: t['senderAddress'] as String,
              symbol: t['symbol'] as String,
              name: t['name'] as String,
              decimals: t['decimals'] as int,
              cap: t['cap'] as String,
              amount: t['amount'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
    });
    test('tokenTransferTx', () {
      final t = v['tokenTransferTx'] as Map<String, dynamic>;
      check(
          TxBuilder.token.transfer(
              from: t['senderAddress'] as String,
              tokenId: t['tokenId'] as String,
              amount: t['amount'] as String,
              recipient: t['recipient'] as String,
              fee: t['fee'] as String,
              nonce: t['nonce'] as int,
              timestamp: t['timestamp'] as int),
          t);
    });
  });

  group('package:janzeer_sdk/crypto.dart compat layer', () {
    test('reproduces the legacy janzeer_crypto.dart results', () {
      final a = compat.accountFromMnemonic(hd['mnemonic'] as String);
      expect([a.privHex, a.pubHex, a.address],
          [hd['privHex'], hd['pubHex'], hd['address']]);
      final t = v['transferTx'] as Map<String, dynamic>;
      final s = compat.buildSignedTransfer(
          timestamp: t['timestamp'] as int,
          fee: t['fee'] as String,
          nonce: t['nonce'] as int,
          senderAddress: t['senderAddress'] as String,
          publicKey: t['publicKey'] as String,
          recipientAddress: t['recipientAddress'] as String,
          amount: t['amount'] as String,
          data: t['data'] as String,
          privHex: rawKey['privHex'] as String);
      expect(s['hash'], t['hash']);
      expect(s['senderSignature'], t['signature']);
      final p = v['promoterTx'] as Map<String, dynamic>;
      expect(
          compat.buildSignedPromoter(
              timestamp: p['timestamp'] as int,
              fee: p['fee'] as String,
              nonce: p['nonce'] as int,
              senderAddress: p['senderAddress'] as String,
              publicKey: p['publicKey'] as String,
              amount: p['amount'] as String,
              promoterKey: p['promoterKey'] as String,
              privHex: rawKey['privHex'] as String)['senderSignature'],
          p['signature']);
      final e = v['exitPromoterTx'] as Map<String, dynamic>;
      expect(
          compat.buildSignedExitPromoter(
              timestamp: e['timestamp'] as int,
              fee: e['fee'] as String,
              nonce: e['nonce'] as int,
              senderAddress: e['senderAddress'] as String,
              publicKey: e['publicKey'] as String,
              promoterKey: e['promoterKey'] as String,
              privHex: rawKey['privHex'] as String)['senderSignature'],
          e['signature']);
      for (final key in ['tokenCreateTx', 'tokenTransferTx']) {
        final tk = v[key] as Map<String, dynamic>;
        final r = compat.buildSignedTokenTx(
            timestamp: tk['timestamp'] as int,
            fee: tk['fee'] as String,
            nonce: tk['nonce'] as int,
            senderAddress: tk['senderAddress'] as String,
            publicKey: tk['publicKey'] as String,
            op: tk['op'] as int,
            tokenId: tk['tokenId'] as String,
            symbol: tk['symbol'] as String,
            name: tk['name'] as String,
            decimals: tk['decimals'] as int,
            cap: tk['cap'] as String?,
            amount: tk['amount'] as String?,
            recipient: tk['recipient'] as String?,
            privHex: rawKey['privHex'] as String);
        expect(r['hash'], tk['hash']);
        expect(r['senderSignature'], tk['signature']);
      }
      expect(compat.deriveAccountIsolate(hd['mnemonic'] as String)['address'],
          hd['address']);
    });
  });
}
