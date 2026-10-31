import 'dart:math';
import 'dart:typed_data';

import 'package:janzeer_sdk/src/bip39.dart';
import 'package:janzeer_sdk/src/wordlist_english.dart';
import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

/// The 24 English vectors of the BIP39 reference implementation (trezor/python-mnemonic `vectors.json`):
/// entropy hex → mnemonic. The passphrase-seed column is omitted: Janzeer does not use the BIP39 seed.
const List<List<String>> referenceVectors = [
  [
    '00000000000000000000000000000000',
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
  ],
  [
    '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f',
    'legal winner thank year wave sausage worth useful legal winner thank yellow'
  ],
  [
    '80808080808080808080808080808080',
    'letter advice cage absurd amount doctor acoustic avoid letter advice cage above'
  ],
  [
    'ffffffffffffffffffffffffffffffff',
    'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong'
  ],
  [
    '000000000000000000000000000000000000000000000000',
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent'
  ],
  [
    '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f',
    'legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal will'
  ],
  [
    '808080808080808080808080808080808080808080808080',
    'letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter always'
  ],
  [
    'ffffffffffffffffffffffffffffffffffffffffffffffff',
    'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo when'
  ],
  [
    '0000000000000000000000000000000000000000000000000000000000000000',
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art'
  ],
  [
    '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f',
    'legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth title'
  ],
  [
    '8080808080808080808080808080808080808080808080808080808080808080',
    'letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless'
  ],
  [
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote'
  ],
  [
    '9e885d952ad362caeb4efe34a8e91bd2',
    'ozone drill grab fiber curtain grace pudding thank cruise elder eight picnic'
  ],
  [
    '6610b25967cdcca9d59875f5cb50b0ea75433311869e930b',
    'gravity machine north sort system female filter attitude volume fold club stay feature office ecology stable narrow fog'
  ],
  [
    '68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c',
    'hamster diagram private dutch cause delay private meat slide toddler razor book happy fancy gospel tennis maple dilemma loan word shrug inflict delay length'
  ],
  [
    'c0ba5a8e914111210f2bd131f3d5e08d',
    'scheme spot photo card baby mountain device kick cradle pact join borrow'
  ],
  [
    '6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3',
    'horn tenant knee talent sponsor spell gate clip pulse soap slush warm silver nephew swap uncle crack brave'
  ],
  [
    '9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863',
    'panda eyebrow bullet gorilla call smoke muffin taste mesh discover soft ostrich alcohol speed nation flash devote level hobby quick inner drive ghost inside'
  ],
  [
    '23db8160a31d3e0dca3688ed941adbf3',
    'cat swing flag economy stadium alone churn speed unique patch report train'
  ],
  [
    '8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0',
    'light rule cinnamon wrap drastic word pride squirrel upgrade then income fatal apart sustain crack supply proud access'
  ],
  [
    '066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad',
    'all hour make first leader extend hole alien behind guard gospel lava path output census museum junior mass reopen famous sing advance salt reform'
  ],
  [
    'f30f8c1da665478f49b001d94c5fc452',
    'vessel ladder alter error federal sibling chat ability sun glass valve picture'
  ],
  [
    'c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05',
    'scissors invite lock maple supreme raw rapid void congress muscle digital elegant little brisk hair mango congress clump'
  ],
  [
    'f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f',
    'void come effort suffer camp survey warrior heavy shoot primary clutch crush open amazing screen patrol group space point ten exist slush involve unfold'
  ],
];

void main() {
  test('wordlist is the reference list', () {
    expect(englishWordlist.length, 2048);
    expect(englishWordlist.first, 'abandon');
    expect(englishWordlist.last, 'zoo');
    expect(englishWordlist.toSet().length, 2048);
    final sorted = [...englishWordlist]..sort();
    expect(sorted, englishWordlist);
  });

  test('reference vectors: entropy → mnemonic → entropy', () {
    for (final v in referenceVectors) {
      final entropy = hexToBytes(v[0]);
      expect(bip39EntropyToMnemonic(entropy), v[1], reason: v[0]);
      expect(bytesToHex(bip39MnemonicToEntropy(v[1])), v[0], reason: v[1]);
      expect(Mnemonic.validate(v[1]), isTrue);
      expect(Mnemonic.fromEntropy(entropy), v[1]);
      expect(bytesToHex(Mnemonic.toEntropy(v[1].toUpperCase())), v[0]);
    }
  });

  test('rejects a bad checksum, an unknown word and a wrong count', () {
    final good = referenceVectors[0][1].split(' ');
    final badChecksum = [...good]..last = 'abandon';
    expect(Mnemonic.validate(badChecksum.join(' ')), isFalse);
    expect(() => bip39MnemonicToEntropy(badChecksum.join(' ')),
        throwsArgumentError);
    expect(Mnemonic.validate(([...good]..[3] = 'janzeer').join(' ')), isFalse);
    expect(Mnemonic.validate(good.take(11).join(' ')), isFalse);
    expect(Mnemonic.validate(''), isFalse);
    expect(() => bip39EntropyToMnemonic(Uint8List(15)), throwsArgumentError);
    expect(() => bip39Generate(strength: 100), throwsArgumentError);
  });

  test('generate: every strength round-trips and uses all 256 byte values', () {
    for (final strength in [128, 160, 192, 224, 256]) {
      final m = Mnemonic.generate(strength: strength);
      expect(m.split(' ').length, (strength + strength ~/ 32) ~/ 11);
      expect(Mnemonic.validate(m), isTrue);
      expect(Mnemonic.fromEntropy(Mnemonic.toEntropy(m)), m);
    }
    // A fixed-seed RNG proves the 0xff byte can appear (the replaced package drew nextInt(255) and never produced it).
    final seen = <int>{};
    final rng = Random(7);
    for (var i = 0; i < 400 && !seen.contains(255); i++) {
      seen.addAll(
          bip39MnemonicToEntropy(bip39Generate(strength: 256, random: rng)));
    }
    expect(seen, contains(255));
  });
}
