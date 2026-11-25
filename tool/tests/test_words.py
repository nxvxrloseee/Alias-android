import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('clean_words', ROOT / 'tool/clean_words.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WordTests(unittest.TestCase):
    def test_titles_preserve_punctuation(self):
        for text in ('Здравствуйте, я ваша тётя!', 'Ну, погоди!', "Жанна д'Арк", 'Кин-дза-дза'):
            self.assertEqual(module.clean(text), text)

    def test_corrupt_and_non_russian_cards_are_rejected(self):
        for text in ('Minecraft', '123', '', 'два,,слова', 'слово / мусор'):
            self.assertIsNone(module.clean(text))

    def test_sources_match_generated_assets(self):
        module.export(check=True)

    def test_editorial_regressions(self):
        bad = {'Дмитрий Донцова', 'Сагрда Фамилия', 'Доту', 'злость характера',
               'головой', 'черти водятся', 'Нарния лев Аслан', 'Америка открытие',
               'Санкт-Петербург основание', 'Сватьи'}
        for path in (ROOT / 'assets/words').glob('*.txt'):
            self.assertFalse(bad.intersection(path.read_text().splitlines()), path.name)
        self.assertIn('Дарья Донцова', (ROOT / 'assets/words/famous.txt').read_text().splitlines())
        self.assertNotIn('Шерлок Холмс', (ROOT / 'assets/words/famous.txt').read_text().splitlines())
        self.assertNotIn('пенсионер', (ROOT / 'assets/words/professions.txt').read_text().splitlines())

    def test_no_category_is_emptied_by_difficulty_filter(self):
        levels = json.loads((ROOT / 'assets/words/advanced.json').read_text())
        for cat, difficult in levels.items():
            words = (ROOT / f'assets/words/{cat}.txt').read_text().splitlines()
            easy = [w for w in words if module.key(w) not in difficult]
            self.assertGreaterEqual(len(easy), 250, cat)
        self.assertEqual(levels['kids'], [])
        kids = (ROOT / 'assets/words/kids.txt').read_text().splitlines()
        self.assertGreaterEqual(len(kids), 450)
        self.assertEqual(len(kids), len({module.key(w) for w in kids}))


if __name__ == '__main__':
    unittest.main()
