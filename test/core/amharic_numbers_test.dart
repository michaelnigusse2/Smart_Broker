import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/transcription/amharic_numbers.dart';

void main() {
  group('normaliseAmharicNumbers', () {
    test('teens, tens and years', () {
      expect(normaliseAmharicNumbers('እዚህ ሰፈር አስራ አምስት አመት ኖሪያለሁ'), 'እዚህ ሰፈር 15 አመት ኖሪያለሁ');
      expect(normaliseAmharicNumbers('ሃያ አምስት ሰው'), '25 ሰው');
      expect(normaliseAmharicNumbers('ሰላሳ ቀን'), '30 ቀን');
      expect(normaliseAmharicNumbers('በሁለት ሺ አስራ ሰባት'), 'በ2017');
    });

    test('prices with scales and halves', () {
      expect(normaliseAmharicNumbers('ዘጠኝ ሚሊዮን ብር'), '9,000,000 ብር');
      expect(normaliseAmharicNumbers('ሁለት ሚሊዮን ተኩል'), '2,500,000');
      expect(normaliseAmharicNumbers('ሁለት ሚሊዮን አምስት መቶ ሺ ብር'), '2,500,000 ብር');
      expect(normaliseAmharicNumbers('በአምስት መቶ ሺ'), 'በ500,000');
      expect(normaliseAmharicNumbers('አንድ ሺ ሁለት መቶ ብር'), '1200 ብር');
      expect(normaliseAmharicNumbers('አስር ሺ'), '10,000');
      expect(normaliseAmharicNumbers('መቶ ሺ'), '100,000');
      expect(normaliseAmharicNumbers('ሁለት ነጥብ አምስት ሚሊዮን'), '2,500,000');
      expect(normaliseAmharicNumbers('ሶስት ነጥብ አምስት ፐርሰንት'), '3.5 ፐርሰንት');
    });

    test('phone numbers read digit by digit', () {
      expect(
        normaliseAmharicNumbers('ስልኩ ዜሮ ዘጠኝ አንድ አንድ ሃያ ሶስት አርባ አምስት ስልሳ ሰባት ነው'),
        'ስልኩ 0911234567 ነው',
      );
      expect(normaliseAmharicNumbers('ዜሮ ዘጠኝ አስራ ሁለት ሰላሳ አራት'), '091234');
      expect(normaliseAmharicNumbers('ዘጠኝ አንድ አንድ'), '911');
    });

    test('spelling variants match', () {
      expect(normaliseAmharicNumbers('ሀያ'), '20');
      expect(normaliseAmharicNumbers('ሐያ ሦስት'), '23');
      expect(normaliseAmharicNumbers('አሥራ ሁለት'), '12');
      expect(normaliseAmharicNumbers('ሃምሳ ሺህ'), '50,000');
    });

    test('leaves small and ambiguous numbers as words', () {
      // "አንድ" is also the indefinite article.
      expect(normaliseAmharicNumbers('አንድ ሰው መጣ'), 'አንድ ሰው መጣ');
      expect(normaliseAmharicNumbers('ለአንድ ሰው'), 'ለአንድ ሰው');
      // "two or three days"
      expect(normaliseAmharicNumbers('ሁለት ሶስት ቀን'), 'ሁለት ሶስት ቀን');
      expect(normaliseAmharicNumbers('አስር ደቂቃ'), 'አስር ደቂቃ');
      // Not a number sequence.
      expect(normaliseAmharicNumbers('አምስት ሃያ'), 'አምስት ሃያ');
    });

    test('text without numbers is unchanged apart from spacing', () {
      expect(normaliseAmharicNumbers('ሰላም ስሜ ሚካኤል ነው'), 'ሰላም ስሜ ሚካኤል ነው');
      expect(normaliseAmharicNumbers(''), '');
      expect(normaliseAmharicNumbers('ተኩል ነጥብ'), 'ተኩል ነጥብ');
    });
  });

  test('foldAmharicSpelling folds interchangeable letters', () {
    expect(foldAmharicSpelling('ሃያ'), foldAmharicSpelling('ሐያ'));
    expect(foldAmharicSpelling('ሠላሳ'), 'ሰላሳ');
    expect(foldAmharicSpelling('ዐሥር'), 'አስር');
  });
}
