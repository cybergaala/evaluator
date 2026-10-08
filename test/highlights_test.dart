import 'package:evaluator/presentation/controllers/highlights_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apply = HighlightsController.apply;

  test('paints, repaints over, and erases ranges', () {
    var r = apply([], 2, 8, 0);
    expect(r, [(2, 8, 0)]);

    // Painting the middle splits the old range.
    r = apply(r, 4, 6, 1);
    expect(r, [(2, 4, 0), (4, 6, 1), (6, 8, 0)]);

    // Erasing across two ranges trims both.
    r = apply(r, 3, 5, null);
    expect(r, [(2, 3, 0), (5, 6, 1), (6, 8, 0)]);

    // Erasing everything.
    expect(apply(r, 0, 10, null), isEmpty);

    // Ranges outside the cut stay untouched.
    expect(apply([(0, 2, 0), (8, 9, 1)], 3, 5, 2), [
      (0, 2, 0),
      (3, 5, 2),
      (8, 9, 1),
    ]);
  });
}
