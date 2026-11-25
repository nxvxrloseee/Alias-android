#!/usr/bin/env python3
"""Validate line-based source dictionaries and export app assets.

One complete card per line. Commas and punctuation inside titles are preserved.
Curated advanced cards live in tool/word_levels.json. Invalid input aborts the
export before any asset is changed; near-synonyms require editorial review.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / 'words_raw'
OUT = ROOT / 'assets' / 'words'
CARD_RE = re.compile(r"[А-Яа-яЁё][А-Яа-яЁё '\-,!?]*[А-Яа-яЁё!?]")


def key(text: str) -> str:
    return text.casefold().replace('ё', 'е')


def clean(line: str, cat: str = '') -> str | None:
    text = re.sub(r'\s+', ' ', line.strip().lstrip('\ufeff'))
    if (not CARD_RE.fullmatch(text) or len(text) > 60
            or len(text.split()) > 6 or ',,' in text):
        return None
    return text


def read_source(path: Path) -> list[str]:
    result, seen = [], set()
    for n, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        word = clean(line, path.stem)
        if word is None:
            raise ValueError(f'{path}:{n}: недопустимая карточка: {line!r}')
        if key(word) in seen:
            raise ValueError(f'{path}:{n}: повтор карточки: {word!r}')
        seen.add(key(word))
        result.append(word)
    if not result:
        raise ValueError(f'{path}: пустая категория')
    return result


def export(check: bool = False) -> None:
    category_ids = re.findall(r"Category\(\s*'([^']+)'", (ROOT / 'lib/categories.dart').read_text())
    sources = {cat: read_source(RAW / f'{cat}.txt') for cat in category_ids}
    levels = json.loads((ROOT / 'tool/word_levels.json').read_text())
    if set(levels) != set(sources):
        raise ValueError('Список категорий в разметке сложности не совпадает со словарями')
    advanced = set()
    for cat, values in levels.items():
        known = {key(w) for w in sources[cat]}
        for word in values:
            if key(word) not in known:
                raise ValueError(f'{cat}: сложное слово отсутствует в словаре: {word!r}')
            advanced.add(key(word))
    outputs = {f'{cat}.txt': '\n'.join(words) + '\n' for cat, words in sources.items()}
    outputs['advanced.json'] = json.dumps({cat: sorted({key(w) for w in values}) for cat, values in levels.items()}, ensure_ascii=False, indent=2) + '\n'
    if check:
        for filename, content in outputs.items():
            if (OUT / filename).read_text() != content:
                raise ValueError(f'{filename}: ресурс устарел; запустите tool/clean_words.py')
    else:
        OUT.mkdir(parents=True, exist_ok=True)
        for filename, content in outputs.items():
            (OUT / filename).write_text(content, encoding='utf-8')
    for cat, words in sources.items():
        normal = len(words) - len(levels[cat])
        print(f'{cat:12} обычные: {normal:4}  всего: {len(words):4}')
    all_words = {key(w) for words in sources.values() for w in words}
    print(f'Записей: {sum(map(len, sources.values()))}; уникальных: {len(all_words)}; '
          f'обычных: {len({key(w) for cat, words in sources.items() for w in words if key(w) not in {key(v) for v in levels[cat]}})}; с отметкой сложности: {len(advanced)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='проверить ресурсы без перезаписи')
    export(parser.parse_args().check)
