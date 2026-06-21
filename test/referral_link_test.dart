import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolliq/core/env/env.dart';
import 'package:scrolliq/features/referral/data/referral_repository.dart';

void main() {
  group('ReferralRepository.buildLink', () {
    setUp(() {
      // dotenv is otherwise loaded from .env in main(); for tests we feed it
      // values directly so Env.referralBaseUrl reads the override.
      dotenv.testLoad(fileInput: '');
    });

    test('strips a trailing slash from REFERRAL_BASE_URL', () {
      dotenv.testLoad(fileInput: 'REFERRAL_BASE_URL=https://scroll-iq.vercel.app/');
      expect(Env.referralBaseUrl, 'https://scroll-iq.vercel.app');
      expect(
        ReferralRepository.buildLink('ABCD1234'),
        'https://scroll-iq.vercel.app/invite?ref=ABCD1234',
      );
    });

    test('strips multiple trailing slashes', () {
      dotenv.testLoad(fileInput: 'REFERRAL_BASE_URL=https://scrolliq.app///');
      expect(Env.referralBaseUrl, 'https://scrolliq.app');
      expect(
        ReferralRepository.buildLink('XYZ'),
        'https://scrolliq.app/invite?ref=XYZ',
      );
    });

    test('preserves a base URL without a trailing slash', () {
      dotenv.testLoad(fileInput: 'REFERRAL_BASE_URL=https://scrolliq.app');
      expect(
        ReferralRepository.buildLink('CODE1'),
        'https://scrolliq.app/invite?ref=CODE1',
      );
    });

    test('falls back to the default base when the env var is unset', () {
      dotenv.testLoad(fileInput: '');
      expect(Env.referralBaseUrl, 'https://scrolliq.app');
      expect(
        ReferralRepository.buildLink('FOO'),
        'https://scrolliq.app/invite?ref=FOO',
      );
    });
  });

  group('ReferralRepository.parseCode', () {
    test('extracts ref from an https invite URL', () {
      final uri = Uri.parse('https://scroll-iq.vercel.app/invite?ref=abcd1234');
      expect(ReferralRepository.parseCode(uri), 'ABCD1234');
    });

    test('extracts ref from a custom-scheme invite URL', () {
      final uri = Uri.parse('scrolliq://invite?ref=hello');
      expect(ReferralRepository.parseCode(uri), 'HELLO');
    });

    test('returns null when ref is missing', () {
      final uri = Uri.parse('https://scroll-iq.vercel.app/invite');
      expect(ReferralRepository.parseCode(uri), isNull);
    });

    test('returns null when ref is blank', () {
      final uri = Uri.parse('https://scroll-iq.vercel.app/invite?ref=');
      expect(ReferralRepository.parseCode(uri), isNull);
    });
  });
}
