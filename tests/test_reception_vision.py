import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("vision", Path(__file__).parents[1] / "runtime/reception_vision.py")
vision = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vision)


class IdentityTests(unittest.TestCase):
    def test_unknown_is_not_nearest_person(self):
        self.assertEqual(vision.choose_identity({"ana": 0.31})[0], "")

    def test_ambiguous_person_remains_unknown(self):
        self.assertEqual(vision.choose_identity({"ana": 0.71, "bia": 0.69})[0], "")

    def test_clear_match(self):
        self.assertEqual(vision.choose_identity({"ana": 0.82, "bia": 0.40})[0], "ana")

    def test_empty_registry(self):
        self.assertEqual(vision.choose_identity({}), ("", 0.0))


if __name__ == "__main__":
    unittest.main()
